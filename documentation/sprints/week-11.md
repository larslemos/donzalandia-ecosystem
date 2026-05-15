# Week 11: Developer Experience (Part 1)

**Goal**: Make it trivial for a new developer to onboard, run the app, and contribute without "works on my machine" issues.

## Sprint Context
- **Business Value**: Developer friction is expensive. If setting up the app takes 2 days instead of 2 hours, velocity plummets. A robust local environment ensures what is tested locally matches production.
- **Prerequisites**: None.

## Tickets / Developer Tasks

### [DX-01] Standardize Local Development via Docker Compose
- **Description**: The current setup relies on developers installing PHP 8.2, Redis, and MySQL manually. Create a `docker-compose.yml` file to spin up the entire backend stack consistently.
- **Acceptance Criteria**: 
  - [ ] Create `dondza/docker-compose.yml`.
  - [ ] Define services: `app` (PHP-FPM 8.2), `web` (Nginx), `db` (MySQL 8), `redis` (Redis 7), and `worker` (PHP-FPM running the queue).
  - [ ] Include a `Makefile` or helper scripts (e.g., `./vendor/bin/sail` if using Laravel Sail) to easily run migrations and seeders inside the container.
  - [ ] Update `documentation/01-setup.md` with the new Docker-based instructions.
- **Risk Mitigation**: Performance on macOS can be slow due to Docker filesystem mounts. Ensure proper caching configurations (like `virtiofs` or Mutagen) are documented for Mac users.
- **Rollback Plan**: N/A. Developers can continue using local PHP if they choose.

### [DX-02] Create a Database Seeder for Realistic Testing
- **Description**: Working on UI features requires realistic data. The current seeders are basic. Create a robust `DatabaseSeeder` that generates a fully functional "sandbox" entity.
- **Acceptance Criteria**: 
  - [ ] Update Laravel Factories for `User`, `Entity`, `Child`, `Triage`, and `WaitingList`.
  - [ ] The seeder should create: 1 Entity, 1 Super Admin, 2 Professionals, 50 Children (10 with active triages, 5 on the waiting list).
  - [ ] Ensure passwords for seeded users are `password` for easy local login.
- **Risk Mitigation**: Do NOT run seeders in production. Ensure `App::environment('local')` checks are in place.
- **Rollback Plan**: Revert changes to the `database/seeders` folder.
