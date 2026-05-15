# 09 — Strategic Evolution Roadmap & Architectural Alternatives

## Table of Contents
- [Assumptions](#assumptions)
- [Phase 3: Evolution Roadmap (30/60/90 Day)](#phase-3-evolution-roadmap-306090-day)
  - [Month 1 (Days 1-30): 🔥 Stabilization & Critical Fixes](#month-1-days-1-30--stabilization--critical-fixes)
  - [Month 2 (Days 31-60): 🚀 Scalability & Architecture](#month-2-days-31-60--scalability--architecture)
  - [Month 3 (Days 61-90): 🎯 Automation & Future-Proofing](#month-3-days-61-90--automation--future-proofing)
  - [Roadmap Success Metrics Summary](#roadmap-success-metrics-summary)
- [Phase 4: Architectural Alternatives](#phase-4-architectural-alternatives)
  - [Current Architecture Summary](#current-architecture-summary)
  - [Alternative 1: Event-Driven Architecture (EDA)](#alternative-1-event-driven-architecture-eda)
  - [Alternative 2: Microservices Architecture](#alternative-2-microservices-architecture)
  - [Alternative 3: Serverless Backend (BFF Pattern)](#alternative-3-serverless-backend-bff-pattern)
  - [Strategic Recommendation](#strategic-recommendation)

---

## Assumptions
Before executing this roadmap, we are operating under the following assumptions:
- **Current team size**: 3 developers (1 Backend, 1 Frontend, 1 Full-stack).
- **Current cloud budget**: ~$500/month (typical for early-stage production scaling).
- **Compliance requirements**: High. As a healthcare/educational platform handling children's data (PLASIR), compliance with local data privacy laws (e.g., GDPR equivalents) is mandatory. Medical data breaches are safeguarding failures.
- **Business criticality**: High. Customer-facing tool used by healthcare professionals and guardians.
- **Current technical debt level**: Medium-High. The system has solid architectural bones (Modular Monolith, Laravel 12) but suffers from "MVP debt" (e.g., DB-backed sessions, 3-query N+1 login bottlenecks, XSS-vulnerable token storage).

---

## Phase 3: Evolution Roadmap (30/60/90 Day)

### Month 1 (Days 1-30): 🔥 Stabilization & Critical Fixes
**Theme**: Production readiness, immediate risks eliminated

#### Week 1 (Days 1-7): Emergency fixes
- [ ] **Rotate OpenAI Key**: Immediately revoke the compromised OpenAI API key found in git history and issue a new one.
- [ ] **Fix Auth Storage**: Migrate SPA authentication to use pure HttpOnly cookies (Sanctum SPA mode). Remove the Bearer token from `sessionStorage` entirely to eliminate the XSS data breach vector.
- [ ] **Remove Default Passwords**: Delete hardcoded default passwords (e.g., `Dondza2025!`) from `config/auth.php` and implement a secure token-based password setup flow.

**Success metric**: Zero critical vulnerabilities. XSS no longer exposes authentication tokens.
**Blockers to resolve**: Requires admin access to the OpenAI platform to rotate keys.
**Risk if skipped**: Complete account takeover via XSS; financial drain via compromised AI keys.

#### Week 2 (Days 8-14): Observability foundation
- [ ] Switch `SESSION_DRIVER`, `CACHE_STORE`, and `QUEUE_CONNECTION` from `database` to `redis` in production.
- [ ] Implement `X-Request-ID` correlation ID tracing across the frontend (Axios interceptor) and backend (Sentry/BetterStack).

**Success metric**: Sessions no longer write to MySQL (removing the single DB write bottleneck); 100% of logs have trace IDs.

#### Week 3 (Days 15-21): Performance quick wins
- [ ] Optimize the login query bottleneck (BOTTLENECK-01) from 3-6 sequential queries down to a single optimized lookup.
- [ ] Fix the N+1 problem on login by caching the denormalized user role/entity payload.
- [ ] Parallelize the 5 *Triagem Universal* dashboard endpoints on the frontend using `Promise.all`.

**Success metric**: Login P95 latency drops from ~1.5s to < 200ms. Dashboard loads 3x faster.

#### Week 4 (Days 22-30): Documentation & knowledge transfer
- [ ] Set up pre-commit hooks (Husky, lint-staged, Laravel Pint) to enforce code quality locally.
- [ ] Add a basic GitHub Actions CI pipeline to run PHPUnit and Vitest before allowing merges to `main`.

**Success metric**: CI runs on every PR, blocking failing or unformatted code from reaching production.

---

### Month 2 (Days 31-60): 🚀 Scalability & Architecture
**Theme**: Horizontal scaling enabled, technical debt reduced

#### Week 5-6 (Days 31-44): Architecture refactoring
- [ ] Refactor the `EnsureEntityAccess` middleware to cache entity checks per user (60s TTL) to eliminate the per-request DB query overhead.
- [ ] Add a software circuit breaker for OpenAI API jobs to prevent the Laravel queue from backing up during AI service outages.
- [ ] Invalidate TanStack Query caches selectively on the frontend instead of globally clearing them on entity switch.

**Success metric**: Middleware adds < 5ms overhead per request. AI outages do not crash the queue system.
**Rollback plan**: Feature flag for middleware caching; can instantly revert to direct DB queries if cache desync occurs.

#### Week 7-8 (Days 45-60): Database optimization
- [ ] Configure a MySQL Read Replica and route all Universal Dashboard and analytics reporting queries to the `mysql_read` connection.
- [ ] Enforce server-side pagination on all list endpoints (e.g., `cadastro/children`, referrals) to prevent massive JSON payloads.
- [ ] Add a cron job (`schedule:run`) to prune old sessions, completed queue jobs, and soft-deleted children past retention periods.

**Success metric**: Primary Database CPU utilization stays under 40% during peak triage entry hours.
**Zero-downtime migration strategy**: Provision read replica -> Wait for sync -> Deploy backend `.env` and database config changes.

---

### Month 3 (Days 61-90): 🎯 Automation & Future-Proofing
**Theme**: Self-healing systems, developer productivity

#### Week 9-10 (Days 61-74): Full observability
- [ ] Implement strict account lockout (rate limiting by user ID, not just IP) for failed login attempts.
- [ ] Set up Prometheus/Grafana or BetterStack alerts for `QUEUE_HEALTH_MAX_PENDING`.
- [ ] Create incident response runbooks for the top 5 failure scenarios (e.g., Redis OOM, OpenAI timeout, MySQL connection exhaustion).

**Success metric**: MTTR (Mean Time to Recovery) < 30 minutes for infrastructure incidents.

#### Week 11-12 (Days 75-90): Developer experience
- [ ] Split the heavy MUI library into a separate Vite chunk (`vendor-mui`) to improve frontend initial load times.
- [ ] Implement a standardized local development environment using Docker Compose (PHP-FPM, Nginx, MySQL, Redis) to replace `php artisan serve`.
- [ ] Finalize the "Ownership V2" rules feature flag (`OWNERSHIP_CHILD_ACCESS_V2_ENABLED`) and roll it out safely via canary deployment.

**Success metric**: A new developer can spin up the full stack locally in under 15 minutes using `docker-compose up`.

---

### Roadmap Success Metrics Summary

| Metric | Current | Month 1 | Month 2 | Month 3 |
|--------|---------|---------|---------|---------|
| Max concurrent users | ~150 (est) | 300 | 750 | 1500+ |
| P99 response time | 1.5s+ | < 800ms | < 400ms | < 200ms |
| Deployment frequency | Manual | Weekly (CI) | 2x/week | Daily |
| MTTR (hours) | Unknown | <4 | <2 | <0.5 |
| Critical vulnerabilities | 3 | 0 | 0 | 0 |

---

## Phase 4: Architectural Alternatives

### Current Architecture Summary
- **Frontend**: React 18 SPA built with Vite, using MUI v5 and TanStack Query for state.
- **Backend**: Laravel 12 Modular Monolith (PHP 8.2+), using Eloquent ORM and Sanctum for Auth.
- **Database**: MySQL 8.0 (Primary) with Redis for caching/sessions.
- **Communication**: Synchronous REST/JSON over HTTPS.
- **Hosting**: Vercel (Frontend CDN), VPS/Docker (Backend API).

### Alternative 1: Event-Driven Architecture (EDA)
**Description**: Decouple services via message broker (Kafka/RabbitMQ/SQS)

**When to choose**:
- Complex workflows with multiple steps (e.g., Triage -> Waitlist -> AI Report -> Notification).
- Need for audit trails of state changes (e.g., tracking a child's entire clinical journey).
- Async processing acceptable (not real-time).

**Pros**:
1. **Scalability**: Each consumer scales independently.
2. **Resilience**: Broker buffers during downstream outages.
3. **Flexibility**: Add new consumers without changing producers.

**Cons**:
1. **Complexity**: Debugging distributed async flows is hard.
2. **Latency**: Not suitable for real-time responses.
3. **Exactly-once semantics**: Difficult to guarantee.

**Migration cost**: **High** (2-3 months)
- Requires message broker infrastructure.
- Rewrites synchronous calls to async.
- New error handling patterns (dead letter queues, retries).

**Code example snippet**:
```php
// Current: REST sync call (simplified)
$triage = Triage::create($data);
$this->waitingListService->add($triage->child);
$this->aiReportService->generate($triage);
return response()->json($triage);

// Event-driven alternative
$triage = Triage::create($data);
Event::dispatch(new TriageCompleted($triage));
// WaitingListListener and AiReportListener consume independently
return response()->json($triage);
```

### Alternative 2: Microservices Architecture
**Description**: Break the Laravel modular monolith into physical microservices (e.g., Auth Service, Patient Service, AI Service).

**When to choose**:
- The team grows to 15+ backend engineers requiring independent deployment pipelines.
- Different modules require drastically different scaling profiles or languages (e.g., rewriting the AI processing module in Python).

**Pros**:
1. **Independent Scaling**: Scale the Triage module separately from the Auth module.
2. **Polyglot Stack**: Allows mixing PHP, Python (for AI), and Node.js.
3. **Fault Isolation**: If the Assessment engine crashes, the core Cadastro system remains online.

**Cons**:
1. **Operational Overhead**: Requires Kubernetes/ECS, service meshes, and complex CI/CD.
2. **Data Consistency**: Distributed transactions and foreign key constraints across services become a nightmare.
3. **Overkill for Team Size**: A 3-person team will grind to a halt managing infrastructure.

**Migration cost**: **Extreme** (6+ months)
- Requires breaking the shared MySQL database into service-specific databases.
- Implementing an API Gateway.
- Complete rewrite of inter-module communication (from internal method calls to HTTP/gRPC).

### Alternative 3: Serverless Backend (BFF Pattern)
**Description**: Shift away from a heavy Laravel API to Serverless functions (AWS Lambda / Vercel Functions) acting as a Backend-For-Frontend, talking directly to a managed database like Supabase or PlanetScale.

**When to choose**:
- Highly variable traffic (e.g., massive spikes during school hours, zero traffic at night).
- Desire to eliminate server management entirely.

**Pros**:
1. **Zero Ops**: No servers or PHP-FPM to manage.
2. **Pay-for-What-You-Use**: Costs scale to zero during off-hours.
3. **Global Edge**: Functions can execute close to the user.

**Cons**:
1. **Cold Starts**: Initial latency penalties for functions.
2. **Vendor Lock-in**: Deeply tied to AWS or Vercel ecosystems.
3. **Framework Rewrite**: Laravel cannot easily be lifted-and-shifted to pure serverless functions without tools like Bref, which still have limitations.

**Migration cost**: **Extreme** (6+ months)
- Requires a complete rewrite of the backend logic.

### Strategic Recommendation
**Stick with the Modular Monolith (Current Architecture)**.

For a 3-person team building an internal/specialized healthcare application with a $500/mo budget, **moving to Microservices or Event-Driven Architecture right now is a premature optimization trap.**

The current architecture (Laravel 12 Modular Monolith + React SPA) is capable of handling millions of requests a day if the database and caching bottlenecks are fixed (as outlined in the 90-day roadmap). It provides the best balance of developer velocity, data consistency, and operational simplicity.

**Next step evolution**: If the AI processing becomes too heavy, extract *only* the AI report generation into an event-driven Python microservice via Redis queues, while keeping the rest of the application as a monolith.
