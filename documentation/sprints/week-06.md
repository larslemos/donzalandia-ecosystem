# Week 06: Architecture Refactoring (Part 2)

**Goal**: Refine frontend caching and finalize architectural tweaks from the previous week.

## Sprint Context
- **Business Value**: A snappy UI relies on intelligent caching. The current frontend cache invalidation strategy is too aggressive, causing unnecessary loading states.
- **Prerequisites**: None.

## Tickets / Developer Tasks

### [ARCH-03] Selective TanStack Query Invalidation
- **Description**: When a user switches their active entity, the frontend currently calls `queryClient.clear()`. This wipes out ALL cached data, forcing a massive re-fetch waterfall of dictionaries, user settings, and unrelated data.
- **Acceptance Criteria**: 
  - [ ] Identify all query keys that are strictly tied to the `entity_id` (e.g., children lists, dashboards, triages).
  - [ ] Replace `queryClient.clear()` in the entity switching logic with `queryClient.invalidateQueries`.
  - [ ] Use a predicate function or specific query key arrays to invalidate ONLY the queries that depend on the active entity.
  - [ ] Verify that global data (e.g., the current user's profile, system dictionaries) remains cached across entity switches.
- **Risk Mitigation**: If a query key is missed during the refactor, users might see data from the previous entity. Perform thorough manual QA on the entity switching flow.
- **Rollback Plan**: Revert the invalidation logic back to `queryClient.clear()`.

### [ARCH-04] Frontend Bundle Optimization (Material UI)
- **Description**: The Vite configuration currently bundles the massive Material UI (MUI) library into the main application chunk, increasing initial load times.
- **Acceptance Criteria**: 
  - [ ] Update `vite.config.js` to split `@mui/material`, `@mui/lab`, `@mui/x-data-grid`, and `@emotion` into their own manual chunk (e.g., `vendor-mui`).
  - [ ] Run a production build (`yarn build`) and verify via a bundle analyzer that the main chunk size has significantly decreased.
  - [ ] Ensure the application still loads correctly without missing styles or components.
- **Risk Mitigation**: Incorrect code splitting can cause circular dependencies or loading errors. Test the production build locally before deploying.
- **Rollback Plan**: Revert the changes to the `manualChunks` configuration in `vite.config.js`.
