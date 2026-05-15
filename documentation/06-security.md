# 06 — Security Analysis

## Table of Contents
- [Security Overview](#security-overview)
- [Authentication Implementation](#authentication-implementation)
- [Authorization & Access Control](#authorization--access-control)
- [Input Validation & Sanitization](#input-validation--sanitization)
- [SQL Injection Protection](#sql-injection-protection)
- [XSS Protection](#xss-protection)
- [CSRF Protection](#csrf-protection)
- [Rate Limiting & Abuse Prevention](#rate-limiting--abuse-prevention)
- [Secrets Management](#secrets-management)
- [HTTPS / CORS / Security Headers](#https--cors--security-headers)
- [Data Encryption](#data-encryption)
- [Mobile API Security](#mobile-api-security)
- [Third-Party Security](#third-party-security)
- [Known Vulnerabilities & Recommendations](#known-vulnerabilities--recommendations)
- [Security Checklist](#security-checklist)

---

## Security Overview

| Layer | Status | Notes |
|---|---|---|
| Authentication | ✅ Implemented | Laravel Sanctum (SPA cookies + Bearer tokens) |
| Authorization | ✅ Implemented | Middleware guards + Laravel Policies |
| Input Validation | ✅ Implemented | Laravel Form Requests on all mutations |
| SQL Injection | ✅ Protected | Eloquent ORM (parameterised queries) |
| XSS | ✅ Partially | Laravel escaping + JSON-only API |
| CSRF | ✅ Implemented | Sanctum XSRF-TOKEN cookie |
| Rate Limiting | ✅ Implemented | Named throttle groups on sensitive routes |
| Secrets Management | ⚠️ Review Needed | `.env` file — no vault integration detected |
| HTTPS | ⚠️ Config-level | Enforced at infra level; `SESSION_SECURE_COOKIE=false` in example |
| CORS | ✅ Configured | Whitelist in `CORS_ALLOWED_ORIGINS` |
| Data Encryption at rest | ⚠️ Partial | Password hashed; no full-disk or field-level encryption found |
| Data Encryption in transit | ✅ Production | HTTPS to `api.dondzalandia.co.mz` |
| OpenAI key exposure | ❌ Risk | `openAIService.js` was committed and later purged via `git filter-branch` |

---

## Authentication Implementation

### Method: Laravel Sanctum

**Web (SPA):**
- Login sets an **HTTP-only session cookie** (Laravel session)
- A `XSRF-TOKEN` cookie is also set for CSRF protection
- All subsequent requests authenticate via cookie (no token in `localStorage`)
- Session lifetime: `SESSION_LIFETIME=120` minutes

**Mobile / Bearer token:**
- Login via `/auth/mobile/login` returns a **Sanctum personal access token**
- Token stored by the mobile client
- Protected by `X-Mobile-API-Key` header (shared secret)

**Session Configuration:**
```env
SESSION_DRIVER=database         # Stored in DB, not file (reduces file-system race conditions)
SESSION_LIFETIME=120
SESSION_ENCRYPT=false           # ⚠️ Not encrypted at rest (session data in plain DB rows)
SESSION_HTTP_ONLY=true          # ✅ Cookie not accessible via JavaScript
SESSION_SAME_SITE=lax           # ✅ CSRF defence
SESSION_SECURE_COOKIE=false     # ⚠️ Must be true in production (HTTPS)
SANCTUM_EXPIRATION=120          # Token expiry in minutes
```

### Password Storage
- Passwords hashed with **Bcrypt** (`BCRYPT_ROUNDS=12`)
- Custom `password_hash` column (not Laravel's default `password`)
- `setPasswordHashAttribute()` auto-hashes on assignment, avoids double-hashing via `Hash::needsRehash()`
- Password field hidden from serialization

### Password Reset Flow
- Secure token stored in `password_reset_tokens` table
- Token validated before allowing reset
- Protected by `auth-reset-password` throttle

---

## Authorization & Access Control

### Middleware Stack

| Middleware | Purpose |
|---|---|
| `auth:sanctum` | All protected routes — verifies valid session/token |
| `EnsureEntityAccess` | Tenant isolation — user must belong to requested entity |
| `EnsureSuperAdmin` | Admin-only mutations — user must have `is_super_admin = true` |
| `EnsureMobileApiKey` | Mobile routes — validates `X-Mobile-API-Key` header with `hash_equals()` |
| `AttachRequestContext` | Adds request context to logs (not a security middleware) |

### Policy-Based Authorization

Laravel Policies registered for resource-level rules:
- **`ChildPolicy`** — controls who can view, create, update, delete child records
- **`TriagePolicy`** / **`TriageAccessTest`** — triage data access rules
- **`ReferralPolicy`** / **`ReferralAccessTest`** — referral visibility

### Super Admin Bootstrap Protection

```php
// EnsureSuperAdmin.php
$hasSuperAdmin = User::where('is_super_admin', true)->exists();
if (!$hasSuperAdmin) {
    return $next($request); // Allow first setup
}
```

> ⚠️ **Risk**: Once deployed, if all super admin accounts are deleted, this opens an unauthenticated registration endpoint. Implement a deployment guard to prevent accidental super admin deletion.

### Mobile API Key Comparison

```php
// Uses timing-safe comparison — resistant to timing attacks
if (!hash_equals($expectedKey, $providedKey)) {
    return response()->json(['message' => 'Chave de API inválida.'], 401);
}
```

---

## Input Validation & Sanitization

### Backend: Laravel Form Requests

All API mutations use Laravel **Form Request** classes (located in `app/Modules/*/Requests/`):
- Field presence validation (`required`, `nullable`)
- Type validation (`string`, `integer`, `boolean`, `array`, `date`)
- Relational checks (`exists:table,column`)
- Length constraints (`max:255`, etc.)

### Frontend: Zod + React Hook Form

```js
// Example: form validation with Zod schema
const schema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});
```

- Validation happens **before** submission (client-side fast feedback)
- Server-side validation is the authoritative check

---

## SQL Injection Protection

✅ **Protected by Eloquent ORM**

All database queries use parameterised bindings:
```php
// All Eloquent queries are parameterised — not vulnerable
Child::where('entity_id', $entityId)->where('id', $childId)->first();
```

> ⚠️ Audit any raw `DB::select()` or `DB::statement()` calls (found in the health check route — uses `SELECT 1` which is safe).

---

## XSS Protection

✅ **API-only JSON responses** — no HTML rendering, so traditional XSS via server-rendered HTML is not applicable.

**Frontend protections:**
- React's default JSX escaping prevents reflected XSS in rendered content
- Tiptap rich-text editor outputs sanitized HTML — verify `DOMPurify` is used if raw HTML is rendered
- No `dangerouslySetInnerHTML` should be used without sanitization

> ⚠️ **Recommendation**: Audit Tiptap output rendering to confirm HTML is sanitized before display.

---

## CSRF Protection

✅ **Sanctum XSRF-TOKEN mechanism:**
1. On first request, Laravel sets a `XSRF-TOKEN` cookie (not HTTP-only)
2. Axios automatically reads this cookie and sends it as the `X-XSRF-TOKEN` header
3. Laravel validates the header matches the cookie on state-changing requests
4. API routes (`/api/*`) using `web` middleware are CSRF-protected for SPA clients

**Mobile routes skip CSRF** by design (use `EnsureMobileApiKey` instead).

---

## Rate Limiting & Abuse Prevention

Named throttle groups are applied to all sensitive endpoints:

| Route | Throttle Group | Risk Mitigated |
|---|---|---|
| `POST /auth/login` | `auth-login` | Brute-force credential stuffing |
| `POST /auth/mobile/login` | `auth-mobile-login` | Mobile brute-force |
| `POST /auth/forgot-password` | `auth-forgot-password` | Email enumeration / spam |
| `POST /auth/reset-password` | `auth-reset-password` | Token brute-force |
| `POST /auth/setup-password` | `auth-setup-password` | Setup link abuse |
| `GET /location/provinces|districts` | `location-public` | Scraping prevention |
| `POST /assessment/quiz/start` | `quiz-start` | Quiz spam |
| `POST /assessment/quiz/answers` | `quiz-answers` | Answer flooding |
| `POST /assessment/quiz/answers/batch` | `quiz-batch` | Batch flooding |
| `POST /assessment/quiz/complete` | `quiz-complete` | Completion spam |

> ℹ️ The actual limits (requests/minute) are defined in `config/` throttle configuration. Document specific numbers when configuring for production.

---

## Secrets Management

### Current Approach

All secrets are managed via `.env` file:

| Secret | Variable | Location |
|---|---|---|
| Laravel encryption key | `APP_KEY` | `.env` |
| Database password | `DB_PASSWORD` | `.env` |
| Redis password | `REDIS_PASSWORD` | `.env` |
| Mobile API key | `MOBILE_API_KEY` | `.env` |
| OpenAI API key | `OPENAI_API_KEY` | `.env` |
| Resend API key | `RESEND_API_KEY` | `.env` |
| Sentry DSN | `SENTRY_LARAVEL_DSN` | `.env` |
| BetterStack token | `BETTER_STACK_SOURCE_TOKEN` | `.env` |
| Mapbox API key | `VITE_MAPBOX_API_KEY` | `.env` (frontend) |

### ❌ Past Security Incident

```
CRITICAL: src/services/openAIService.js was committed to version control
with sensitive credentials. The file was purged from all branches using:

  git filter-branch --force --index-filter \
    "git rm --cached --ignore-unmatch src/services/openAIService.js" \
    --prune-empty --tag-name-filter cat -- --all
```

> ⚠️ **Action Required**: The API key committed in that file should be considered **compromised** and must be rotated immediately. Verify it has been revoked in the OpenAI dashboard.

### Recommendations

1. **Rotate the OpenAI API key** — the git history purge does not protect the key if it was ever pushed to a remote before the purge, or if anyone cloned the repo.
2. **Implement a secrets vault**: HashiCorp Vault, AWS Secrets Manager, or Doppler for production secret management.
3. **Add `git-secrets` or `trufflehog`** pre-commit hooks to prevent future secret commits.
4. **Set `SESSION_SECURE_COOKIE=true`** in production `.env`.

---

## HTTPS / CORS / Security Headers

### CORS Configuration

Managed via `config/cors.php`, driven by `CORS_ALLOWED_ORIGINS` env var:

```php
// config/cors.php (actual source)
'paths'                => ['api/*', 'sanctum/csrf-cookie'],
'allowed_methods'      => ['*'],
'allowed_origins'      => array_filter(array_map('trim', explode(',', env('CORS_ALLOWED_ORIGINS')))),
'allowed_headers'      => ['*'],
'max_age'              => 86400,  // Preflight cached 24h → reduces OPTIONS overhead
'supports_credentials' => true,   // Required for Sanctum SPA cookie auth
```

**Default origin whitelist:**
```
https://plasir.dondzalandia.co.mz
https://test-plasir.dondzalandia.co.mz
http://localhost:3031
http://localhost:3032
http://localhost:3000
```

- Explicit origin whitelist — no wildcard `*` ✅
- `supports_credentials: true` — required for CSRF cookie flow ✅  
- Preflight cached 24h — reduces round-trips ✅
- Local dev origins included in defaults ⚠️ — must override `CORS_ALLOWED_ORIGINS` in production `.env` to remove `localhost` entries
- `SANCTUM_STATEFUL_DOMAINS` must match the frontend domain for SPA cookie auth ✅

### Vercel Deployment (Frontend)

```json
// vercel.json
{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
```

No explicit security headers configured at `vercel.json` level.

> ⚠️ **Recommendation**: Add security headers in `vercel.json` or Vercel project settings:
> ```
> Content-Security-Policy: default-src 'self'; ...
> X-Frame-Options: DENY
> X-Content-Type-Options: nosniff
> Referrer-Policy: strict-origin-when-cross-origin
> Permissions-Policy: geolocation=(), microphone=()
> ```

### HTTPS

- Production domains (`api.dondzalandia.co.mz`, `plasir.dondzalandia.co.mz`) serve over HTTPS ✅
- `SESSION_SECURE_COOKIE=false` in `.env.example` — **must be overridden to `true` in production** ⚠️

---

## Data Encryption

### At Rest

| Data | Encryption Status | Method |
|---|---|---|
| Passwords | ✅ Hashed | Bcrypt (12 rounds) |
| Session data | ❌ Plain text | `SESSION_ENCRYPT=false` |
| Database fields | ❌ Not encrypted | No field-level encryption |
| Disk storage | Not assessed | Depends on server/cloud config |

> ⚠️ **Recommendation**: Enable `SESSION_ENCRYPT=true` in production. Consider field-level encryption for sensitive medical data (anamnesis, diagnostic records) using Laravel's `encrypted` cast.

### In Transit

- Production API: HTTPS ✅
- Frontend to API: HTTPS ✅
- API to Redis: Unencrypted by default ⚠️ (add TLS if Redis is on a separate host)
- API to MySQL: Unencrypted by default ⚠️ (configure `DB_SSLMODE` for production)

---

## Mobile API Security

- Mobile routes (`/auth/mobile/*`) are protected by **`X-Mobile-API-Key`** header
- Key comparison uses `hash_equals()` (timing-safe) ✅
- If `MOBILE_API_KEY` is not set, the server returns 500 (fail-closed) ✅
- Mobile token management: Sanctum personal access tokens with `SANCTUM_EXPIRATION=120`

> ⚠️ **Recommendation**: The `MOBILE_API_KEY` is a single shared secret — if compromised, rotate it. Consider implementing per-device tokens for better revocation granularity.

---

## Third-Party Security

| Service | Security Consideration |
|---|---|
| **OpenAI** | AI triage prompts include child functional screening data — review DPA and data minimisation |
| **Resend** | Email delivery — configure SPF/DKIM/DMARC on `dondzalandia.co.mz` sending domain |
| **Sentry** | `SENTRY_SEND_DEFAULT_PII=false` ✅ — PII is not sent to Sentry |
| **Mapbox** | Public token — restrict by URL referrer in Mapbox dashboard |
| **BetterStack** | Log entries may contain user IDs and entity context — verify log retention policy |

### AI Report Data Scope

The `config/triage_ai_report.php` defines exactly what data is sent to OpenAI:

- **Prompt version**: `triage_report_v2` (file: `resources/ai/triage-report/prompts/triage_report_v2.txt`)
- **Schema version**: `triage_analysis_v2` (file: `resources/ai/triage-report/schemas/triage_analysis_v2.json`)
- **Max referrals per report**: 5
- **Stale threshold**: 90 seconds (reports older than this are regenerated)
- **Specialist catalog** (embedded in prompt — not PII):

| Domain | Specialists Recommended |
|---|---|
| school_history | Psicopedagogo, Psicologo Escolar |
| vision | Oftalmologista, Optometrista |
| hearing | Otorrinolaringologista |
| mobility | Fisioterapeuta, Fisiatra |
| cognition | Psicologo Clinico, Neuropediatra |
| communication | Terapeuta da Fala |
| autonomy | Terapeuta Ocupacional |
| mental_health | Psicologo Clinico — Saude Mental |
| urgent_referral | CERPIJs, MISAU, MTGAS |

> ⚠️ **GDPR / Data Protection**: The WGSS screening results (disability domain scores) for a child are sent to OpenAI for report generation. Review the OpenAI data processing agreement and confirm compliance with Mozambican child data protection regulations before enabling `TRIAGE_AI_REPORT_ENABLED=true` in production.

---

## Known Vulnerabilities & Recommendations

| # | Severity | Issue | Recommendation |
|---|---|---|---|
| 1 | 🔴 Critical | OpenAI API key previously committed to git | **Rotate key immediately** |
| 2 | 🔴 Critical | `SESSION_SECURE_COOKIE=false` in production risk | Set `SESSION_SECURE_COOKIE=true` in prod `.env` |
| 3 | 🟠 High | No secrets vault — all secrets in `.env` file | Implement Doppler / AWS Secrets Manager |
| 4 | 🟠 High | Session data not encrypted at rest | Enable `SESSION_ENCRYPT=true` |
| 5 | 🟠 High | No security headers on frontend (Vercel) | Add CSP, X-Frame-Options, etc. |
| 6 | 🟡 Medium | Super admin bootstrap allows unauthenticated registration if all admins deleted | Add guard to prevent last super admin deletion |
| 7 | 🟡 Medium | Child health data sent to OpenAI | Review data processing agreement; consider data minimisation |
| 8 | 🟡 Medium | Redis and MySQL connections unencrypted in transit (if on separate hosts) | Enable TLS for DB and Redis connections |
| 9 | 🟡 Medium | No pre-commit secret scanning hooks | Add `git-secrets` or `trufflehog` to CI/CD |
| 10 | 🟢 Low | `MOBILE_API_KEY` is a single shared secret | Consider per-device tokens for better revocation |
| 11 | 🟢 Low | Tiptap HTML output may need DOMPurify sanitization | Audit rendering of rich text in React |

---

## Security Checklist

| Category | Item | Status |
|---|---|---|
| **Auth** | Passwords hashed with Bcrypt (12 rounds) | ✅ |
| **Auth** | HTTP-only session cookies for SPA | ✅ |
| **Auth** | Secure cookie flag in production | ⚠️ Must configure |
| **Auth** | Session encrypted at rest | ❌ |
| **Auth** | Token expiration (SANCTUM_EXPIRATION) | ✅ |
| **Auth** | Password reset token stored hashed | ✅ |
| **AuthZ** | Route-level middleware guards | ✅ |
| **AuthZ** | Resource-level policies | ✅ |
| **AuthZ** | Tenant data isolation | ✅ |
| **Input** | Server-side validation (Form Requests) | ✅ |
| **Input** | Client-side validation (Zod) | ✅ |
| **SQL** | Parameterised queries (Eloquent) | ✅ |
| **XSS** | JSON API (no HTML rendering) | ✅ |
| **XSS** | React JSX auto-escaping | ✅ |
| **CSRF** | XSRF-TOKEN cookie + header validation | ✅ |
| **Rate** | Login throttle | ✅ |
| **Rate** | Password reset throttle | ✅ |
| **Rate** | Public endpoint throttle | ✅ |
| **Secrets** | `.env` not committed | ✅ |
| **Secrets** | `openAIService.js` purged from history | ✅ (post-incident) |
| **Secrets** | OpenAI key rotated | ❌ Must do |
| **Secrets** | Secrets vault | ❌ |
| **Secrets** | Pre-commit secret scanning | ❌ |
| **Transport** | HTTPS in production | ✅ |
| **Transport** | DB/Redis TLS | ⚠️ Unconfirmed |
| **Headers** | Security headers (CSP etc.) | ❌ |
| **CORS** | Explicit origin whitelist | ✅ |
| **PII** | Sentry PII disabled | ✅ |
| **Mobile** | Timing-safe key comparison | ✅ |
| **Mobile** | Mobile routes separate throttle | ✅ |
