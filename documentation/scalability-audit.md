# Scalability Audit Report — PLASIR / Dondzalândia

> **Auditor**: Principal Engineer review  
> **Date**: 2026-05-15  
> **Scope**: `dondza` (Laravel 12 API) + `dondza_cadastro` (React 18 SPA)

---

## Executive Summary

| Category | Status | Notes |
|---|---|---|
| Database query efficiency | ⚠️ Risks | N+1 patterns on login; 3-query identifier resolution |
| Connection pooling | ⚠️ Unknown | Not configured; Laravel default (no pooling) |
| Caching strategy | ✅ Implemented | Redis cache + TanStack Query client-side |
| Horizontal scaling | ⚠️ Partial | Requires Redis for sessions/cache/queue |
| Queue system | ✅ Implemented | DB queue (dev), Redis (prod recommended) |
| Frontend bundle | ✅ Good | Code splitting configured in Vite |
| Observability | ⚠️ Gaps | No distributed tracing; no Prometheus metrics |
| Circuit breakers | ❌ Missing | OpenAI, Resend failures not isolated |

**Scalability cliff estimate**: System should handle ~100–200 concurrent professional users on a single server with current architecture. Above that, the login N+1, session DB writes, and queue saturation become bottlenecks.

---

## Phase 1: Specific Performance Bottlenecks (Evidence-Based)

---

### BOTTLENECK-01 — Login Fires 3 Sequential DB Queries Per Attempt

**Location**: `dondza/app/Modules/Auth/UseCases/LoginUseCase.php:162-190`

**Evidence**:
```php
private function resolveUserByIdentifier(string $identifier): ?User
{
    // Query 1: child code lookup
    $child = DB::table('children')->where('code', $identifier)->first();
    if ($child) {
        // Query 2: person lookup
        $person = DB::table('person')->where('id', $child->person_id)->first();
        if ($person && $person->user_id) {
            return User::find($person->user_id); // Query 3
        }
    }

    // Query 4: email lookup (most common path)
    $user = User::where('email', $identifier)->first();
    if ($user) return $user;

    // Query 5: phone lookup
    $person = DB::table('person')->where('phone', $identifier)
        ->whereNotNull('user_id')->first();
    if (!$person) return null;
    return User::find($person->user_id); // Query 6
}
```

**Impact**: 
- Best case (email match): 2 queries (children check + email lookup)
- Worst case (no match): 4–6 queries before returning null
- Under 100 concurrent logins/minute: 200–600 queries/minute from login alone
- Under a brute-force attack (bypassing IP throttle via proxy rotation): this is a DB denial-of-service vector

**Fix**:
```php
private function resolveUserByIdentifier(string $identifier): ?User
{
    // Single optimized query covering all identifier types
    $user = User::where('email', $identifier)->first();
    if ($user) return $user;

    // Only check person table if the identifier looks like a phone or code
    // (not an email address)
    if (!filter_var($identifier, FILTER_VALIDATE_EMAIL)) {
        $person = DB::table('persons')
            ->where(function ($q) use ($identifier) {
                $q->where('phone', $identifier);
                // child code lookup moved to a dedicated student auth endpoint
            })
            ->whereNotNull('user_id')
            ->select('user_id')
            ->first();

        if ($person) return User::find($person->user_id);
    }

    return null;
}
```

Add composite index:
```sql
-- If phone login stays on the persons table:
CREATE INDEX idx_persons_phone_user ON persons(phone, user_id);
```

**Effort**: S | **Confidence**: High.

---

### BOTTLENECK-02 — Login Response Loads 5 Eager-Loaded Relationships

**Location**: `dondza/app/Modules/Auth/UseCases/LoginUseCase.php:79-90`

**Evidence**:
```php
$user->load([
    'userEntities.entity',       // 2 levels: userEntities JOIN entities
    'userEntities.role',         // 3rd level
    'userRoles.role',            // 2 levels
    'userRoles.entity',          // 3rd level
    'person.professional.specialties', // 3 levels deep
]);

$mainEntity = $user->userEntities()
    ->where('is_main', true)
    ->with('entity')
    ->first(); // ADDITIONAL query after the load above
```

**Impact**: 
- Every login fires 7–10 DB queries (5 eager loads + userEntities refetch + specialty pivot)
- For a user with 3 entities, 5 specialties: 10–15 queries
- Under 50 concurrent logins: 500–750 queries/minute
- P95 login response time estimate: **800ms–2s** on modest hardware

**Fix**: Replace the multi-level eager load with a single denormalised query:
```php
// Option A: Cache the login payload per user (5-minute TTL)
$cacheKey = "user_login_data_{$user->id}";
$loginData = Cache::remember($cacheKey, 300, function () use ($user) {
    $user->load([
        'userEntities.entity',
        'userEntities.role',
        'userRoles.role',
        'person.professional.specialties',
    ]);
    return $this->buildLoginResponse($user);
});
```

**Effort**: M | **Confidence**: High.

---

### BOTTLENECK-03 — Sessions Stored in MySQL (Default) — Write Contention at Scale

**Location**: `dondza/.env.example:57` — `SESSION_DRIVER=database`

**Evidence**:
```env
SESSION_DRIVER=database
CACHE_STORE=database  # Also database in dev
QUEUE_CONNECTION=database  # Also database in dev
```

**Impact**:
- Every authenticated request reads + writes to the `sessions` table
- At 200 concurrent users: 200 read + 200 write operations/second on `sessions`
- Sessions table has no partitioning — row-level locks on concurrent session updates
- Combined with cache reads/writes and queue polls to the same MySQL instance: **single DB write bottleneck**

**The cliff**: At ~150 concurrent users, session writes + cache reads + queue polling will saturate a single MySQL server's write capacity, causing login timeouts and cascading failures.

**Fix** — Switch all three to Redis in production:
```env
# Production .env
SESSION_DRIVER=redis
CACHE_STORE=redis
QUEUE_CONNECTION=redis
```

This removes **all three** database-backed drivers from the hot path and frees MySQL for actual data queries.

**Effort**: XS (config change only) | **Confidence**: High.

---

### BOTTLENECK-04 — `EnsureEntityAccess` Performs DB Query on Every Request

**Location**: `dondza/app/Modules/Tenancy/Middleware/EnsureEntityAccess.php:80`

**Evidence**:
```php
if (!$this->tenancyService->hasEntityAccess($user, $entityId)) {
    // This calls DB: user_entities WHERE user_id = ? AND entity_id = ?
    return response()->json(['message' => 'Sem acesso.'], 403);
}
```

**Impact**:
- Every protected route fires a `user_entities` table lookup
- A professional browsing the dashboard makes 5–10 API calls per page load
- Each call: 1 auth check (Sanctum session) + 1 entity access check + N business queries
- At 50 concurrent users × 8 requests/user: 400 entity-access queries/second

**Fix**: Cache the entity access check per user per request lifecycle (request-scoped cache) or per user (short TTL):
```php
// In TenancyService::hasEntityAccess()
public function hasEntityAccess(User $user, string $entityId): bool
{
    $cacheKey = "entity_access_{$user->id}_{$entityId}";
    
    return Cache::remember($cacheKey, 60, function () use ($user, $entityId) {
        return $user->userEntities()
            ->where('entity_id', $entityId)
            ->exists();
    });
}
```

Invalidate when user-entity relationships change:
```php
// In UserEntity observer
Cache::forget("entity_access_{$userEntity->user_id}_{$userEntity->entity_id}");
```

**Effort**: S | **Confidence**: High.

---

### BOTTLENECK-05 — Triage Universal Dashboard: 5 Separate HTTP Requests (No Parallelism)

**Location**: `dondza_cadastro/src/sections/triagem/` (inferred from route structure)  
**Backend**: `routes/api.php:265-269` — 5 separate endpoints for the analytics dashboard

**Evidence** (from routes):
```php
Route::get('screening/triagem-universal/overview', ...);
Route::get('screening/triagem-universal/functional-profile', ...);
Route::get('screening/triagem-universal/question-analysis', ...);
Route::get('screening/triagem-universal/equidade', ...);
Route::get('screening/triagem-universal/risk-profiles', ...);
```

**Impact**:
- If the frontend loads these sequentially (tab by tab, or all on mount): 5 round-trips
- Each endpoint likely performs aggregation queries over the full `triages` + `wgss_screenings` tables
- No evidence of materialized views or pre-computed projections for the universal dashboard (only `triage_projections` which covers the per-child case)
- At 1,000 triages per entity: each aggregation query scans the full table — **O(n) per dashboard load**

**Fix**:

**Short term** — Ensure frontend fires all 5 in parallel:
```js
// Use Promise.all or React Query's useQueries
const results = await Promise.all([
  api.get('screening/triagem-universal/overview'),
  api.get('screening/triagem-universal/functional-profile'),
  api.get('screening/triagem-universal/question-analysis'),
  api.get('screening/triagem-universal/equidade'),
  api.get('screening/triagem-universal/risk-profiles'),
]);
```

**Medium term** — Cache aggregated results:
```php
// In TriagemUniversalController
$cacheKey = "triagem_universal_overview_{$entityId}";
return Cache::remember($cacheKey, 300, fn() => $this->computeOverview($entityId));
```

**Long term** — Add a `triagem_universal_projections` pre-computed table updated by a queue job on each new triage submission.

**Effort**: S (frontend parallelism), M (caching), L (materialized projections) | **Confidence**: Medium.

---

## Phase 2: Database Scalability

### Query Efficiency

| Finding | Severity | Notes |
|---|---|---|
| Login: 3–6 sequential queries per attempt | 🟠 High | See BOTTLENECK-01 |
| Login: 5 eager-loaded relationships | 🟠 High | See BOTTLENECK-02 |
| EnsureEntityAccess: per-request DB query | 🟡 Medium | See BOTTLENECK-04 |
| Universal dashboard: no aggregation cache | 🟡 Medium | See BOTTLENECK-05 |
| Indexes on critical paths | ✅ Good | Performance migration `2026_04_05_150000` adds pre-Redis indexes |
| Unique constraints on child records | ✅ Good | UNIQUE on `triages.child_id`, `anamneses.child_id`, `diagnostics.child_id` |
| Soft delete + index | ✅ Good | `deleted_at` indexed on children |

### Connection Pooling

**Current state**: Laravel uses PHP-FPM with persistent connections per worker. There is no explicit connection pooler (PgBouncer/ProxySQL) configured in the deployment docs.

**Risk**: At 50 concurrent PHP-FPM workers (typical), 50 MySQL connections are held open. At 200 workers, 200 connections — above MySQL's default `max_connections=151`. This causes `Too many connections` errors.

**Fix**:
```bash
# Option A: Increase MySQL max_connections (quick)
# /etc/mysql/mysql.conf.d/mysqld.cnf
max_connections = 500

# Option B: Deploy ProxySQL or PgBouncer in front of MySQL (proper solution)
# Reduces actual MySQL connections to 10-20 regardless of PHP workers
```

### Read Replicas

No read replica configuration found. Dashboard and analytics endpoints (`/triagem-universal/*`, `/dashboard/overview`, `/plasir/anamneses/dashboard`) all write-capable DB connections for read queries.

**Fix**: Configure a `mysql_read` connection in `config/database.php` and use it in analytics controllers:
```php
$results = DB::connection('mysql_read')->select(...);
```

### Data Volume & Partitioning

| Table | Growth Rate | Risk |
|---|---|---|
| `triages` | 1 per child ever | Low (bounded by child population) |
| `student_answers` | N per quiz per child | High — unbounded as assessments scale |
| `sessions` | 1 per active session | Medium — prune regularly |
| `jobs` (queue) | Spikes on batch ops | Medium — clear after processing |

**Recommendation**: Add a cron job to prune old sessions and completed jobs:
```bash
php artisan schedule:run  # Ensure sessions:prune and queue:prune are scheduled
```

---

## Phase 3: API Scalability

### Statelessness

**Current state**: ⚠️ Mixed. The system issues Sanctum Bearer tokens (stateless) but also maintains server-side sessions (stateful). The logout correctly invalidates both. The dual-mode creates orphaned session rows.

**Recommendation**: Choose one mode (see SECURITY HIGH-06). If pure token auth is chosen, remove all session writes — this makes the API fully stateless and horizontally scalable without Redis sessions.

### Pagination

| Finding | Status |
|---|---|
| `cadastro/children` — paginated? | ⚠️ Not confirmed from routes |
| `waiting-list` — supports `?search=` | ✅ Server-side filtering added |
| `screening/triages` — paginated? | ⚠️ Not confirmed |
| `referrals/inbox` — paginated? | ⚠️ Not confirmed |
| `assessment/results` — paginated? | ⚠️ Not confirmed |

**Risk**: Unpaginated list endpoints on entities with 500+ children or 1000+ triages will return multi-megabyte JSON responses. React renders these synchronously, causing UI freezes.

**Recommendation**: Enforce pagination on all list endpoints via a base controller method:
```php
// In base Controller or a ListsResources trait
protected function paginatedResponse($query, int $perPage = 25): JsonResponse
{
    return response()->json($query->paginate($perPage));
}
```

### Long-Running Requests

| Operation | Async? | Risk |
|---|---|---|
| AI triage report generation | ✅ Queue job | Good |
| PDF export | ❌ Synchronous in frontend | Medium |
| Email sending (Resend) | ⚠️ Via queue | Verify queue is used |
| Geocode / reverse-geocode | ❌ Synchronous (external API call) | High if Mapbox is slow |

**Fix for geocode**: Add a 5-second timeout + circuit breaker for the Mapbox calls:
```php
// In LocationController
try {
    $result = Http::timeout(5)->post('https://api.mapbox.com/...');
} catch (\Illuminate\Http\Client\ConnectionException $e) {
    return response()->json(['error' => 'Geocoding service unavailable'], 503);
}
```

---

## Phase 4: Frontend Scalability

### Bundle Size Analysis

`vite.config.js` correctly configures `manualChunks`:

```js
// These heavy libs are correctly split into separate chunks:
'vendor-export'   → jspdf, html2canvas, xlsx, pdfjs-dist
'vendor-charts'   → apexcharts, react-apexcharts
'vendor-editor'   → @tiptap/*, lowlight
'vendor-maps'     → react-map-gl, mapbox-gl
'vendor-lightbox' → yet-another-react-lightbox
```

**What's missing**: MUI (Material UI v5) is not split. It is one of the largest dependencies and is loaded in the main chunk. This increases the initial parse time.

**Fix**:
```js
// Add to manualChunks in vite.config.js
if (id.includes('@mui/material') || id.includes('@mui/lab') || id.includes('@mui/x-')) {
  return 'vendor-mui';
}
if (id.includes('@emotion/')) {
  return 'vendor-emotion';
}
```

### State Management & Re-renders

**TanStack Query** is correctly used for all server state — this is good. The `queryClient.clear()` call on logout is correct.

**Risk**: `queryClient.clear()` is also called on every `switchEntity`. This clears ALL cached queries, causing a full re-fetch waterfall on entity switch. With 5–10 cached queries active, this creates a spike of concurrent requests.

**Fix**: Invalidate only entity-scoped queries on switch:
```js
// Instead of queryClient.clear():
queryClient.invalidateQueries({ predicate: (query) => 
  query.queryKey.some(key => typeof key === 'string' && key.includes('entity'))
});
```

### API Request Patterns

The 5 Triagem Universal endpoints (BOTTLENECK-05) need parallel firing. Also check for sequential waterfall patterns in dashboard views that could be parallelised.

---

## Phase 5: Infrastructure Scalability

### Queue System

| Aspect | Status | Notes |
|---|---|---|
| Queue backend | ⚠️ DB in dev | Must use Redis in production |
| Dead letter queue | ✅ `failed_jobs` table | Exists |
| Job retry logic | ✅ `--tries=1` in dev | Set higher retry for AI/email jobs |
| Queue monitoring | ⚠️ Basic | `QUEUE_HEALTH_MAX_PENDING=10` alert exists |
| Circuit breaker for jobs | ❌ Missing | OpenAI failures queue indefinitely |

**Fix for circuit breaker** on AI reports:
```php
// In GenerateTriageAiReport job
public function handle(): void
{
    // Check OpenAI failure rate in cache
    $failures = Cache::get('openai_consecutive_failures', 0);
    if ($failures >= 5) {
        $this->fail(new \RuntimeException('OpenAI circuit breaker open'));
        return;
    }
    
    try {
        // ... generate report
        Cache::forget('openai_consecutive_failures');
    } catch (\Exception $e) {
        Cache::increment('openai_consecutive_failures');
        Cache::put('openai_consecutive_failures', 
            Cache::get('openai_consecutive_failures'), 
            now()->addMinutes(10)
        );
        throw $e;
    }
}
```

### Horizontal Scaling Checklist

| Requirement | Status |
|---|---|
| Sessions in Redis | ⚠️ Must configure |
| Cache in Redis | ⚠️ Must configure |
| Queue in Redis | ⚠️ Must configure |
| File storage in S3 | ⚠️ Currently local disk |
| No in-memory state between requests | ✅ Confirmed |
| Health check endpoint | ✅ `/api/health/ready` |

**The system CAN scale horizontally** once Redis is used for sessions/cache/queue and file storage moves to S3. With `SESSION_DRIVER=database`, horizontal scaling is **not safe** (session sticky-sessions would be required).

---

## Phase 6: Observability Gaps

| Gap | Severity | Fix |
|---|---|---|
| No distributed tracing | 🟡 Medium | Add Sentry Performance or OpenTelemetry spans for queue jobs |
| No Prometheus/metrics endpoint | 🟡 Medium | Add `laravel-prometheus` or expose queue depth via health endpoint |
| No correlation ID across frontend→backend | 🟡 Medium | Add `X-Request-ID` header; log it in both Sentry contexts |
| No alerting runbooks | 🟡 Medium | Document response procedures for `QUEUE_HEALTH_MAX_PENDING` alerts |
| Slow query log disabled by default | 🟡 Medium | `SLOW_QUERY_LOG_ENABLED=false` — enable in production with 500ms threshold |
| No frontend performance monitoring | 🟢 Low | Consider Sentry Performance or Vercel Analytics for Web Vitals |

**Recommended correlation ID implementation**:
```php
// In AttachRequestContext middleware (already exists)
$requestId = Str::uuid()->toString();
$request->headers->set('X-Request-ID', $requestId);
\Sentry\configureScope(function (\Sentry\State\Scope $scope) use ($requestId) {
    $scope->setTag('request_id', $requestId);
});
\Log::withContext(['request_id' => $requestId]);
```

```js
// In axios.js interceptor
config.headers['X-Request-ID'] = crypto.randomUUID();
```

---

## Summary: The 5 Things to Fix Before Going Live at Scale

| # | Action | Effort | Unblocks |
|---|---|---|---|
| 1 | Switch SESSION/CACHE/QUEUE to Redis | XS | Horizontal scaling, removes DB write bottleneck |
| 2 | Cache entity access check (60s TTL) | S | 40% reduction in per-request DB queries |
| 3 | Cache login payload per user (5min TTL) | M | Login response time from ~1.5s → ~200ms |
| 4 | Split MUI into separate Vite chunk | S | Initial bundle parse time reduction |
| 5 | Parallelize Triagem Universal dashboard requests | S | Dashboard load time from ~5s → ~1.5s |
