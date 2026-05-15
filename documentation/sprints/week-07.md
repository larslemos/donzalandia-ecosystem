# Week 07: Database Optimization (Part 1)

**Goal**: Prepare the database for high read concurrency by splitting analytical workloads from transactional ones.

## Sprint Context
- **Business Value**: Aggregation queries for dashboards can lock tables or consume massive CPU, slowing down real-time triage entry for professionals. Route these heavy reads to a replica.
- **Prerequisites**: A MySQL Read Replica must be provisioned in the cloud provider.

## Tickets / Developer Tasks

### [DB-01] Configure MySQL Read Replica
- **Description**: Laravel supports read/write database connections natively. Configure the application to route specific analytical queries to a read replica.
- **Acceptance Criteria**: 
  - [ ] Add read/write connection arrays to `config/database.php`.
  - [ ] Update production `.env` to support `DB_READ_HOST`.
  - [ ] Verify that basic Eloquent writes (`Triage::create`) go to the primary, while generic `User::find()` queries route to the replica automatically.
- **Risk Mitigation**: Replication lag. If a user creates a triage and immediately redirects to a dashboard, the data might not be on the replica yet. Laravel's `sticky => true` config handles this by pinning the session to the write DB for the remainder of the request.
- **Rollback Plan**: Remove the read replica configuration from `.env` and `database.php`.

### [DB-02] Enforce Server-Side Pagination
- **Description**: Some list endpoints (e.g., `cadastro/children`, `referrals/inbox`) currently return the entire dataset. This causes multi-megabyte JSON payloads that freeze the React frontend.
- **Acceptance Criteria**: 
  - [ ] Identify all non-paginated list endpoints returning potentially unbounded data.
  - [ ] Update the Eloquent queries to use `->paginate(25)`.
  - [ ] Update the frontend Data Grids (MUI `DataGrid`) to use server-side pagination, passing `page` and `per_page` query parameters.
- **Risk Mitigation**: The frontend UI will break if it expects an array but receives a paginated object (`{ data: [...], current_page: 1 }`). Update the API, Axios interceptors, and React components simultaneously.
- **Rollback Plan**: Revert the backend pagination and frontend DataGrid changes.
