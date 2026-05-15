# Week 03: Performance Quick Wins

**Goal**: Resolve the most glaring database queries and API bottlenecks to ensure smooth operation under moderate load.

## Sprint Context
- **Business Value**: Slow load times directly impact the productivity of healthcare professionals and teachers. Resolving N+1 queries and parallelizing dashboard requests provides an immediate, noticeable speed boost for end-users.
- **Prerequisites**: Week 02 (Redis migration) must be complete, as some of these fixes rely on efficient caching.

## Tickets / Developer Tasks

### [PERF-01] Optimize Login Query Resolution
- **Description**: The current `resolveUserByIdentifier` method in the `LoginUseCase` fires 3-6 sequential DB queries per login attempt, checking various tables (child codes, emails, phones). Consolidate this into a single optimized lookup.
- **Acceptance Criteria**: 
  - [ ] Rewrite `resolveUserByIdentifier` to check the `users` table first (email match).
  - [ ] If no email match, perform a single join query against the `persons` table to resolve phone numbers.
  - [ ] Ensure the total query count during a failed login attempt is reduced to a maximum of 2.
- **Risk Mitigation**: Write a unit test for the `resolveUserByIdentifier` method covering all identifier types (email, phone, invalid) before refactoring.
- **Rollback Plan**: Revert the changes to `LoginUseCase.php`.

### [PERF-02] Fix Login Payload N+1 Eager Loading
- **Description**: Building the JSON response upon a successful login currently triggers 5+ eager-loaded relationships (roles, entities, specialties), taking up to 1.5 seconds. Cache the denormalized login payload.
- **Acceptance Criteria**: 
  - [ ] Implement caching in the login payload construction logic using `Cache::remember`.
  - [ ] The cache key should be specific to the user (e.g., `user_login_data_{id}`).
  - [ ] Set a TTL of 5 minutes or invalidate the cache proactively when user roles/entities are updated.
  - [ ] Verify login response time drops significantly (target < 200ms).
- **Risk Mitigation**: Stale permissions upon role changes. Ensure cache invalidation is added to the relevant Observers (e.g., `UserRoleObserver`, `UserEntityObserver`).
- **Rollback Plan**: Remove the `Cache::remember` wrapper from the payload builder.

### [PERF-03] Parallelize Triagem Universal Dashboard Requests
- **Description**: The *Triagem Universal* dashboard on the frontend loads 5 different analytical views. Currently, these requests may be firing sequentially, causing the dashboard to take 5+ seconds to render.
- **Acceptance Criteria**: 
  - [ ] Refactor the frontend data fetching logic for the Triagem Universal dashboard.
  - [ ] Use `Promise.all` (if using vanilla fetch/axios) or configure TanStack Query's `useQueries` to fire all 5 requests concurrently.
  - [ ] The dashboard should render significantly faster.
- **Risk Mitigation**: Firing 5 concurrent requests might overwhelm a single PHP-FPM worker if the DB queries are slow. Ensure the database is appropriately indexed for these analytical endpoints.
- **Rollback Plan**: Revert the frontend fetch logic to sequential loading.
