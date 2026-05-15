# 03 — API Documentation

## Table of Contents
- [Base URL & Authentication](#base-url--authentication)
- [Global Headers](#global-headers)
- [Rate Limiting](#rate-limiting)
- [Response Format](#response-format)
- [Status Codes](#status-codes)
- [Health Check](#health-check)
- [Auth Endpoints](#auth-endpoints)
- [Location Endpoints](#location-endpoints-public)
- [Cadastro — Entities](#cadastro--entities)
- [Cadastro — Users](#cadastro--users)
- [Cadastro — Children](#cadastro--children)
- [Cadastro — Guardians](#cadastro--guardians)
- [Cadastro — Specialties](#cadastro--specialties)
- [Académico — Grades / Classrooms / Subjects](#académico)
- [Screening / Triagem](#screening--triagem)
- [Waiting List](#waiting-list)
- [Referrals](#referrals)
- [Plasir — Anamnesis & Consultation](#plasir--anamnesis--consultation)
- [DiagnosticoNEE](#diagnosticonee)
- [Assessment — Tests / Exercises / Quiz / Results](#assessment)
- [Dashboard](#dashboard)
- [Guardian App (Mobile)](#guardian-app-mobile)
- [cURL Examples](#curl-examples)

---

## Base URL & Authentication

| Environment | Base URL |
|---|---|
| Production | `https://api.dondzalandia.co.mz/api` |
| Local dev | `http://localhost:8000/api` |

### Authentication Methods

**1. SPA (Web Frontend) — Sanctum Cookie**
```
POST /api/auth/login → sets Laravel session cookie
Subsequent requests automatically send XSRF-TOKEN + session cookie
```

**2. Mobile App — Bearer Token + API Key**
```
Header: X-Mobile-API-Key: <MOBILE_API_KEY>
Header: Authorization: Bearer <sanctum_token>
```

**3. Super Admin endpoints** — require authenticated user with `is_super_admin = true`.

---

## Global Headers

| Header | Required | Value |
|---|---|---|
| `Accept` | ✅ | `application/json` |
| `Content-Type` | POST/PUT | `application/json` |
| `X-XSRF-TOKEN` | SPA | Auto-set from cookie |
| `X-Mobile-API-Key` | Mobile routes | `<MOBILE_API_KEY env var>` |

---

## Rate Limiting

| Named Limit | Applied To | Limit |
|---|---|---|
| `auth-login` | `POST /auth/login` | Configured in `config/auth.php` throttle |
| `auth-mobile-login` | `POST /auth/mobile/login` | Separate mobile limit |
| `auth-forgot-password` | `POST /auth/forgot-password` | Brute-force protection |
| `auth-reset-password` | `POST /auth/reset-password` | Per-token limit |
| `auth-setup-password` | `POST /auth/setup-password` | Per-token limit |
| `location-public` | `GET /location/provinces|districts` | Public throttle |
| `quiz-start` | `POST /assessment/quiz/start` | Per-user limit |
| `quiz-answers` | `POST /assessment/quiz/answers` | Per-user limit |
| `quiz-batch` | `POST /assessment/quiz/answers/batch` | Per-user limit |
| `quiz-complete` | `POST /assessment/quiz/complete` | Per-user limit |

---

## Response Format

### Success (2xx)
```json
{
  "data": { ... },
  "message": "Optional success message"
}
```

### Error (4xx / 5xx)
```json
{
  "message": "Human-readable error description"
}
```

### Validation Error (422)
```json
{
  "message": "The given data was invalid.",
  "errors": {
    "field_name": ["Validation message"]
  }
}
```

---

## Status Codes

| Code | Meaning |
|---|---|
| 200 | OK |
| 201 | Created |
| 204 | No Content (successful delete) |
| 400 | Bad Request |
| 401 | Unauthenticated |
| 403 | Forbidden (insufficient role / entity access) |
| 404 | Not Found |
| 422 | Validation Error |
| 429 | Too Many Requests |
| 503 | Service Unavailable (health check degraded) |

---

## Health Check

### `GET /health/ready`
Returns the readiness status of the API (DB + Redis connectivity).

**Auth:** None (public)

**Response 200 — Healthy:**
```json
{ "status": "ok", "checks": { "db": "ok", "redis": "ok" } }
```

**Response 503 — Degraded:**
```json
{ "status": "degraded", "checks": { "db": "ok", "redis": "error" } }
```

---

## Auth Endpoints

### `POST /auth/login`
Authenticate a user. Sets a session cookie for SPA clients.

**Auth:** Public | **Throttle:** `auth-login`

**Request:**
```json
{ "email": "user@example.com", "password": "secret" }
```

**Response 200:**
```json
{
  "user": { "id": "uuid", "email": "...", "is_super_admin": false, "main_role": "professional" },
  "entity": { "id": "uuid", "name": "Escola XYZ" },
  "token": "1|abc..."
}
```

---

### `POST /auth/register`
Register a new user. **Super admin only** (or first setup if no super admin exists).

**Auth:** `EnsureSuperAdmin`

**Request:**
```json
{
  "email": "newuser@example.com",
  "name": "Full Name",
  "entity_id": "uuid",
  "role": "professional"
}
```

---

### `POST /auth/register-guardian`
Register a guardian account (public — for parent onboarding).

**Auth:** Public

---

### `POST /auth/mobile/login`
Mobile app login. Identical to `/auth/login` but requires `X-Mobile-API-Key` header.

**Auth:** `EnsureMobileApiKey` | **Throttle:** `auth-mobile-login`

---

### `GET /auth/setup-password/{id}/{hash}`
Validate a setup-password link (sent by email). Returns link validity status.

**Auth:** Public

---

### `POST /auth/setup-password`
Complete initial password setup from welcome email.

**Auth:** Public | **Throttle:** `auth-setup-password`

**Request:**
```json
{ "id": "uuid", "hash": "...", "password": "newPassword123", "password_confirmation": "newPassword123" }
```

---

### `POST /auth/verify-email`
Verify email address via token.

**Auth:** Public

---

### `POST /auth/forgot-password`
Send a password reset email.

**Auth:** Public | **Throttle:** `auth-forgot-password`

**Request:**
```json
{ "email": "user@example.com" }
```

---

### `GET /auth/reset-password/validate`
Validate a password-reset token before showing the reset form.

**Auth:** Public

---

### `POST /auth/reset-password`
Reset password using a valid token.

**Auth:** Public | **Throttle:** `auth-reset-password`

---

### `POST /auth/resend-welcome-email`
Resend the welcome / verification email.

**Auth:** Public (by email) or Super Admin (by `user_id`)

---

### `GET /auth/me`
Return the currently authenticated user and their active entity.

**Auth:** `auth:sanctum`

**Response 200:**
```json
{
  "user": { "id": "uuid", "email": "...", "is_super_admin": false },
  "entity": { "id": "uuid", "name": "Escola XYZ" }
}
```

---

### `POST /auth/logout`
Revoke the current session / token.

**Auth:** `auth:sanctum`

---

### `POST /auth/switch-entity`
Switch the active entity context for a multi-entity user.

**Auth:** `auth:sanctum`

**Request:**
```json
{ "entity_id": "uuid" }
```

---

## Location Endpoints (Public)

### `GET /location/provinces`
List all Mozambican provinces.

**Auth:** Public | **Throttle:** `location-public`

### `GET /location/districts`
List districts, optionally filtered by `?province_id=`.

**Auth:** Public | **Throttle:** `location-public`

### `GET /location/neighborhoods`
List neighborhoods. *(Requires auth)*

### `POST /location/autocomplete`
Autocomplete address search.

### `POST /location/geocode`
Convert address string to coordinates.

### `POST /location/reverse-geocode`
Convert coordinates to address.

---

## Cadastro — Entities

> All write operations require `EnsureSuperAdmin`.

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/cadastro/entities` | `auth:sanctum` | List entities (super admin: all; tenant: own) |
| GET | `/cadastro/entities/{id}` | `auth:sanctum` | Get entity detail |
| GET | `/cadastro/entities/stats` | Super Admin | Aggregate statistics across all entities |
| POST | `/cadastro/entities` | Super Admin | Create new entity |
| PUT | `/cadastro/entities/{id}` | Super Admin | Update entity |
| DELETE | `/cadastro/entities/{id}` | Super Admin | Delete entity |

**Entity object:**
```json
{
  "id": "uuid",
  "name": "Escola Primária Central",
  "code_prefix": "EPC",
  "province_id": 1,
  "district_id": 5,
  "created_at": "2026-01-01T00:00:00Z"
}
```

---

### Entity Responsible Professionals

| Method | Path | Description |
|---|---|---|
| GET | `/cadastro/entities/{entity}/responsible-professionals` | List responsible professionals |
| POST | `/cadastro/entities/{entity}/responsible-professionals` | Assign professional |
| PUT | `/cadastro/entities/{entity}/responsible-professionals/{professional}` | Update assignment |
| DELETE | `/cadastro/entities/{entity}/responsible-professionals/{professional}` | Remove assignment |

---

## Cadastro — Users

> Requires `EnsureEntityAccess`.

| Method | Path | Description |
|---|---|---|
| GET | `/cadastro/users` | List users in entity |
| POST | `/cadastro/users` | Create user |
| GET | `/cadastro/users/{user}` | Get user |
| PUT | `/cadastro/users/{user}` | Update user |
| DELETE | `/cadastro/users/{user}` | Soft-delete user |
| DELETE | `/cadastro/users/trash/{user}/force` | Permanently delete user |

**GET `/professionals/all`** — Super Admin only: list all professionals across all entities (for referral targeting).

---

## Cadastro — Children

> Requires `EnsureEntityAccess`.

| Method | Path | Description |
|---|---|---|
| GET | `/cadastro/children` | List children in entity |
| POST | `/cadastro/children` | Register new child |
| GET | `/cadastro/children/{id}` | Get child detail |
| PUT | `/cadastro/children/{id}` | Update child |
| DELETE | `/cadastro/children/{id}` | Soft-delete child |
| GET | `/cadastro/children/stats` | Entity child statistics |
| GET | `/cadastro/children/trash` | List soft-deleted children |
| PUT | `/cadastro/children/trash/{id}/restore` | Restore soft-deleted child |
| DELETE | `/cadastro/children/trash/{id}/force` | Permanent delete |

---

## Cadastro — Guardians

| Method | Path | Description |
|---|---|---|
| GET | `/cadastro/guardians` | List guardians in entity |
| GET | `/cadastro/guardians/{guardian}` | Get guardian detail |

---

## Cadastro — Specialties

| Method | Path | Description |
|---|---|---|
| GET | `/cadastro/specialties` | List professional specialties |

---

## Académico

### Grades

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/academico/grades` | `auth:sanctum` | List all grades |
| GET | `/academico/grades/{id}` | `auth:sanctum` | Get grade |
| POST | `/academico/grades` | Super Admin | Create grade |
| PUT | `/academico/grades/{id}` | Super Admin | Update grade |
| DELETE | `/academico/grades/{id}` | Super Admin | Delete grade |

### Classrooms

Full CRUD via `apiResource('academico/classrooms')` — requires `EnsureEntityAccess`.

### Subjects

Full CRUD — Super Admin only:
- `GET /academico/subjects`, `POST`, `PUT /{id}`, `DELETE /{id}`
- `GET /academico/subject-bases` — list subject base categories
- `POST /academico/subject-bases` — create base category

### Skills & Competences

Full CRUD — Super Admin only (`apiResource`):
- `/academico/skills`
- `/academico/competences`

---

## Screening / Triagem

> Requires `EnsureEntityAccess`.

| Method | Path | Description |
|---|---|---|
| GET | `/screening/triages` | List triages / screenings |
| POST | `/screening/triages` | Create triage record |
| GET | `/screening/triages/{id}` | Get triage |
| PUT | `/screening/triages/{id}` | Update triage |
| DELETE | `/screening/triages/{id}` | Delete triage |
| GET | `/screening/triages/dashboard` | Triage dashboard stats |
| GET | `/screening/triages/stats` | Aggregate stats |
| GET | `/screening/manual-signalizations` | List manual signalizations |
| GET | `/screening/manual-signalizations/{id}` | Get signalization |
| POST | `/screening/manual-signalizations` | Create manual signalization |
| GET | `/screening/signalizations/dashboard` | Signalization dashboard |
| GET | `/screening/signalizations/summary` | Signalization summary |

### AI Triage Reports

| Method | Path | Description |
|---|---|---|
| GET | `/screening/triage-ai-report/child/{childId}` | Get AI report for child |
| POST | `/screening/triage-ai-report/child/{childId}/ensure` | Generate if not exists |
| POST | `/screening/triage-ai-report/child/{childId}/retry` | Retry failed generation |

### Triagem Universal (Analytics Dashboard — 5 tabs)

| Method | Path | Description |
|---|---|---|
| GET | `/screening/triagem-universal/overview` | Overview statistics |
| GET | `/screening/triagem-universal/functional-profile` | Functional profile breakdown |
| GET | `/screening/triagem-universal/question-analysis` | Per-question analysis |
| GET | `/screening/triagem-universal/equidade` | Equity / geographic map data |
| GET | `/screening/triagem-universal/risk-profiles` | Risk profile distribution |

---

## Waiting List

> Requires `EnsureEntityAccess`.

| Method | Path | Description |
|---|---|---|
| GET | `/waiting-list` | List waiting list entries (supports `?search=`) |
| PUT | `/waiting-list/{id}/close` | Close / resolve a waiting list entry |
| PUT | `/waiting-list/{id}/priority` | Update entry priority |

---

## Referrals

> Requires `EnsureEntityAccess`.

| Method | Path | Description |
|---|---|---|
| GET | `/referrals` | List referrals created by current user |
| POST | `/referrals` | Create referral to another specialist |
| GET | `/referrals/inbox` | Referrals received by current user |
| GET | `/referrals/available-professionals` | List professionals available for referral |
| PUT | `/referrals/{id}/return` | Return / reject a referral |

### Referral Reports

| Method | Path | Description |
|---|---|---|
| GET | `/referrals/{referralId}/report` | Get investigation report |
| POST | `/referrals/{referralId}/report` | Create / upsert report |
| PUT | `/referrals/{referralId}/report` | Update report |
| POST | `/referrals/{referralId}/report/submit` | Submit completed report |

---

## Plasir — Anamnesis & Consultation

> Requires `EnsureEntityAccess`.

| Method | Path | Description |
|---|---|---|
| GET | `/plasir/anamneses` | List anamneses |
| POST | `/plasir/anamneses` | Create anamnesis |
| GET | `/plasir/anamneses/{id}` | Get anamnesis |
| PUT | `/plasir/anamneses/{id}` | Update anamnesis |
| DELETE | `/plasir/anamneses/{id}` | Delete anamnesis |
| GET | `/plasir/anamneses/dashboard` | Anamnesis dashboard |
| GET | `/plasir/anamneses/summary` | Anamnesis summary |
| GET | `/plasir/consultations` | List consultations |
| POST | `/plasir/consultations` | Create consultation |
| GET | `/plasir/consultations/{id}` | Get consultation |
| PUT | `/plasir/consultations/{id}` | Update consultation |
| DELETE | `/plasir/consultations/{id}` | Delete consultation |
| GET | `/plasir/student-history/{id}` | Full student clinical history |

---

## DiagnosticoNEE

> Requires `EnsureEntityAccess`.

| Method | Path | Description |
|---|---|---|
| GET | `/diagnostico/diagnostics` | List diagnostics |
| POST | `/diagnostico/diagnostics` | Create diagnostic |
| GET | `/diagnostico/diagnostics/{id}` | Get diagnostic |
| PUT | `/diagnostico/diagnostics/{id}` | Update |
| DELETE | `/diagnostico/diagnostics/{id}` | Delete |
| GET | `/diagnostico/dashboard` | Diagnostic dashboard |
| GET | `/diagnostico/summary` | Summary |
| GET | `/diagnostico/hypotheses` | List hypotheses |
| POST | `/diagnostico/hypotheses` | Create hypothesis |
| GET | `/diagnostico/hypotheses/referred-to-me` | Referrals assigned to me |
| GET | `/diagnostico/instruments` | List instruments |
| POST | `/diagnostico/instruments` | Create instrument |
| GET | `/diagnostico/referrals` | Child referrals |
| POST | `/diagnostico/referrals` | Create child referral |
| GET | `/diagnostico/referrals/active/{childId}` | Active referral for child |
| GET | `/diagnostico/final-diagnostics` | Final diagnostics list |
| POST | `/diagnostico/final-diagnostics` | Create final diagnostic |
| GET | `/diagnostico/timeline-events` | Timeline events |
| POST | `/diagnostico/timeline-events` | Log timeline event |

---

## Assessment

### Tests & Exercises (Super Admin)

| Method | Path | Description |
|---|---|---|
| GET | `/assessment/tests` | List tests |
| POST | `/assessment/tests` | Create test |
| GET | `/assessment/tests/{id}` | Get test |
| PUT | `/assessment/tests/{id}` | Update test |
| DELETE | `/assessment/tests/{id}` | Delete test |
| POST | `/assessment/tests/{id}/publish` | Publish test |
| POST | `/assessment/tests/{id}/unpublish` | Unpublish test |
| GET | `/assessment/exercises` | List exercises |
| POST | `/assessment/exercises` | Create exercise |
| GET | `/assessment/tests/{testId}/exercises` | Exercises for a specific test |

### Quiz (Student flow — authenticated, no entity required)

| Method | Path | Throttle | Description |
|---|---|---|---|
| POST | `/assessment/quiz/start` | `quiz-start` | Start a quiz session |
| POST | `/assessment/quiz/answers` | `quiz-answers` | Save a single answer |
| POST | `/assessment/quiz/answers/batch` | `quiz-batch` | Save multiple answers |
| GET | `/assessment/quiz/{resultId}/progress` | — | Get quiz progress |
| POST | `/assessment/quiz/complete` | `quiz-complete` | Submit & complete quiz |

### Results (Entity-scoped)

| Method | Path | Description |
|---|---|---|
| GET | `/assessment/results` | List results for entity |
| GET | `/assessment/results/{id}` | Get result detail |
| GET | `/assessment/results/{id}/score` | Get computed score |

---

## Dashboard

> Requires `EnsureEntityAccess`.

| Method | Path | Description |
|---|---|---|
| GET | `/dashboard/overview` | High-level KPIs |
| GET | `/dashboard/entity-stats` | Entity-specific statistics |

---

## Guardian App (Mobile)

> Requires `auth:sanctum`. Guardian-scoped (no entity_id required).

| Method | Path | Description |
|---|---|---|
| GET | `/guardian/my-children` | List guardian's own children |
| GET | `/guardian/children/{id}` | Child detail |
| POST | `/guardian/children` | Register new child |
| GET | `/guardian/schools` | List available schools |
| GET | `/guardian/grades` | List available grades |
| POST | `/guardian/school-history` | Submit school history |
| POST | `/guardian/vision` | Submit vision screening |
| POST | `/guardian/hearing` | Submit hearing screening |
| POST | `/guardian/mobility` | Submit mobility screening |
| POST | `/guardian/cognition` | Submit cognition screening |
| POST | `/guardian/communication` | Submit communication screening |
| POST | `/guardian/autonomy` | Submit autonomy screening |
| POST | `/guardian/mental-health` | Submit mental health screening |

---

## cURL Examples

### Login
```bash
curl -X POST https://api.dondzalandia.co.mz/api/auth/login \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"secret"}'
```

### Get Children (with auth token)
```bash
curl https://api.dondzalandia.co.mz/api/cadastro/children?entity_id=<uuid> \
  -H "Accept: application/json" \
  -H "Authorization: Bearer <token>"
```

### Create Triage
```bash
curl -X POST https://api.dondzalandia.co.mz/api/screening/triages \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"child_id":"uuid","entity_id":"uuid","form_data":{...}}'
```

### Health Check
```bash
curl https://api.dondzalandia.co.mz/api/health/ready
```

### Mobile Login
```bash
curl -X POST https://api.dondzalandia.co.mz/api/auth/mobile/login \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "X-Mobile-API-Key: <MOBILE_API_KEY>" \
  -d '{"email":"guardian@example.com","password":"secret"}'
```

> 📌 **Scribe Docs**: Run `php artisan scribe:generate` in the backend to produce full interactive API docs from code annotations. Output is written to `.scribe/`.
