# 07 — Deployment Guide

## Table of Contents
- [Supported Deployment Targets](#supported-deployment-targets)
- [Frontend Deployment (Vercel)](#frontend-deployment-vercel)
- [Backend Deployment (Laravel)](#backend-deployment-laravel)
- [Production Environment Setup](#production-environment-setup)
- [CI/CD Pipeline Considerations](#cicd-pipeline-considerations)
- [Health Checks & Monitoring](#health-checks--monitoring)
- [Logging & Observability](#logging--observability)
- [Backup & Recovery](#backup--recovery)
- [Scaling Considerations](#scaling-considerations)

---

## Supported Deployment Targets

| Component | Target | Status |
|---|---|---|
| **Frontend** (`dondza_cadastro`) | Vercel | ✅ Configured (`vercel.json`) |
| **Backend** (`dondza`) | Any PHP 8.2+ host / VPS / container | ✅ Laravel-compatible |
| **Database** | MySQL 8.0+ (managed or self-hosted) | ✅ |
| **Cache / Queue** | Redis (managed or self-hosted) | ✅ |
| **Email** | Resend (SaaS) | ✅ Configured |
| **Error Tracking** | Sentry (SaaS) | ✅ Configured |
| **Logs** | BetterStack / Logtail (SaaS) | ✅ Configured |

---

## Frontend Deployment (Vercel)

### `vercel.json` Configuration

```json
{
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

This SPA rewrite rule ensures React Router handles all routes client-side.

### Vercel Environment Variables

Set these in the Vercel project dashboard under **Settings → Environment Variables**:

| Variable | Value |
|---|---|
| `PP_SERVER_URL` | `https://api.dondzalandia.co.mz/api` |
| `VITE_ASSETS_DIR` | `https://api.dondzalandia.co.mz/api` |
| `VITE_MAPBOX_API_KEY` | `<your mapbox token>` |
| `VITE_SENTRY_DSN` | `<your frontend Sentry DSN>` |
| `VITE_SENTRY_ENVIRONMENT` | `production` |
| `VITE_SENTRY_TRACES_SAMPLE_RATE` | `0.02` |
| `SENTRY_AUTH_TOKEN` | `<sentry auth token>` |
| `SENTRY_ORG` | `dondzalandia` |
| `SENTRY_PROJECT` | `plasir-web` |

### Build Command

Vercel auto-detects the Vite project. The build command is:

```bash
yarn build
# or: npm run build
```

Output directory: `dist/`

### Custom Domain

Point `plasir.dondzalandia.co.mz` to Vercel via CNAME or A record in your DNS provider.

### Recommended Vercel Security Headers

Add to `vercel.json`:

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
        {
          "key": "Content-Security-Policy",
          "value": "default-src 'self'; script-src 'self' 'unsafe-inline' https:; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://api.dondzalandia.co.mz https://*.mapbox.com https://*.sentry.io;"
        }
      ]
    }
  ],
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

---

## Backend Deployment (Laravel)

### Option A: Traditional VPS / Shared Hosting

```bash
# 1. SSH into server, navigate to web root
cd /var/www/dondza

# 2. Pull latest code
git pull origin main

# 3. Install dependencies (no dev)
composer install --no-dev --optimize-autoloader

# 4. Configure environment
cp .env.example .env
# Edit .env with production values
php artisan key:generate

# 5. Run migrations
php artisan migrate --force

# 6. Cache config, routes, views for performance
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

# 7. Set permissions
chmod -R 775 storage bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache

# 8. Restart queue worker (use Supervisor — see below)
php artisan queue:restart
```

### Option B: Docker / Container

The project does not include a `Dockerfile` but is fully compatible with standard Laravel Docker setups (e.g., `php:8.2-fpm` + Nginx).

Recommended container setup:
- `php:8.2-fpm` for PHP-FPM
- `nginx:alpine` as reverse proxy
- `mysql:8.0` for database
- `redis:7-alpine` for cache/queue

### Nginx Configuration Example

```nginx
server {
    listen 80;
    server_name api.dondzalandia.co.mz;
    root /var/www/dondza/public;

    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

### PHP-FPM Worker (Supervisor)

The queue worker must run as a persistent process. Use Supervisor:

```ini
; /etc/supervisor/conf.d/dondza-worker.conf
[program:dondza-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/dondza/artisan queue:work database --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/dondza/storage/logs/worker.log
stopwaitsecs=3600
```

```bash
supervisorctl reread
supervisorctl update
supervisorctl start dondza-worker:*
```

---

## Production Environment Setup

### Critical `.env` Differences from Development

```env
APP_ENV=production
APP_DEBUG=false                         # Never true in production
APP_URL=https://api.dondzalandia.co.mz

# Security
SESSION_SECURE_COOKIE=true             # HTTPS only cookies
SESSION_ENCRYPT=true                   # Encrypt session data

# Database (MySQL — not SQLite)
DB_CONNECTION=mysql
DB_HOST=<prod-db-host>
DB_PORT=3306
DB_DATABASE=dondzalandia_production
DB_USERNAME=<prod-user>
DB_PASSWORD=<strong-random-password>

# Redis
REDIS_HOST=<prod-redis-host>
REDIS_PASSWORD=<redis-auth-password>

# Cache and Queue (Redis in production)
CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis                   # Faster than database for sessions

# Email
MAIL_MAILER=resend
RESEND_API_KEY=<production-resend-key>
MAIL_FROM_ADDRESS=noreply@dondzalandia.co.mz

# Logging
LOG_CHANNEL=stack
LOG_LEVEL=warning                      # Not debug
BETTER_STACK_SOURCE_TOKEN=<token>

# Sentry
SENTRY_LARAVEL_DSN=<prod-dsn>
SENTRY_TRACES_SAMPLE_RATE=0.05
SENTRY_SEND_DEFAULT_PII=false

# CORS (production only)
CORS_ALLOWED_ORIGINS=https://plasir.dondzalandia.co.mz
SANCTUM_STATEFUL_DOMAINS=plasir.dondzalandia.co.mz

# OpenAI
OPENAI_API_KEY=<rotated-key>
TRIAGE_AI_REPORT_ENABLED=true

# Frontend URLs
FRONTEND_URL=https://plasir.dondzalandia.co.mz
```

### SSL/TLS

- Use **Let's Encrypt** (certbot) or a managed SSL certificate
- Configure Nginx to redirect HTTP → HTTPS
- Auto-renew certificate via cron/certbot timer

---

## CI/CD Pipeline Considerations

No CI/CD configuration files (`.github/workflows`, `.gitlab-ci.yml`) were found in the scanned repositories. The following is a **recommended** setup:

### Recommended GitHub Actions — Backend

```yaml
# .github/workflows/deploy-backend.yml
name: Deploy Backend

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: password
          MYSQL_DATABASE: dondzalandia_api_test
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
      - run: composer install
      - run: php artisan test

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /var/www/dondza
            git pull origin main
            composer install --no-dev --optimize-autoloader
            php artisan migrate --force
            php artisan config:cache && php artisan route:cache
            php artisan queue:restart
```

### Recommended GitHub Actions — Frontend

```yaml
# Vercel auto-deploys from the connected GitHub repo on push to main.
# For manual control, use the Vercel GitHub Action:
name: Deploy Frontend

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: yarn install --frozen-lockfile
      - run: yarn build
        env:
          PP_SERVER_URL: ${{ secrets.PP_SERVER_URL }}
          VITE_MAPBOX_API_KEY: ${{ secrets.VITE_MAPBOX_API_KEY }}
          VITE_SENTRY_DSN: ${{ secrets.VITE_SENTRY_DSN }}
          SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
          SENTRY_ORG: dondzalandia
          SENTRY_PROJECT: plasir-web
```

---

## Health Checks & Monitoring

### Built-in Health Check Endpoint

```
GET /api/health/ready
```

Checks DB and Redis connectivity. Returns:
- `200 { "status": "ok" }` — all systems healthy
- `503 { "status": "degraded", "checks": {...} }` — one or more systems down

Configure your load balancer / uptime monitor to poll this endpoint every 30 seconds.

### Recommended Uptime Monitoring

- **BetterStack** (already integrated for logs) also offers uptime monitoring
- Monitor both `https://api.dondzalandia.co.mz/api/health/ready` and `https://plasir.dondzalandia.co.mz`

### Queue Health

Monitor the queue for pending/failed jobs:

```bash
# Check pending jobs
php artisan queue:monitor database:10   # Alert if > 10 pending

# Check failed jobs
php artisan queue:failed

# Retry all failed jobs
php artisan queue:retry all
```

Configure `QUEUE_HEALTH_MAX_PENDING=10` and `QUEUE_HEALTH_MAX_FAILED=0` for alert thresholds.

---

## Logging & Observability

### Log Channels (Backend)

| Channel | Variable | Purpose |
|---|---|---|
| `observability_file` | `OBSERVABILITY_LOG_STACK` | Business event logging |
| `queue_failures_file` | `QUEUE_FAILURE_LOG_STACK` | Failed job audit trail |
| `slow_queries_file` | `SLOW_QUERY_LOG_STACK` | Slow DB query detection |
| BetterStack (Logtail) | `BETTER_STACK_SOURCE_TOKEN` | Remote log aggregation |

### Slow Query Logging

```env
SLOW_QUERY_LOG_ENABLED=true       # Enable in production
SLOW_QUERY_THRESHOLD_MS=500       # Alert on queries > 500ms
SLOW_QUERY_LOG_LEVEL=warning
```

### Sentry (Frontend + Backend)

- Backend: `sentry/sentry-laravel` — automatic exception capture + performance tracing
- Frontend: `@sentry/react` — JS error tracking + source maps uploaded on build
- Sample rate: `SENTRY_TRACES_SAMPLE_RATE=0.05` (5% of transactions traced)
- PII: `SENTRY_SEND_DEFAULT_PII=false` (no personal data sent)

---

## Backup & Recovery

### Database Backups

```bash
# Manual MySQL dump
mysqldump -u <user> -p dondzalandia_production > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
mysql -u <user> -p dondzalandia_production < backup_YYYYMMDD_HHMMSS.sql
```

A `database/backups/` directory exists in the backend repo — store automated backup scripts here.

**Recommended schedule:**
- Full backup: daily
- Transaction log backup: hourly (if using MySQL binlog replication)
- Retention: 30 days

### Storage Backups

If file uploads are enabled (filesystem disk = `local`), back up `storage/app/public/`.

**Recommendation**: Switch to `FILESYSTEM_DISK=s3` with AWS S3 or compatible object storage for production file storage.

### Recovery Procedure

```bash
# 1. Restore database from latest backup
mysql -u root -p dondzalandia_production < latest_backup.sql

# 2. Clear application cache
php artisan cache:clear
php artisan config:clear

# 3. Run any missing migrations
php artisan migrate --force

# 4. Restart queue workers
php artisan queue:restart

# 5. Verify health check
curl https://api.dondzalandia.co.mz/api/health/ready
```

---

## Scaling Considerations

### Horizontal Scaling (API)

The Laravel API can scale horizontally if:
1. **Sessions** use Redis (not database or file): `SESSION_DRIVER=redis`
2. **Cache** uses Redis: `CACHE_STORE=redis`
3. **Queue** uses Redis: `QUEUE_CONNECTION=redis`
4. **Uploaded files** use S3 (not local disk): `FILESYSTEM_DISK=s3`

All stateless request handling — session and cache centralized in Redis.

### Queue Workers

Scale queue workers independently of the API by running multiple Supervisor `numprocs` or container replicas:

```env
QUEUE_HEALTH_MAX_PENDING=10    # Alert if queue backlog grows
```

### Database

- Use a **read replica** for dashboard/analytics queries (Triagem Universal, etc.)
- Configure Laravel's `DB::connection('read')` for read-heavy routes
- Enable MySQL slow query log and optimize indexes based on production query patterns

### Redis

- Use **Redis Cluster** or managed Redis (e.g., Redis Cloud, AWS ElastiCache) for HA
- Separate Redis instances for cache and queue if needed

### CDN (Frontend)

Vercel's edge CDN handles frontend asset delivery globally. For the API:
- Use a CDN (CloudFront, Cloudflare) in front of the API for static/cacheable responses
- Apply aggressive caching for `/location/provinces` and `/location/districts` endpoints
