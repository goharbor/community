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
- Rich debugging and tracing.
- Strong community adoption.
- Accessible for both frontend and backend contributors.

## Goals
- Replace UI/XPath-based Robot tests with Playwright.
- Migrate testcases incrementally by multiple PRs in a non-blocking manner.
- Maintain coverage during migration.
- Improve contributor experience and onboarding.
- Retire Robot tests after achieving 1:1 coverage.

## Non-goals
- Immediate deletion of Robot tests.
- Creating a single PR including all changes.

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
- Better developer experience.
- Easier contributions.
- Reduced technical debt by retiring Robot + Selenium.
