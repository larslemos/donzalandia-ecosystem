# 08 — Testing & Quality

## Table of Contents
- [Test Overview](#test-overview)
- [Backend Tests (Laravel / PHPUnit)](#backend-tests-laravel--phpunit)
- [Frontend Tests (Vitest / Testing Library)](#frontend-tests-vitest--testing-library)
- [How to Run Test Suites](#how-to-run-test-suites)
- [Test Coverage](#test-coverage)
- [Linting & Code Formatting](#linting--code-formatting)
- [Pre-commit Quality Gates](#pre-commit-quality-gates)
- [API Documentation Generation](#api-documentation-generation)
- [Quality Improvement Recommendations](#quality-improvement-recommendations)

---

## Test Overview

| Layer | Framework | Type | Status |
|---|---|---|---|
| Backend API | PHPUnit 11 | Feature (HTTP integration) | ✅ Active |
| Backend API | PHPUnit 11 | Unit | ⚠️ Minimal (1 example) |
| Backend API | PHPUnit 11 | Performance | ✅ Active |
| Frontend | Vitest + Testing Library | Component / Unit | ✅ Configured |
| Frontend | MSW | API mocking | ✅ Configured |
| E2E | — | — | ❌ Not implemented |

---

## Backend Tests (Laravel / PHPUnit)

### Test Configuration (`phpunit.xml`)

```xml
<phpunit bootstrap="vendor/autoload.php" colors="true">
  <testsuites>
    <testsuite name="Unit">
      <directory>tests/Unit</directory>
    </testsuite>
    <testsuite name="Feature">
      <directory>tests/Feature</directory>
    </testsuite>
  </testsuites>

  <php>
    <env name="APP_ENV" value="testing"/>
    <env name="DB_CONNECTION" value="mysql"/>
    <env name="DB_DATABASE" value="dondzalandia_api_test"/>
    <env name="CACHE_STORE" value="array"/>
    <env name="QUEUE_CONNECTION" value="sync"/>
    <env name="SESSION_DRIVER" value="array"/>
    <env name="MAIL_MAILER" value="array"/>
    <env name="BCRYPT_ROUNDS" value="4"/>
    <env name="OWNERSHIP_CHILD_ACCESS_V2_ENABLED" value="false"/>
  </php>
</phpunit>
```

**Key test settings:**
- **DB**: MySQL (`dondzalandia_api_test` database — must exist)
- **Queue**: `sync` (jobs run inline, no worker needed)
- **Cache**: `array` (in-memory, no Redis required)
- **Sessions**: `array` (no DB/Redis required)
- **Bcrypt rounds**: 4 (faster hashing for tests)

### Test Structure

```
tests/
├── Feature/
│   ├── Auth/
│   │   ├── AuthLoginTest.php          # Login flow, invalid credentials, throttle
│   │   ├── AuthLogoutTest.php         # Logout, token invalidation
│   │   ├── AuthMeTest.php             # /auth/me endpoint
│   │   ├── AuthSwitchEntityTest.php   # Entity switching
│   │   └── AuthRateLimitTest.php      # Rate limit enforcement
│   ├── Cadastro/
│   │   ├── ChildMutationTest.php      # Child CRUD, soft delete, restore
│   │   ├── UserForceDeleteTest.php    # User force delete workflow
│   │   ├── WaitingAndTriageQueueVisibilityTest.php  # Data isolation
│   │   └── EntityResponsibleProfessionalControllerTest.php
│   ├── Triagem/
│   │   ├── TriageMutationTest.php         # Triage CRUD
│   │   ├── TriageAiReportGenerationTest.php  # AI report queue flow
│   │   ├── TriageDuplicateConsolidationCommandTest.php
│   │   ├── MentalHealthSignalizationSyncTest.php
│   │   └── WaitingListReconcileTest.php
│   ├── Plasir/
│   │   ├── AnamnesisMutationTest.php
│   │   ├── AnamnesisDuplicateConsolidationCommandTest.php
│   │   └── DashboardControllerTest.php
│   ├── DiagnosticoNEE/
│   │   └── DiagnosticDashboardSummaryTest.php
│   └── Policy/
│       ├── ChildPolicyTest.php         # Authorization policy unit tests
│       ├── ChildEntityIsolationTest.php # Multi-tenant isolation
│       ├── TriageAccessTest.php
│       └── ReferralAccessTest.php
├── Performance/
│   └── UserControllerPerformanceTest.php  # Response time assertions
└── Unit/
    └── ExampleTest.php                 # Laravel stub (minimal)
```

### What's Well Covered

✅ Authentication flows (login, logout, me, switch entity, rate limiting)  
✅ Child CRUD with soft delete / restore  
✅ Triage creation and mutation  
✅ AI report job dispatch and generation  
✅ Waiting list reconciliation  
✅ Policy-based access control (ChildPolicy, TriageAccess, ReferralAccess)  
✅ Multi-tenant data isolation  
✅ Duplicate consolidation commands (triage, anamnesis)  

### What's Missing or Minimal

❌ Unit test coverage (only `ExampleTest.php`)  
❌ Guardian app endpoints  
❌ Assessment / Quiz flow  
❌ Referral report endpoints  
❌ Geographic endpoints  
❌ Diagnostic NEE full flow  
❌ Public insights module  

---

## Frontend Tests (Vitest / Testing Library)

### Configuration (`vite.config.js`)

```js
test: {
  environment: 'jsdom',         // DOM environment simulation
  setupFiles: './src/test/setup.js',  // Global test setup
  css: true,                    // Process CSS in tests
  globals: false,               // No implicit globals (use imports)
}
```

### Test Setup (`src/test/setup.js`)

Configures:
- `@testing-library/jest-dom` custom matchers
- MSW (Mock Service Worker) server for API mocking

### MSW API Mocking

```
src/_mock/          # Mock data (fixtures)
src/test/           # MSW handlers and server setup
```

MSW intercepts real HTTP requests during tests and returns controlled mock responses — tests run fully offline without hitting the real API.

### Writing a Component Test (Example)

```js
import { render, screen, fireEvent } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import LoginForm from 'src/auth/view/LoginForm';

describe('LoginForm', () => {
  it('shows validation error for empty email', async () => {
    render(<LoginForm />);
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }));
    expect(await screen.findByText(/email is required/i)).toBeInTheDocument();
  });
});
```

---

## How to Run Test Suites

### Backend (PHPUnit)

```bash
cd dondza

# Prerequisites: create the test database
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS dondzalandia_api_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Run all tests
php artisan test

# Run specific test suite
php artisan test --testsuite=Feature
php artisan test --testsuite=Unit

# Run a specific test file
php artisan test tests/Feature/Auth/AuthLoginTest.php

# Run a specific test method
php artisan test --filter=test_user_can_login

# Run with verbose output
php artisan test --verbose

# Run in parallel (faster)
php artisan test --parallel

# Alternative: via Composer script
composer run test

# Via PHPUnit directly
./vendor/bin/phpunit
./vendor/bin/phpunit --testsuite=Feature --verbose
```

### Frontend (Vitest)

```bash
cd dondza_cadastro

# Run tests in watch mode (development)
yarn test
# or: npm run test

# Run tests once (CI mode)
yarn test:run
# or: npm run test:run

# Run specific test file
yarn test src/auth/view/LoginView.test.jsx

# Run with verbose output
yarn test --reporter=verbose

# Run with UI (Vitest UI — if installed)
yarn test --ui
```

---

## Test Coverage

### Backend — Generate Coverage Report

```bash
# Requires Xdebug or PCOV PHP extension
XDEBUG_MODE=coverage php artisan test --coverage

# Generate HTML report
XDEBUG_MODE=coverage ./vendor/bin/phpunit --coverage-html coverage/
# Open: coverage/index.html in browser

# Coverage summary in terminal
XDEBUG_MODE=coverage ./vendor/bin/phpunit --coverage-text

# XML report (for CI)
XDEBUG_MODE=coverage ./vendor/bin/phpunit --coverage-clover coverage.xml
```

### Frontend — Generate Coverage Report

```bash
cd dondza_cadastro

# Run tests with coverage
yarn vitest run --coverage

# Output: coverage/ directory with HTML report
```

> ⚠️ **Note**: Coverage infrastructure (Xdebug/PCOV for PHP, `@vitest/coverage-v8` for frontend) must be installed. Verify with `php -m | grep xdebug` and check `devDependencies` for `@vitest/coverage-v8`.

---

## Linting & Code Formatting

### Backend — Laravel Pint

[Laravel Pint](https://laravel.com/docs/pint) is the PHP code style fixer (based on PHP-CS-Fixer).

```bash
cd dondza

# Check for style violations (no changes)
./vendor/bin/pint --test

# Auto-fix all violations
./vendor/bin/pint

# Fix specific file
./vendor/bin/pint app/Http/Controllers/SomeController.php
```

### Frontend — ESLint

```bash
cd dondza_cadastro

# Run linter
yarn lint
# or: npm run lint

# Auto-fix linting issues
yarn lint:fix
# or: npm run lint:fix
```

**ESLint configuration** (`.eslintrc.cjs`):
- Base: `eslint-config-airbnb` (strict Airbnb style guide)
- Plugins: `react`, `react-hooks`, `jsx-a11y`, `import`, `prettier`, `perfectionist`, `unused-imports`
- Alias resolution via `eslint-import-resolver-alias`

### Frontend — Prettier

```bash
cd dondza_cadastro

# Check formatting
yarn fm:check
# or: npm run fm:check

# Auto-format all source files
yarn fm:fix
# or: npm run fm:fix
```

**Prettier configuration** (`prettier.config.mjs`):
- Consistent formatting for JS/JSX/TS/TSX files
- Integrated with ESLint via `eslint-config-prettier` (disables conflicting rules)

### Editor Config (`.editorconfig`)

Both repositories include `.editorconfig` to enforce consistent:
- Indentation (spaces, 2-wide for frontend; 4-wide for backend)
- Line endings (LF)
- Trailing newline

---

## Pre-commit Quality Gates

No pre-commit hooks (`.husky`, `.git-hooks`) were found in either repository.

### Recommended Setup: Husky + lint-staged (Frontend)

```bash
cd dondza_cadastro
npx husky init
```

`.husky/pre-commit`:
```bash
#!/bin/sh
npx lint-staged
```

`package.json` addition:
```json
{
  "lint-staged": {
    "src/**/*.{js,jsx,ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ]
  }
}
```

### Recommended: Secret Scanning Pre-commit Hook

```bash
# Install trufflehog
brew install trufflehog

# Add to .husky/pre-commit
trufflehog git file://. --since-commit HEAD --only-verified --fail
```

### Recommended: PHP Pre-commit Hook (Backend)

`.git/hooks/pre-commit`:
```bash
#!/bin/sh
./vendor/bin/pint --test
if [ $? -ne 0 ]; then
  echo "PHP Pint check failed. Run './vendor/bin/pint' to fix."
  exit 1
fi
```

---

## API Documentation Generation

The backend includes **Scribe** for automatic API documentation generation:

```bash
cd dondza

# Generate API docs from code annotations
php artisan scribe:generate

# Output location: .scribe/
# Serve locally:
php artisan serve
# Visit: http://localhost:8000/docs
```

Scribe reads Laravel Form Requests, route definitions, and docblock annotations to produce:
- Interactive HTML API docs
- OpenAPI (Swagger) YAML spec
- Postman collection JSON

---

## Quality Improvement Recommendations

### High Priority

| Item | Action |
|---|---|
| ❌ No E2E tests | Add Playwright or Cypress for critical user journeys (login → triage → waiting list) |
| ❌ Minimal unit tests (backend) | Add unit tests for UseCases and Services |
| ❌ No pre-commit hooks | Implement Husky + lint-staged (frontend) and Pint check (backend) |
| ❌ No secret scanning | Add trufflehog or git-secrets to pre-commit and CI pipeline |
| ❌ No CI/CD pipelines | Implement GitHub Actions for test + deploy on PR merge |

### Medium Priority

| Item | Action |
|---|---|
| ⚠️ Missing frontend test coverage | Add tests for key components (LoginForm, ChildForm, TriageForm) |
| ⚠️ Assessment/quiz tests missing | Add feature tests for quiz start/answer/complete flow |
| ⚠️ Guardian app tests missing | Add feature tests for all guardian endpoints |
| ⚠️ Coverage reports not in CI | Add coverage threshold enforcement (e.g., min 70%) |

### Low Priority

| Item | Action |
|---|---|
| 🟢 Vitest UI not configured | Add `@vitest/ui` for interactive test browser |
| 🟢 Performance tests | Expand `UserControllerPerformanceTest.php` to more endpoints |
| 🟢 Contract tests | Add Pact or similar for API contract testing between frontend and backend |
