# PLASIR — Project Documentation

> **Platform:** PLASIR (Plataforma de Sinalização e Intervenção em Risco)  
> **Organisation:** Dondzalândia, Lda  
> **Generated:** 2026-05-15  
> **Repositories:** `dondza` (Laravel 12 API) + `dondza_cadastro` (React 18 / Vite SPA)

---

## Documentation Index

| # | Document | Description |
|---|---|---|
| 01 | [Setup & Installation](./01-setup.md) | Prerequisites, install steps, env vars, local dev, troubleshooting |
| 02 | [Architecture & Technical Overview](./02-architecture.md) | System diagram, tech stack, folder structure, design patterns, integrations |
| 03 | [API Documentation](./03-api.md) | All endpoints, auth, rate limiting, request/response schemas, cURL examples |
| 04 | [Database Schema](./04-database.md) | ER diagram, all tables, indexes, migration history |
| 05 | [Features & User Journey](./05-features.md) | Feature list, flow diagrams, RBAC, user stories |
| 06 | [Security Analysis](./06-security.md) | Auth implementation, protections, known vulnerabilities, security checklist |
| 07 | [Deployment Guide](./07-deployment.md) | Vercel, Laravel VPS, CI/CD, monitoring, backup, scaling |
| 08 | [Testing & Quality](./08-testing.md) | PHPUnit, Vitest, coverage, linting, pre-commit hooks |

---

## Quick Reference

### Production URLs
| Service | URL |
|---|---|
| API | `https://api.dondzalandia.co.mz/api` |
| Frontend (PLASIR Web) | `https://plasir.dondzalandia.co.mz` |
| Health Check | `https://api.dondzalandia.co.mz/api/health/ready` |

### Local Development
```bash
# Backend (all services)
cd dondza && composer run dev      # → http://localhost:8000

# Frontend
cd dondza_cadastro && yarn dev     # → http://localhost:3031
```

### Key Security Actions Required
> ⚠️ **URGENT**: The OpenAI API key committed in `src/services/openAIService.js` must be **rotated immediately**. The git history purge does not protect keys that were previously exposed.

---

## Architecture at a Glance

```
dondza_cadastro (React SPA)          dondza (Laravel 12 API)
─────────────────────────            ────────────────────────
React 18 + Vite                      PHP 8.2 + Laravel 12
MUI v5 component library     ──────→ Sanctum Auth (cookie/token)
TanStack Query (server state)        10 Domain Modules
React Router v6                      MySQL 8 + Redis
Sentry (error tracking)              Sentry + BetterStack
Vercel (deployment)                  OpenAI (AI reports)
                                     Resend (email)
```
