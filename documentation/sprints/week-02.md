# Week 02: Observability Foundation

**Goal**: Establish a baseline for system monitoring and log correlation to detect issues before they impact users.

## Sprint Context
- **Business Value**: Without observability, the team is flying blind. This sprint provides the tools necessary to debug complex issues, trace user requests across the stack, and eliminate single points of failure like database-backed sessions.
- **Prerequisites**: A managed Redis instance (or a well-configured self-hosted one) must be provisioned for the production environment.

## Tickets / Developer Tasks

### [INFRA-01] Migrate Sessions, Cache, and Queue to Redis
- **Description**: The application currently uses MySQL for sessions, cache, and queues. At scale, this creates a severe write bottleneck. Migrate these drivers to Redis to offload the database and enable horizontal scaling.
- **Acceptance Criteria**: 
  - [ ] Provision a Redis instance for staging and production.
  - [ ] Update `.env` variables: `SESSION_DRIVER=redis`, `CACHE_STORE=redis`, `QUEUE_CONNECTION=redis`.
  - [ ] Ensure `phpredis` extension is installed on the PHP-FPM servers.
  - [ ] Verify that new logins create sessions in Redis, not MySQL.
  - [ ] Verify that queued jobs (e.g., AI reports) are processed via Redis.
- **Risk Mitigation**: Active user sessions stored in MySQL will be lost when switching to Redis, forcing all users to log in again. Schedule this deployment during a low-traffic window and communicate the required re-login to users.
- **Rollback Plan**: Revert `.env` variables back to `database`. Users will have to log in again.

### [OBS-01] Implement Request ID Correlation
- **Description**: Tracing an error from the frontend through to the backend logs is difficult. Implement a unique `X-Request-ID` for every HTTP request and log it in both Sentry and BetterStack.
- **Acceptance Criteria**: 
  - [ ] Add an Axios interceptor in the React frontend to generate a UUID and append it as the `X-Request-ID` header to all outgoing API requests.
  - [ ] Update the `AttachRequestContext` middleware in Laravel to read the incoming `X-Request-ID` (or generate one if missing).
  - [ ] Configure Laravel's logging (Monolog) to include the `X-Request-ID` in the log context for all log entries.
  - [ ] Configure Sentry (backend) to tag all captured exceptions and performance traces with the `X-Request-ID`.
- **Risk Mitigation**: None. This is a purely additive observability feature.
- **Rollback Plan**: Revert the Axios interceptor and Laravel middleware changes.
