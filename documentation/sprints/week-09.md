# Week 09: Full Observability & Alerting

**Goal**: Move from reactive firefighting to proactive alerting.

## Sprint Context
- **Business Value**: Finding out the system is down because a user emailed support is unacceptable for a healthcare platform. The team must know before the users do.
- **Prerequisites**: Redis queue and BetterStack logging configured (Weeks 02/03).

## Tickets / Developer Tasks

### [OBS-02] Implement Strict Account Lockout
- **Description**: The current rate limiting is IP-based, leaving the system vulnerable to distributed brute-force attacks. Implement a per-user account lockout mechanism.
- **Acceptance Criteria**: 
  - [ ] Modify `LoginUseCase.php`. If a login fails, increment a cache counter keyed by the user's ID (`login_fails_{id}`).
  - [ ] If the counter exceeds 5, return a 429 status code and block further attempts for 15 minutes, regardless of IP address.
  - [ ] Reset the counter upon successful login.
  - [ ] Do not expose whether the account is locked vs. invalid credentials to avoid user enumeration.
- **Risk Mitigation**: Legitimate users forgetting their password might get locked out. Ensure the "Forgot Password" flow is robust and clearly visible.
- **Rollback Plan**: Remove the cache counter logic from the `LoginUseCase`.

### [OBS-03] Set Up Queue and Error Alerting
- **Description**: The system relies heavily on asynchronous jobs (AI reports, emails). If the queue stops processing, the application appears broken.
- **Acceptance Criteria**: 
  - [ ] Configure `QUEUE_HEALTH_MAX_PENDING=10` in `.env`.
  - [ ] Create a scheduled command or use an external monitor (BetterStack Uptime) to check the queue length.
  - [ ] Configure BetterStack to trigger an alert (Slack/Email/SMS) if the `failed_jobs` table grows above 0 or if the queue length exceeds 10.
  - [ ] Configure Sentry to alert on spikes in 500 errors (e.g., > 10 in 5 minutes).
- **Risk Mitigation**: Alert fatigue. Tune the thresholds so developers only get pinged for actual actionable outages, not transient errors.
- **Rollback Plan**: Disable the alerts in BetterStack and Sentry dashboards.
