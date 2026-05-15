# Week 10: Incident Response Readiness

**Goal**: Document how to fix the system when it breaks at 3 AM.

## Sprint Context
- **Business Value**: When an outage occurs, MTTR (Mean Time To Recovery) depends entirely on the developer's ability to diagnose and fix the issue quickly without panicking. Runbooks remove the guesswork.
- **Prerequisites**: Alerts set up in Week 09.

## Tickets / Developer Tasks

### [DOC-03] Create Incident Response Runbooks
- **Description**: Write markdown files detailing exactly what to do for the top 5 failure scenarios.
- **Acceptance Criteria**: 
  - [ ] Create `documentation/runbooks/` folder.
  - [ ] Write `01-redis-oom.md`: Steps to flush cache, restart Redis, and increase memory limits.
  - [ ] Write `02-queue-backed-up.md`: Steps to scale up queue workers, retry failed jobs, and bypass circuit breakers.
  - [ ] Write `03-openai-outage.md`: Steps to disable the AI report feature flag and communicate with users.
  - [ ] Write `04-db-connection-exhaustion.md`: Steps to identify rogue queries and restart PHP-FPM.
  - [ ] Write `05-frontend-deployment-failure.md`: Steps to revert a Vercel deployment instantly.
- **Risk Mitigation**: Runbooks must be accessible when the system is down. Store them in the Git repository, not in an internal wiki that might share infrastructure.
- **Rollback Plan**: N/A (Documentation only).

### [OBS-04] Health Check Dashboard Integration
- **Description**: Expose the `/api/health/ready` endpoint data to the team in a visual way.
- **Acceptance Criteria**: 
  - [ ] Ensure `/api/health/ready` checks DB connectivity, Redis connectivity, and Queue status.
  - [ ] Point an external Uptime monitoring tool (e.g., BetterStack, UptimeRobot) at this endpoint.
  - [ ] Create a public or team-facing status page (e.g., `status.dondzalandia.co.mz`).
- **Risk Mitigation**: The health check endpoint must not perform heavy DB queries, or the monitor itself will cause a DDoS. Keep it lightweight (e.g., `DB::select('SELECT 1')`).
- **Rollback Plan**: Disable the uptime monitor.
