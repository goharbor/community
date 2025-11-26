# Proposal: Migrate UI E2E Tests from Robot + Selenium to Playwright

Author: Prasanth Baskar/[bupd](https://github.com/bupd)

Tracking: [goharbor/harbor#22134](https://github.com/goharbor/harbor/issues/22134)

Timeline: ~3 months (one release cycle v2.15 for Phase 1)

## Summary

Migrate Harbor’s UI end-to-end (E2E) tests from Robot Framework + Selenium to Playwright. The goal is to improve test reliability, reduce technical debt, and enable more contributors to participate in test development. Migration will be incremental; existing Robot testcases will remain until equivalent Playwright coverage exists.

## Motivation

### Current challenges
- Robot testcases rely heavily on XPath and are fragile.
- Difficult to edit or extend, discouraging contributions.
- Poor developer experience compared to modern tooling.

### Why Playwright
- Strong cross-browser, cross-environment support.
- Unified reports (screenshots, videos, traces) built-in.
- Faster execution, automatic waiting, modern API.
- Easier for frontend + backend contributors.
- Simple containerization and reproducible CI runs.
- Strong community adoption.

### Portability & Containerization
- Playwright works consistently across Jenkins, GitHub Actions, GitLab, air-gapped networks, and plain shell environments.
- A single container image can include Playwright browsers + required CLIs (docker, helm, cosign, notation, oras, curl, jq).
- Running via `docker run …` already works today similar to Robot.
- No Selenium server or additional runtime dependency is required.
- It Supports sequential runs.
- Secrets are handled through environment variables.
- It supports 
- It supports fixtures and helper modules. https://playwright.dev/docs/test-fixtures
- Skipping, tagging, grouping, and environment-driven execution are built-in https://playwright.dev/docs/test-annotations
- Playwright can run CLI operations via Node's `child_process` reliably (docker, helm, oras, cosign, notation).
- Reports, videos, traces, retries, and serial execution already meet & exceed current quality standards.
- The proposed setup preserves existing capabilities while modernizing UI testing, improving speed, maintainability, and debugging.

## Screenshots
- Live Browser State Visualization
<img width="1321" height="1032" alt="Screenshot_2025-11-26_18-19-56" src="https://github.com/user-attachments/assets/a925ad4f-e1dd-4f5b-8ec9-3d03d77e7ea8" />

- Full Network Log Capture
<img width="1321" height="1032" alt="Screenshot_2025-11-26_18-20-23" src="https://github.com/user-attachments/assets/288ae102-979c-4527-abc4-fbc87ee4de67" />

- Request/Response Inspection & Assertions
<img width="1321" height="1032" alt="Screenshot_2025-11-26_18-21-09" src="https://github.com/user-attachments/assets/208ecd1e-cf76-4226-9c19-a63a73e038cb" />

<img width="1321" height="1032" alt="Screenshot_2025-11-26_18-21-28" src="https://github.com/user-attachments/assets/018a0e01-091e-41a6-90df-8fb9305b4d2f" />


- Shell Command & Script Execution (Node child-process)
<img width="1321" height="1032" alt="Screenshot_2025-11-26_18-20-11" src="https://github.com/user-attachments/assets/8042fef4-2adf-42cd-95b4-67f2ce92a96f" />


## Goals
- Replace UI/XPath-based Robot tests with Playwright.
- Preserve existing coverage during migration.
- Migrate testcases incrementally by multiple PRs in a non-blocking manner.
- Maintain coverage during migration.
- Improve contributor experience and onboarding.
- Retire Robot tests after achieving 1:1 coverage.

## Non-goals
- Immediate deletion of Robot tests.
- Creating a single PR including all changes.
- No drop in test quality or coverage during migration.

> Note: Robot tests will eventually be deleted, but this will occur in a later phase, not during Phase 1.

## Proposal

### Phase 1 – Migration (This Release Cycle)
(Setup): Add a GitHub Action to run Playwright tests
- Start with nightly UI Robot tests.
- Incrementally migrate testcases to Playwright in multiple PRs.
- Contributors submit migration in multiple small PRs.
- Robot tests remain until Playwright test cases reach 1:1 parity.

### Phase 2 – Retirement (Next Release Cycle)
- Plan to retire Robot UI testcases after migrating all testcases to Playwright.

## Requirements
- Infra Needs: access to AWS Harbor environments for setup (servers, webhooks).
- Contributors: Community-driven migration.

## Checklist for Phase 1
- [ ] Add GitHub Action to run Playwright pipeline.
- [ ] Configure CI to run both Robot and Playwright tests.
- [ ] Configure CI to run Playwright tests on PRs.
- [ ] Break down test suite into smaller subtests.
- [ ] Migrate Robot UI tests to Playwright in multiple PRs.
- [ ] Ensure main branch stays green (non-blocking, incremental merges).
- [ ] Achieve full 1:1 parity with Robot UI tests.
- [ ] Upgrade Angular frontend to latest version.
- [ ] Ensure all UI E2E cases pass in CI with latest Angular frontend.

## Outcome

- Reliable UI tests.
- Better debugging (videos, traces, network logs).
- Stronger developer experience and contributor onboarding.
- Reduced technical debt by retiring Robot + Selenium.
