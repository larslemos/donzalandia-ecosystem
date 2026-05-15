# Security Audit Report — PLASIR / Dondzalândia

> **Auditor**: Principal Engineer / Security Architect review  
> **Date**: 2026-05-15  
> **Scope**: `dondza` (Laravel 12 API) + `dondza_cadastro` (React 18 SPA)  
> **Method**: Static code analysis of actual source files

---

## Executive Summary

| Severity | Count |
|---|---|
| 🔴 Critical | 3 |
| 🟠 High | 6 |
| 🟡 Medium | 7 |
| 🟢 Low | 4 |

**Ready for production**: ❌ — Critical issues must be resolved before handling real patient data.

---

## 🔴 Critical Issues (Fix Immediately)

---

### CRITICAL-01 — Bearer Token Stored in `sessionStorage` (XSS-Accessible)

**Location**: `dondza_cadastro/src/auth/context/jwt/utils.js:21` + `dondza_cadastro/src/auth/context/jwt/constant.js:1`

**Evidence**:
```js
// constant.js:1
export const STORAGE_KEY = 'jwt_access_token';

// utils.js:21
sessionStorage.setItem(STORAGE_KEY, access_token);

// axios.js:116
config.headers.Authorization = `Bearer ${accessToken}`;
```

**Risk**: Any JavaScript running on the page (XSS, malicious browser extension, injected script from a compromised CDN) can call `sessionStorage.getItem('jwt_access_token')` and steal the Bearer token. With the token, an attacker can impersonate the professional/admin for up to 120 minutes and access child health records, diagnoses, and referrals. This is a **medical data breach**.

**Why this matters more than usual**: The system handles sensitive child disability screening data — a breach is not just a compliance event, it's a safeguarding failure.

**Fix**: Migrate to HttpOnly cookie-only auth. The backend already supports Sanctum SPA cookies — remove the Bearer token from the client entirely.

```js
// utils.js — NEW: no token storage at all
export async function setSession(access_token) {
  // Sanctum SPA mode: the session cookie is managed by the browser automatically.
  // No client-side token storage needed.
  // Remove ALL references to sessionStorage for the token.
  if (!access_token) {
    delete axios.defaults.headers.common.Authorization;
  }
  // Do NOT store the token anywhere client-side.
}
```

```js
// axios.js — Remove the interceptor that reads from sessionStorage
// The cookie is sent automatically by withCredentials: true
axiosInstance.interceptors.request.use(async (config) => {
  // Remove: const accessToken = sessionStorage.getItem(STORAGE_KEY);
  // Remove: if (accessToken) { config.headers.Authorization = ... }
  // CSRF is already handled via xsrfCookieName/xsrfHeaderName
  return config;
});
```

**Effort**: M | **Confidence**: High — confirmed by direct code read.

---

### CRITICAL-02 — Hardcoded Default Passwords in `config/auth.php`

**Location**: `dondza/config/auth.php:126-134`

**Evidence**:
```php
'default_passwords' => [
    'guardian'      => env('AUTH_DEFAULT_PASSWORD_GUARDIAN', 'Guardian2025!'),
    'professional'  => env('AUTH_DEFAULT_PASSWORD_PROFESSIONAL', 'Professional2025!'),
    'tenant_admin'  => env('AUTH_DEFAULT_PASSWORD_TENANT_ADMIN', 'TenantAdmin2025!'),
    'secretary'     => env('AUTH_DEFAULT_PASSWORD_SECRETARY', 'Secretary2025!'),
],
'default_password' => env('AUTH_DEFAULT_PASSWORD', 'Dondza2025!'),
```

**Risk**: These passwords are **committed to Git** and visible to anyone with repo access. If the `.env` overrides are not set in production (they are absent from `.env.example`), all newly created accounts use these known passwords. An attacker who knows the registration email of any new user can log in immediately with `Dondza2025!` before that user sets their own password. Since `must_change_password=true` blocks login, the only attack window is between account creation and the setup link being clicked — but if the link is delayed or the email goes to spam, that window can be **days**.

**Fix**:
1. Remove hardcoded fallback values — fail loudly if env vars are not set:
```php
'default_passwords' => [
    'guardian'     => env('AUTH_DEFAULT_PASSWORD_GUARDIAN') 
        ?? throw new \RuntimeException('AUTH_DEFAULT_PASSWORD_GUARDIAN not set'),
    'professional' => env('AUTH_DEFAULT_PASSWORD_PROFESSIONAL')
        ?? throw new \RuntimeException('AUTH_DEFAULT_PASSWORD_PROFESSIONAL not set'),
],
```
2. Add all `AUTH_DEFAULT_PASSWORD_*` variables to `.env.example` with empty values.
3. **Better approach**: Don't assign ANY password at creation. Generate a cryptographically random temporary token instead. The user sets their real password via the email link only. Never store a guessable default.

**Effort**: S | **Confidence**: High.

---

### CRITICAL-03 — Previously Compromised OpenAI API Key (Rotation Not Confirmed)

**Location**: Git history (file purged: `src/services/openAIService.js`)  
**Evidence**: `git filter-branch` was run to purge the file, but the key was pushed to GitHub before the purge.

**Risk**: GitHub secret scanning may have already flagged this. More critically: **any clone made before the purge contains the key**. If the key is still active, it can be used to:
- Make expensive OpenAI API calls (financial damage)
- Access OpenAI fine-tuned models or org data
- Submit arbitrary prompts on behalf of the organisation

**Fix** (Non-negotiable):
```bash
# 1. Go to https://platform.openai.com/api-keys RIGHT NOW
# 2. Delete/revoke the old key
# 3. Create a new key
# 4. Update OPENAI_API_KEY in production .env
# 5. Verify no other services use the old key
```

**Effort**: XS | **Confidence**: High.

---

## 🟠 High Issues

---

### HIGH-01 — User Data (Roles/Entities) Cached in `localStorage` — Legacy Path Active

**Location**: `dondza_cadastro/src/utils/authCache.js:33-39` + `auth-storage.js:114-128`

**Evidence**:
```js
// authCache.js:33 — still reads from localStorage as fallback
if (!cached) {
  cached = localStorage.getItem(CACHE_KEYS.USER_DATA);
  if (cached) {
    sessionStorage.setItem(CACHE_KEYS.USER_DATA, cached);
    localStorage.removeItem(CACHE_KEYS.USER_DATA);
  }
}

// auth-storage.js:114 — legacy currentUser key still read
const legacyUser = readStorageItem(localStorage, LEGACY_CURRENT_USER_KEY); // 'currentUser'
```

**Risk**: `localStorage` persists across browser tabs and survives page close. If a user's role data (including `is_super_admin`) is read from localStorage during session initialisation and the server-side `/auth/me` call fails (network error, outage), the app falls back to stale cached roles. An attacker who gains `localStorage` access (shared device, XSS) can modify role data to elevate privileges client-side.

The security boundary relies entirely on the backend enforcing authorisation — which it does correctly. But the UX risk is that stale elevated permissions remain visible/navigable after a role change until cache expires (5 minutes TTL).

**Fix**:
```js
// authCache.js — remove all localStorage fallbacks
export function getCachedUserData() {
  try {
    const cached = sessionStorage.getItem(CACHE_KEYS.USER_DATA);
    // DO NOT read from localStorage as fallback
    if (!cached) return null;
    const { data, timestamp } = JSON.parse(cached);
    if (Date.now() - timestamp > CACHE_TTL) {
      sessionStorage.removeItem(CACHE_KEYS.USER_DATA);
      return null;
    }
    return data;
  } catch { return null; }
}
```

Also run a one-time migration to purge the `currentUser` key from any existing user's localStorage on app load:
```js
// In app initialisation (main.jsx or App.jsx)
localStorage.removeItem('currentUser');
localStorage.removeItem('auth_user_data');
localStorage.removeItem('auth_permissions');
localStorage.removeItem('auth_entities');
```

**Effort**: S | **Confidence**: High.

---

### HIGH-02 — No Account Lockout After Failed Login Attempts

**Location**: `dondza/app/Modules/Auth/UseCases/LoginUseCase.php` (no lockout logic)  
`dondza/routes/api.php:103` — only IP-based throttle via `throttle:auth-login`

**Risk**: Laravel's named throttle is **IP-based**. An attacker can:
1. Rotate IPs (proxies, botnets, Tor) to bypass IP throttle
2. Target a known email address with unlimited password attempts across IPs

No account lockout exists at the application level. For a platform holding child medical records, this is unacceptable.

**Fix** — Add per-account failed attempt counter:
```php
// In LoginUseCase — after Hash::check fails:
use Illuminate\Support\Facades\Cache;

$lockKey = 'login_fails_' . $user->id;
$failures = Cache::increment($lockKey);
Cache::put($lockKey, $failures, now()->addMinutes(15));

if ($failures >= 5) {
    return [
        'body' => ['message' => 'Conta temporariamente bloqueada. Tente novamente em 15 minutos.'],
        'status' => 429,
    ];
}
```

On successful login, clear the counter:
```php
Cache::forget('login_fails_' . $user->id);
```

**Effort**: S | **Confidence**: High.

---

### HIGH-03 — Email Enumeration via `resendWelcomeEmail` and `forgotPassword`

**Location**: `dondza/app/Modules/Auth/Controllers/AuthController.php:191-193` and `forgotPassword`

**Evidence**:
```php
// resendWelcomeEmail — explicit email existence check
$request->validate([
    'email' => ['required', 'email', 'exists:users,email'], // ← reveals email existence
]);
```

**Risk**: An unauthenticated attacker can POST any email to `/auth/resend-welcome-email` and `/auth/forgot-password` and determine if that email is registered. Response timing and validation errors differ. For a healthcare platform with identifiable guardians and professionals, revealing who is registered is a privacy violation.

**Fix**: Always return the same generic response regardless of whether the email exists:
```php
public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
{
    // Remove 'exists:users,email' from validation
    // The UseCase should silently do nothing if the email doesn't exist
    $result = app(ForgotPasswordUseCase::class)->execute($request->input('email'));
    
    // Always return 200 with same message
    return response()->json([
        'message' => 'Se o email estiver registado, receberá as instruções em breve.'
    ], 200);
}
```

**Effort**: S | **Confidence**: High.

---

### HIGH-04 — Setup Password URL Built with SHA1(email)

**Location**: `dondza/app/Modules/Auth/UseCases/LoginUseCase.php:197`

**Evidence**:
```php
$hash = sha1($user->email); // ← SHA1 is broken for security purposes
```

**Risk**: SHA1 is cryptographically broken. A rainbow table of SHA1(email) hashes for common emails exists publicly. If an attacker knows the user's email (discoverable via enumeration), they can compute `sha1(email)` trivially, and need only the HMAC signature to forge a valid setup URL. The HMAC uses `config('app.key')` which is secure — this is the real protection. But using SHA1 for the `hash` component is a code smell and reduces defense in depth.

**Fix**:
```php
// Replace sha1 with a secure random token
$hash = bin2hex(random_bytes(32)); // 64-char hex, not derived from email
// Store the hash in the DB linked to the user, validate on redemption
```

**Effort**: M | **Confidence**: Medium (HMAC signature provides the real protection; this is defense-in-depth).

---

### HIGH-05 — `SESSION_SECURE_COOKIE=false` in `.env.example` — Production Risk

**Location**: `dondza/.env.example:63`

**Evidence**:
```env
SESSION_SECURE_COOKIE=false
```

**Risk**: If a production server is misconfigured and served over plain HTTP (redirect misconfiguration, internal load balancer terminating TLS), session cookies will be transmitted unencrypted. More critically, if a developer copies `.env.example` to `.env` for a staging environment and forgets to change this, staging runs with insecure cookies.

**Fix**: Change the example default, add a comment:
```env
# MUST be true in production (HTTPS only). Only set false for local HTTP dev.
SESSION_SECURE_COOKIE=false
```
And add a boot-time assertion:
```php
// In AppServiceProvider::boot()
if (app()->isProduction() && !config('session.secure')) {
    throw new \RuntimeException('SESSION_SECURE_COOKIE must be true in production.');
}
```

**Effort**: XS | **Confidence**: High.

---

### HIGH-06 — Dual Auth Mode Confusion (Cookie + Bearer Token Simultaneously)

**Location**: `dondza_cadastro/src/utils/axios.js:113-118` + backend Sanctum config

**Evidence**:
```js
// Sends BOTH a session cookie AND a Bearer token on every request
const accessToken = sessionStorage.getItem(STORAGE_KEY);
if (accessToken) {
  config.headers.Authorization = `Bearer ${accessToken}`;
}
// withCredentials: true also sends the session cookie
```

**Risk**: The system simultaneously sends session cookies (SPA stateful mode) AND `Authorization: Bearer <token>` headers. Sanctum resolves auth by checking the Bearer token first if present. This means:
1. The session cookie is never the authoritative auth mechanism when a token exists
2. The cookie's session is maintained but not used — orphaned session rows accumulate in the DB
3. The "stateless" token path bypasses some CSRF protections that only apply to the stateful cookie path
4. Logout revokes the Sanctum token correctly, but the orphaned web session may persist

**Fix**: Commit to **one** auth mode. Recommended: pure SPA cookie mode (HttpOnly, no Bearer token):
```php
// Remove token issuance from LoginUseCase — don't return access_token in response
// Use only: Auth::login($user) + session()->regenerate()
```

```js
// Remove all token storage and Authorization header logic from axios.js
// Rely purely on withCredentials: true + XSRF-TOKEN cookie
```

**Effort**: L | **Confidence**: High.

---

## 🟡 Medium Issues

---

### MEDIUM-01 — No MFA for Privileged Accounts

**Risk**: Super admins and lead specialists accessing child health records have no second factor. A compromised password (phishing, reuse) gives full system access. For a healthcare platform handling sensitive minor data, MFA is a compliance expectation.

**Recommendation**: Implement TOTP (Google Authenticator / Authy) for `is_super_admin` accounts as a first step, using `laravel-google2fa` or similar. Session-based MFA challenge after password verification.

---

### MEDIUM-02 — No Password Strength Policy

**Location**: `LoginRequest` and `RegisterRequest` validation rules not inspected; `SetupPasswordRequest` likely has basic validation.

**Risk**: No evidence of minimum length > 8, complexity requirements, or breach database checks (HaveIBeenPwned API). Default passwords are strong (e.g., `Professional2025!`) but user-chosen passwords may be weak.

**Fix**: Add a Zxcvbn or HaveIBeenPwned check in the `SetupPasswordRequest` and `ResetPasswordRequest` validators:
```php
'password' => ['required', 'confirmed', 'min:12', new NotCompromisedPassword()],
```

---

### MEDIUM-03 — Login Accepts Phone Number as Identifier (Unthrottled Path)

**Location**: `LoginUseCase.php:181-190` — `resolveUserByIdentifier` performs 3 sequential DB queries per login attempt (child code → email → phone).

**Risk**: The phone lookup (`DB::table('person')->where('phone', $identifier)`) runs on every failed email lookup. This:
1. Leaks timing information (phone matches are slower than email matches)
2. Allows phone-based user enumeration
3. Creates a 3-query load on every login attempt

**Fix**: Consolidate to a single query or parallel lookups. If phone login is required, create a dedicated endpoint with its own throttle and validation.

---

### MEDIUM-04 — Logs Written to Local Disk (No Rotation Guard)

**Location**: `config/logging.php:82-84`

**Evidence**:
```php
'single' => [
    'driver' => 'single',  // Single unbounded file
    'path'   => storage_path('logs/laravel.log'),
    'level'  => env('LOG_LEVEL', 'debug'),
],
```

**Risk**: The `single` driver writes to an unbounded file. `LOG_LEVEL=debug` in dev (and potentially staging) logs full request data including query results. On a VPS with limited disk, this can cause a disk-full outage. In production with `debug` level, sensitive data (user IDs, entity IDs, form payloads) is logged.

**Fix**: Ensure production uses `daily` driver, not `single`. Add to AppServiceProvider:
```php
if (app()->isProduction() && config('logging.default') === 'single') {
    \Log::warning('Production is using single log driver — potential disk exhaustion');
}
```

---

### MEDIUM-05 — No CSP or Security Headers on Vercel Frontend

**Location**: `dondza_cadastro/vercel.json` — only contains SPA rewrite rule.

**Risk**: Without a Content-Security-Policy, any XSS vulnerability allows arbitrary script execution. Without `X-Frame-Options: DENY`, the app can be embedded in an iframe for clickjacking. Without `X-Content-Type-Options: nosniff`, MIME sniffing attacks are possible.

**Fix** (add to `vercel.json`):
```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "X-XSS-Protection", "value": "1; mode=block" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
        { "key": "Content-Security-Policy", "value": "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self' https://api.dondzalandia.co.mz https://sentry.io https://*.mapbox.com; img-src 'self' data: blob: https:;" }
      ]
    }
  ],
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

---

### MEDIUM-06 — `verifyEmail` Uses `sha1(email)` for Hash Comparison

**Location**: `AuthController.php:155`

**Evidence**:
```php
if (!hash_equals(sha1($user->email), $hash)) {
```

Same SHA1 issue as HIGH-04. The `hash_equals` makes it timing-safe, but the hash itself is trivially computable from the email address. Should use a random token stored in the DB.

---

### MEDIUM-07 — `SESSION_ENCRYPT=false` — Session Data Unencrypted at Rest

**Location**: `dondza/.env.example:59`

**Risk**: Session rows in the `sessions` table are stored in plain text. Anyone with DB read access can read session data including the authenticated user context. This is relevant if DB backups are compromised or a SQL injection were found in another part of the codebase.

**Fix**: Set `SESSION_ENCRYPT=true` in production `.env`.

---

## 🟢 Low Issues

---

### LOW-01 — `APP_DEBUG=true` Default in `.env.example`

Stack traces with file paths, class names, and query details would be exposed to clients if a developer copies `.env.example` to production without changing this.

**Fix**: Change `.env.example` default to `APP_DEBUG=false`. Add boot assertion as per HIGH-05 pattern.

---

### LOW-02 — CORS `max_age=86400` with `allowed_headers=['*']`

Caching a preflight for 24 hours with wildcard allowed headers means new header restrictions won't take effect for 24 hours after a config change. Low risk but reduces the ability to quickly lock down access.

---

### LOW-03 — No `Permissions-Policy` Header

The frontend uses Mapbox (geolocation), potentially microphone for audio exercises. A `Permissions-Policy` header should explicitly declare which browser features are used and block all others.

```
Permissions-Policy: geolocation=(self), microphone=(), camera=(), payment=()
```

---

### LOW-04 — `console.log` / `console.error` Calls in Production Code

**Location**: Multiple files in `dondza_cadastro/src/utils/` include `console.error(...)` calls that may log sensitive data (user IDs, error objects with API responses) to the browser console in production.

**Fix**: Replace with structured Sentry captures in production or gate behind `import.meta.env.DEV` checks.

---

## Remediation Priority Order

| Priority | Issue | Effort | Impact |
|---|---|---|---|
| 1 | CRITICAL-03 — Rotate OpenAI key | XS | Immediate financial + data risk |
| 2 | CRITICAL-02 — Remove hardcoded passwords | S | Account takeover on creation |
| 3 | HIGH-05 — SESSION_SECURE_COOKIE | XS | Cookie hijacking in HTTP |
| 4 | HIGH-02 — Account lockout | S | Brute force on any account |
| 5 | HIGH-03 — Email enumeration | S | Privacy / GDPR |
| 6 | CRITICAL-01 — Token in sessionStorage | M | XSS token theft → data breach |
| 7 | HIGH-06 — Dual auth mode cleanup | L | Architecture debt + CSRF gaps |
| 8 | HIGH-01 — localStorage legacy removal | S | Role data from stale cache |
| 9 | MEDIUM-05 — Security headers | XS | XSS blast radius reduction |
| 10 | MEDIUM-07 — Session encryption | XS | DB breach scope reduction |
