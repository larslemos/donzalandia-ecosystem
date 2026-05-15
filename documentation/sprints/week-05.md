# Week 05: Architecture Refactoring (Part 1)

**Goal**: Increase system resilience by caching expensive middleware checks and isolating external service failures.

## Sprint Context
- **Business Value**: External APIs go down, and database queries add up. This sprint protects the system from cascading failures and reduces the "death by a thousand cuts" caused by redundant access checks.
- **Prerequisites**: Redis must be available (completed in Week 02).

## Tickets / Developer Tasks

### [ARCH-01] Cache the EnsureEntityAccess Middleware
- **Description**: The `EnsureEntityAccess` middleware queries the `user_entities` table on every single protected API route. Cache this check to dramatically reduce database load.
- **Acceptance Criteria**: 
  - [ ] Modify `TenancyService::hasEntityAccess` to wrap the DB existence check in `Cache::remember`.
  - [ ] Use a request-scoped cache or a short TTL (e.g., 60 seconds) with a key like `entity_access_{user_id}_{entity_id}`.
  - [ ] Hook into the `UserEntity` Eloquent Observer to actively invalidate this cache key when a user's entity access is modified.
  - [ ] Verify that navigating around the dashboard results in fewer DB queries.
- **Risk Mitigation**: Cache desynchronization could temporarily lock a user out or grant them access after removal. The 60-second TTL limits the window of vulnerability.
- **Rollback Plan**: Remove the cache wrapper and revert to querying the database directly.

### [ARCH-02] Implement Circuit Breaker for OpenAI AI Reports
- **Description**: If the OpenAI API goes down or becomes severely degraded, the queue will fill up with failing `GenerateTriageAiReport` jobs, delaying other important background tasks (like transactional emails).
- **Acceptance Criteria**: 
  - [ ] Implement a circuit breaker pattern in the `GenerateTriageAiReport` job.
  - [ ] Track consecutive failures in Cache. If failures exceed a threshold (e.g., 5), immediately fail new jobs with a specific `RuntimeException` ("Circuit breaker open") without attempting to call OpenAI.
  - [ ] The circuit breaker should automatically close (reset) after a cooldown period (e.g., 10 minutes).
- **Risk Mitigation**: A completely open circuit breaker means no reports generate. Ensure there is a manual way (Artisan command) to reset the breaker or that the cooldown period is well-tuned.
- **Rollback Plan**: Remove the circuit breaker logic from the Job class.
