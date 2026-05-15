# Week 12: Developer Experience (Part 2) & Feature Rollout

**Goal**: Finalize the core architecture and safely roll out complex feature migrations using canary patterns.

## Sprint Context
- **Business Value**: Large features (like the new Ownership V2 rules) carry immense risk if deployed universally. Feature flags allow gradual rollouts and instant rollbacks.
- **Prerequisites**: Ownership V2 code must be complete but hidden behind the existing `.env` flag.

## Tickets / Developer Tasks

### [DX-03] Implement Dynamic Feature Flag System
- **Description**: Currently, feature flags (like `OWNERSHIP_CHILD_ACCESS_V2_ENABLED`) are hardcoded in `.env`, requiring a server restart to toggle. Implement a dynamic, database-backed (or Redis-backed) feature flag system.
- **Acceptance Criteria**: 
  - [ ] Install a feature flag package (e.g., Laravel Pennant).
  - [ ] Migrate `OWNERSHIP_CHILD_ACCESS_V2_ENABLED` to a dynamic feature flag.
  - [ ] Create a simple UI or Artisan command for super admins to toggle flags for specific entities or globally.
- **Risk Mitigation**: Ensure the default state of any flag falls back safely to the legacy behavior if the flag system fails.
- **Rollback Plan**: Revert back to reading from `config()` and `.env`.

### [FEAT-01] Safely Roll Out Ownership V2
- **Description**: Use the new dynamic feature flag system to roll out the Ownership V2 child access rules to a single "canary" school entity.
- **Acceptance Criteria**: 
  - [ ] Enable the `ownership_v2` flag for a specific test entity ID via Laravel Pennant.
  - [ ] Monitor logs and user reports from that specific entity for 48 hours.
  - [ ] If successful, enable the flag globally.
- **Risk Mitigation**: The legacy behavior must remain completely intact for all other entities during the canary phase. Ensure `EnsureEntityAccess` handles the branching logic flawlessly.
- **Rollback Plan**: Instantly toggle the flag to `false` in the database/Redis, reverting the canary entity to legacy access rules.
