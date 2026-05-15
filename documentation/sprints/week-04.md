# Week 04: Documentation & Knowledge Transfer

**Goal**: Standardize the development workflow and ensure any developer can deploy and test the application safely.

## Sprint Context
- **Business Value**: A project with a "bus factor" of 1 is a massive risk. Code formatting and linting should not be debated in PRs; they should be enforced by machines. A solid CI pipeline builds confidence for frequent deployments.
- **Prerequisites**: Access to the GitHub/GitLab repository settings to enforce branch protections.

## Tickets / Developer Tasks

### [DOC-01] Implement Pre-commit Hooks (Frontend & Backend)
- **Description**: Add Husky and lint-staged to the React frontend to run ESLint and Prettier before commits. Add a Git hook to run Laravel Pint for the backend before commits. Add a secret scanner (e.g., trufflehog) to prevent further API key leaks.
- **Acceptance Criteria**: 
  - [ ] Initialize Husky in `dondza_cadastro` and configure `lint-staged` for `.js`/`.jsx` files.
  - [ ] Add a `pre-commit` hook to `dondza` that runs `./vendor/bin/pint --test` and aborts if it fails.
  - [ ] Integrate a basic secret scanning check in the pre-commit chain.
  - [ ] Document the setup process in the respective `README.md` files.
- **Risk Mitigation**: Hooks might fail on developers' machines due to missing global dependencies (e.g., trufflehog). Use npx or composer bin links where possible.
- **Rollback Plan**: Remove the Husky initialization and the `.husky`/`.git/hooks` configurations.

### [DOC-02] Configure CI Pipeline via GitHub Actions
- **Description**: Currently, tests are run manually. Configure a CI pipeline that runs the test suites and lints the code on every Pull Request against the `main` branch.
- **Acceptance Criteria**: 
  - [ ] Create a `.github/workflows/test-backend.yml` file to run PHPUnit tests against an ephemeral MySQL database.
  - [ ] Create a `.github/workflows/test-frontend.yml` file to run Vitest.
  - [ ] Branch protection rules are updated to require passing CI status checks before a PR can be merged.
- **Risk Mitigation**: Flaky tests might block legitimate PRs. Identify and isolate flaky tests (if any) before enforcing the status check.
- **Rollback Plan**: Disable branch protection rules and delete the workflow files.
