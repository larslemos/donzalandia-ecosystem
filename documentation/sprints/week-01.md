# Week 01: Emergency Fixes & Security Hardening

**Goal**: Eliminate all known critical vulnerabilities and secure the production environment before scaling.

## Sprint Context
- **Business Value**: A medical/educational platform cannot afford to leak children's data or have its external API keys hijacked. This sprint guarantees the base level of trust required by schools and guardians.
- **Prerequisites**: Access to the OpenAI platform to rotate API keys. Access to the production database to monitor for orphaned sessions during the Auth migration.

## Tickets / Developer Tasks

### [SEC-01] Rotate OpenAI API Key
- **Description**: The current OpenAI API key was leaked in Git history. Generate a new key and update the production `.env` file.
- **Acceptance Criteria**: 
  - [ ] A new OpenAI API key is generated.
  - [ ] The leaked key is immediately revoked in the OpenAI Dashboard.
  - [ ] The `OPENAI_API_KEY` variable in the production `.env` is updated.
  - [ ] AI Triage report generation is tested in staging/production and succeeds with the new key.
- **Risk Mitigation**: The old key could be in use by an unmonitored side project. Communicate the rotation to the broader team beforehand.
- **Rollback Plan**: N/A. The old key must remain revoked. If the new key fails, verify `.env` syntax or OpenAI billing status.

### [SEC-02] Migrate SPA Auth to Pure HttpOnly Cookies
- **Description**: The frontend currently stores a Sanctum Bearer token in `sessionStorage` (vulnerable to XSS). Migrate to Laravel Sanctum's SPA authentication mode, which uses HttpOnly cookies to handle sessions, removing the need for client-side token storage.
- **Acceptance Criteria**: 
  - [ ] Remove all references to `sessionStorage.getItem('jwt_access_token')` from the React codebase (`utils.js`, `axios.js`, etc.).
  - [ ] Ensure `withCredentials: true` is set on the global Axios instance.
  - [ ] Update the `LoginUseCase` in Laravel to issue session cookies via `Auth::login($user)` and `session()->regenerate()` instead of returning a Bearer token in the JSON payload.
  - [ ] The user can log in, switch entities, and log out successfully using only cookies.
- **Risk Mitigation**: Ensure CORS and Sanctum stateful domains (`SANCTUM_STATEFUL_DOMAINS`) are correctly configured in staging before deploying to production, as SPA cookies rely heavily on strict origin matching.
- **Rollback Plan**: Revert the frontend commit that removes `sessionStorage` logic and the backend commit that modifies `LoginUseCase`.

### [SEC-03] Remove Hardcoded Default Passwords
- **Description**: The `config/auth.php` file contains hardcoded fallback passwords (e.g., `Dondza2025!`). If `.env` variables are missing, new accounts are created with guessable passwords, leading to account takeover vulnerabilities between creation and the user clicking the setup link.
- **Acceptance Criteria**: 
  - [ ] Remove hardcoded default passwords from `config/auth.php`.
  - [ ] Modify the configuration to throw a `RuntimeException` if `AUTH_DEFAULT_PASSWORD_*` variables are missing in production.
  - [ ] Update the account creation flow to assign a cryptographically random, temporary token instead of a password upon creation.
  - [ ] Ensure the temporary token is invalidated once the user sets their password via the setup link.
- **Risk Mitigation**: Test the entire account creation and password setup flow thoroughly. Ensure existing accounts without passwords (if any) are not broken.
- **Rollback Plan**: Revert changes to `config/auth.php` and the account creation UseCase.
