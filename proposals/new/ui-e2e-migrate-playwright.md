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
- It supports sequential runs.
- Secrets are handled through environment variables.
- It supports fixtures and helper modules. https://playwright.dev/docs/test-fixtures
- Skipping, tagging, grouping, and environment-driven execution are built-in https://playwright.dev/docs/test-annotations
- Playwright can run CLI operations via Node's `child_process` reliably (docker, helm, oras, cosign, notation).
- Reports, videos, traces, retries, and serial execution already meet & exceed current quality standards.
- The proposed setup preserves existing capabilities while modernizing UI testing, improving speed, maintainability, and debugging.

#### Dockerfile for Playwright E2E Engine

Reference: [POC Dockerfile](https://github.com/bupd/harbor/blob/87b9f97/src/portal/e2e/Dockerfile) | Existing Robot UI Engine: [Dockerfile.ui_test](https://github.com/goharbor/harbor/blob/main/tests/test-engine-image/Dockerfile.ui_test)

```dockerfile
FROM node:20-bookworm

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    sudo

# Add Docker's GPG key
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
RUN apt-get update && apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install @playwright/test
RUN npx playwright install --with-deps

COPY . .

# Command to run the tests
CMD ["npx", "playwright", "test", "--reporter=html"]
```

#### Running Tests in Docker

```bash
E2E_IMAGE=goharbor/harbor-e2e-engine:playwright-ui

# Run all tests
docker run -i \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/test-results:/app/test-results \
  -e HARBOR_URL=https://harbor.example.com \
  -e HARBOR_ADMIN_PASSWORD=Harbor12345 \
  -w /app \
  $E2E_IMAGE npx playwright test

# Run tests with HTML report
docker run -i \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/test-results:/app/test-results \
  -w /app \
  $E2E_IMAGE npx playwright test --reporter=html
```

#### Keyword-Driven Execution

Playwright supports keyword-driven execution similar to Robot Framework. See the [official documentation](https://playwright.dev/docs/running-tests#run-specific-tests) for details.

```bash
E2E_IMAGE=goharbor/harbor-e2e-engine:playwright-ui

# Run tests by title/keyword (using -g flag for grep)
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test -g "create new project"

# Run tests matching multiple keywords
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test -g "login|logout"

# Run tests by file name pattern
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test project

# Run a specific test file
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test tests/project.spec.ts

# Run tests with specific tag (using grep)
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test -g "@smoke"

# Run tests in headed mode (for debugging, requires X11 forwarding)
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
  $E2E_IMAGE npx playwright test -g "create new project" --headed
```

#### Common Playwright CLI Options

| Option | Description | Example |
|--------|-------------|---------|
| `-g, --grep <pattern>` | Run tests matching title pattern | `npx playwright test -g "login"` |
| `--grep-invert <pattern>` | Run tests NOT matching pattern | `npx playwright test --grep-invert "slow"` |
| `--project <name>` | Run tests in specific project/browser | `npx playwright test --project=chromium` |
| `--headed` | Run in headed browser mode | `npx playwright test --headed` |
| `--debug` | Run with Playwright Inspector | `npx playwright test --debug` |
| `--trace on` | Record trace for each test | `npx playwright test --trace on` |
| `--reporter <type>` | Specify reporter (list, html, json) | `npx playwright test --reporter=html` |
| `--workers <n>` | Set number of parallel workers | `npx playwright test --workers=4` |
| `--retries <n>` | Set retry count for failed tests | `npx playwright test --retries=2` |

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

## Technical Considerations

### Process Orchestration & Parallelism

Configuration: Tests run sequentially in CI (--workers=1) to avoid docker daemon conflicts, port collisions, and resource contention - identical to current Robot Framework behavior.

```typescript
// playwright.config.ts
export default defineConfig({
  workers: process.env.CI ? 1 : undefined,  // Sequential in CI, parallel in dev
  fullyParallel: false,
  retries: process.env.CI ? 2 : 0,
});
```

Resource Management: Playwright fixtures provide setup/teardown guarantees equivalent to Robot's suite setup/teardown, ensuring clean state and proper resource cleanup between tests.

### Credential Safety

Credentials are handled through environment variables and never hardcoded. GitHub Actions automatically masks secrets in logs. Playwright traces are configured to capture only on first retry, with screenshots and videos only on failure. Test helper functions never log credentials directly - they use data attributes and environment variables for sensitive inputs.

```typescript
export default defineConfig({
  use: {
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
});
```

### SSH Operations (when needed)

UI tests rarely require SSH. When infrastructure setup needs remote operations, Node.js libraries like `ssh2` provide equivalent functionality to Robot's SSHLibrary.

### Reporting Comparison: Robot vs Playwright

| Capability | Robot Framework | Playwright |
|------------|----------------|------------|
| HTML Reports | ✅ Keyword-level logs | ✅ Test-level reports |
| Screenshots | ✅ On failure only | ✅ Configurable (failure/always/never) |
| Videos | ❌ Not supported | ✅ Full test recordings |
| Network Traces | ❌ Not supported | ✅ Complete request/response logs |
| Interactive Trace Viewer | ❌ Not supported | ✅ Step-through with DOM snapshots |
| Retry Tracking | ⚠️ Basic | ✅ Separate reports per retry |
| CI Integration | ⚠️ Basic | ✅ GitHub Actions annotations + summaries |
| Debugging Experience | ⚠️ Limited | ✅ Inspector, codegen, trace viewer |

Playwright's reporting capabilities significantly exceed Robot Framework's, particularly for debugging UI flakiness.

## Scope

This proposal focuses exclusively on UI E2E tests - the XPath-heavy, fragile tests that hinder contribution and maintenance. Infrastructure orchestration tests (those using SSHLibrary, Process, heavy CLI orchestration) are out of scope and will remain in Robot Framework where it excels.

## Goals
- Replace UI/XPath-based Robot tests with Playwright.
- Preserve existing coverage during migration.
- Migrate testcases incrementally by multiple PRs in a non-blocking manner.
- Maintain coverage during migration.
- Improve contributor experience and onboarding.
- Retire Robot UI tests after achieving 1:1 coverage.

## Non-goals
- Replacing Robot Framework for infrastructure/orchestration tests.
- Immediate deletion of Robot tests.
- Creating a single PR including all changes.
- No drop in test quality or coverage during migration.

> Note: Robot UI tests will be retired in Phase 2, after Playwright achieves 1:1 parity. Infrastructure tests remain in Robot Framework.

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
