# 01 — Project Setup & Installation Guide

## Table of Contents
- [System Prerequisites](#system-prerequisites)
- [Repository Structure](#repository-structure)
- [Backend Setup (dondza)](#backend-setup-dondza)
- [Frontend Setup (dondza_cadastro)](#frontend-setup-dondza_cadastro)
- [Environment Variables](#environment-variables)
- [Running Locally (Full Stack)](#running-locally-full-stack)
- [Database Initialization & Seeding](#database-initialization--seeding)
- [Troubleshooting](#troubleshooting)

---

## System Prerequisites

| Dependency | Minimum Version | Recommended | Notes |
|---|---|---|---|
| **PHP** | 8.2+ | 8.3 | Required by Laravel 12 |
| **Composer** | 2.x | latest | PHP package manager |
| **Node.js** | 20.x | 20 LTS | Pinned in `package.json` engines |
| **Yarn** | 1.22.22 | 1.22.22 | Pinned as `packageManager` in frontend |
| **MySQL** | 8.0+ | 8.0+ | Used in production & test environments |
| **Redis** | 6.x+ | 7.x | Cache, sessions, queues |
| **Git** | 2.x | latest | Version control |

> ⚠️ SQLite is the default `DB_CONNECTION` in `.env.example` for quick local starts. **Tests run against MySQL** (`dondzalandia_api_test`). Production uses MySQL.

---

## Repository Structure

```
Dondzalandia/
├── dondza/               # Laravel 12 API backend
└── dondza_cadastro/      # React 18 + Vite frontend (PLASIR web)
```

These are two **independent** Git repositories. Each must be set up separately.

---

## Backend Setup (`dondza`)

### 1. Clone & Enter Directory

```bash
git clone <backend-repo-url> dondza
cd dondza
```

### 2. Install PHP Dependencies

```bash
composer install
```

### 3. Configure Environment

```bash
cp .env.example .env
php artisan key:generate
```

Then open `.env` and fill in all required variables (see [Environment Variables](#environment-variables)).

### 4. Database Setup

**SQLite (quick dev start):**
```bash
touch database/database.sqlite
php artisan migrate
```

**MySQL (recommended for full parity with prod):**
```bash
# Set DB_CONNECTION=mysql, DB_HOST, DB_DATABASE, DB_USERNAME, DB_PASSWORD in .env
php artisan migrate
```

### 5. Seed Initial Data

```bash
php artisan db:seed
```

### 6. Build Frontend Assets (embedded Blade views, if any)

```bash
npm install
npm run build
```

### 7. Start the Development Server

Use the Composer `dev` script which starts all services concurrently:

```bash
composer run dev
```

This starts (in parallel, color-coded):
- `php artisan serve` — API on `http://localhost:8000`
- `php artisan queue:listen --tries=1` — Queue worker
- `php artisan pail --timeout=0` — Log tail
- `npm run dev` — Vite (if Blade views use Vite assets)

Or, to start only the API:

```bash
php artisan serve
```

---

## Frontend Setup (`dondza_cadastro`)

### 1. Clone & Enter Directory

```bash
git clone <frontend-repo-url> dondza_cadastro
cd dondza_cadastro
```

### 2. Install JavaScript Dependencies

```bash
yarn install
```

> ⚠️ Use **Yarn** (v1.22.22). Do not use `npm install` — the project uses a `yarn.lock`.

### 3. Configure Environment

```bash
cp .env.example .env
```

Set the backend API URL:

```env
PP_SERVER_URL=http://localhost:8000/api
VITE_ASSETS_DIR=http://localhost:8000/api
```

Fill in other optional keys (Mapbox, Sentry) as needed.

### 4. Start the Development Server

```bash
yarn dev
```

Frontend runs at: **`http://localhost:3031`**

To expose on network:

```bash
yarn dev:host
```

---

## Environment Variables

### Backend (`dondza/.env`)

| Variable | Required | Default | Description |
|---|---|---|---|
| `APP_KEY` | ✅ | — | Laravel encryption key (auto-generated) |
| `APP_ENV` | ✅ | `local` | `local` / `production` |
| `APP_URL` | ✅ | `http://localhost` | Base URL of the API |
| `MOBILE_API_KEY` | ✅ | — | Secret key for `X-Mobile-API-Key` header |
| `DB_CONNECTION` | ✅ | `sqlite` | `sqlite` or `mysql` |
| `DB_HOST` | ⚠️ MySQL only | `127.0.0.1` | Database host |
| `DB_PORT` | ⚠️ MySQL only | `3306` | Database port |
| `DB_DATABASE` | ⚠️ MySQL only | — | Database name |
| `DB_USERNAME` | ⚠️ MySQL only | — | Database username |
| `DB_PASSWORD` | ⚠️ MySQL only | — | Database password |
| `REDIS_HOST` | ✅ | `127.0.0.1` | Redis host |
| `REDIS_PORT` | ✅ | `6379` | Redis port |
| `REDIS_PASSWORD` | ⚠️ Prod | `null` | Redis auth |
| `QUEUE_CONNECTION` | ✅ | `database` | `database` / `redis` |
| `CACHE_STORE` | ✅ | `database` | `database` / `redis` |
| `SESSION_DRIVER` | ✅ | `database` | Session backend |
| `RESEND_API_KEY` | ✅ Prod | — | Transactional email via Resend |
| `OPENAI_API_KEY` | ⚠️ AI features | — | OpenAI for AI triage reports |
| `OPENAI_MODEL` | — | `gpt-5.4-mini` | OpenAI model to use |
| `TRIAGE_AI_REPORT_ENABLED` | — | `true` | Feature flag for AI triage |
| `SENTRY_LARAVEL_DSN` | ⚠️ Prod | — | Sentry error tracking |
| `BETTER_STACK_SOURCE_TOKEN` | ⚠️ Prod | — | BetterStack log ingestion |
| `FRONTEND_URL` | ✅ | `http://localhost:3031` | PLASIR web URL (used in emails) |
| `PLASIR_FRONTEND_URL` | ✅ | `http://localhost:3032` | Secondary frontend URL |
| `GUARDIAN_VERIFY_URL` | ⚠️ Mobile | — | Mobile deep link base for email verify |
| `SANCTUM_STATEFUL_DOMAINS` | ✅ | `localhost,...` | Domains allowed for SPA auth |
| `CORS_ALLOWED_ORIGINS` | ✅ | `https://plasir.dondzalandia.co.mz,...` | CORS whitelist |
| `OWNERSHIP_CHILD_ACCESS_V2_ENABLED` | — | `false` | Feature flag for new ownership rules |

### Frontend (`dondza_cadastro/.env`)

| Variable | Required | Default | Description |
|---|---|---|---|
| `PP_SERVER_URL` | ✅ | `https://api.dondzalandia.co.mz/api` | Backend API base URL |
| `VITE_ASSETS_DIR` | ✅ | `https://api.dondzalandia.co.mz/api` | Assets base URL |
| `VITE_MAPBOX_API_KEY` | ⚠️ Maps | — | Mapbox GL access token |
| `VITE_SENTRY_DSN` | ⚠️ Prod | — | Sentry frontend DSN |
| `VITE_SENTRY_ENVIRONMENT` | — | `production` | Sentry environment label |
| `VITE_SENTRY_TRACES_SAMPLE_RATE` | — | `0.02` | Sentry performance tracing |
| `SENTRY_AUTH_TOKEN` | ⚠️ Build | — | Sentry sourcemap upload token |
| `SENTRY_ORG` | ⚠️ Build | `dondzalandia` | Sentry organisation slug |
| `SENTRY_PROJECT` | ⚠️ Build | `plasir-web` | Sentry project slug |

> 🔑 Firebase, AWS Amplify, Auth0, and Supabase variables in `.env.example` are **template leftovers** from the base UI kit and are **not actively used**. Leave them blank.

---

## Running Locally (Full Stack)

```bash
# Terminal 1 — Backend (all services)
cd dondza && composer run dev

# Terminal 2 — Frontend
cd dondza_cadastro && yarn dev
```

| Service | URL |
|---|---|
| Laravel API | `http://localhost:8000/api` |
| PLASIR Web (frontend) | `http://localhost:3031` |
| Health check | `http://localhost:8000/api/health/ready` |

---

## Database Initialization & Seeding

```bash
# Run all migrations (creates schema from scratch)
php artisan migrate

# Run with seed data
php artisan migrate --seed

# Fresh reset (drops all tables then migrates)
php artisan migrate:fresh --seed

# For tests, create the test database first:
mysql -u root -e "CREATE DATABASE dondzalandia_api_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
php artisan test
```

---

## Troubleshooting

### ❌ `cURL error 60: SSL certificate problem` (Windows)
See `docs/SSL-WINDOWS.md` in the backend repo. Usually fixed by pointing PHP to a CA bundle.

### ❌ `REDIS_CLIENT` phpredis extension not found
```bash
pecl install redis
# Then add extension=redis to php.ini
```
Or switch `REDIS_CLIENT=predis` in `.env` and run `composer require predis/predis`.

### ❌ `Session store not set on request`
Ensure `SESSION_DRIVER=database` and run `php artisan migrate` to create the sessions table.

### ❌ Frontend shows blank page after `yarn dev`
Check that `PP_SERVER_URL` is set in `.env` (without quotes). The variable is read directly by `import.meta.env.PP_SERVER_URL`.

### ❌ `queue:listen` jobs not processing
Make sure `QUEUE_CONNECTION=database` and the `jobs` table exists. Run `php artisan migrate`.

### ❌ CORS errors from frontend
Add your local frontend URL to `CORS_ALLOWED_ORIGINS` and `SANCTUM_STATEFUL_DOMAINS` in the backend `.env`.
