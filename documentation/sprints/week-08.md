# Week 08: Database Optimization (Part 2)

**Goal**: Keep the primary database lean and optimized to prevent slow degradation over time.

## Sprint Context
- **Business Value**: Databases degrade gracefully until they don't. Missing indexes and unbounded table growth (e.g., orphaned sessions, failed jobs) eventually lead to catastrophic slowdowns.
- **Prerequisites**: Access to production slow query logs.

## Tickets / Developer Tasks

### [DB-03] Implement Automated Pruning
- **Description**: Tables like `sessions` (if not using Redis), `failed_jobs`, and soft-deleted `children` accumulate infinitely. Set up automated pruning.
- **Acceptance Criteria**: 
  - [ ] Add `php artisan auth:clear-resets` to the Laravel Scheduler.
  - [ ] Add `php artisan queue:prune-failed --hours=168` (7 days) to the Scheduler.
  - [ ] If applicable, create a command to permanently delete `children` where `deleted_at` is older than 30 days (GDPR/Compliance check needed).
  - [ ] Ensure the server's crontab is running `* * * * * cd /path/to/project && php artisan schedule:run >> /dev/null 2>&1`.
- **Risk Mitigation**: Deleting child records is highly sensitive. Verify compliance rules regarding data retention before enabling hard deletes.
- **Rollback Plan**: Remove the pruning commands from `App\Console\Kernel` (or `routes/console.php` in Laravel 12).

### [DB-04] Top 5 Slow Query Optimization
- **Description**: The scalability audit identified missing composite indexes and slow queries (e.g., the 5 sequential endpoints in the Universal Dashboard).
- **Acceptance Criteria**: 
  - [ ] Enable the slow query log (`SLOW_QUERY_LOG_ENABLED=true`, threshold 500ms) in staging/production for 48 hours to collect data.
  - [ ] Identify the top 5 slowest queries.
  - [ ] Create a new migration file (e.g., `add_performance_indexes_v2`) to add the necessary indexes (e.g., `(entity_id, status, priority)` on `waiting_list`).
  - [ ] Deploy the migration.
- **Risk Mitigation**: Adding indexes on large tables locks the table during migration. Run migrations during low-traffic hours or use online DDL tools if the database is massive.
- **Rollback Plan**: Create a `down()` method in the migration to drop the added indexes and run `php artisan migrate:rollback`.
