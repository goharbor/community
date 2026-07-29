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
FROM ubuntu:20.04

ENV TZ=Asia/Shanghai \
    DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8
ENV HELM_EXPERIMENTAL_OCI=1
ENV COSIGN_PASSWORD=Harbor12345
ENV COSIGN_EXPERIMENTAL=1
ENV COSIGN_OCI_EXPERIMENTAL=1
ENV NOTATION_EXPERIMENTAL=1

# Install basic dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    gnupg2 \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    libseccomp2 \
    git \
    iproute2 \
    iptables \
    build-essential \
    sed \
    libssl-dev \
    tar \
    unzip \
    gzip \
    jq \
    libnss3-tools \
    sudo

# Install Google Chrome
RUN wget --no-check-certificate -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-chrome-stable

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest

# Install Docker Engine
RUN DOCKER_VERSION=27.1.1 && \
    wget https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_VERSION.tgz && \
    tar --strip-components=1 -xvzf docker-$DOCKER_VERSION.tgz -C /usr/bin && \
    rm docker-$DOCKER_VERSION.tgz

# Copy Harbor test tools if needed
# COPY --from=tool_builder /tool/tools.tar.gz /usr/local/bin

WORKDIR /app

# Install Playwright and dependencies
COPY package.json package-lock.json ./
RUN npm ci && \
    npx playwright install --with-deps && \
    apt-get clean all

COPY . .

# Setup NSS database for certificates
RUN mkdir -p $HOME/.pki/nssdb && \
    echo Harbor12345 > password.ca && \
    certutil -d sql:$HOME/.pki/nssdb -N -f password.ca

# Docker volume for Docker-in-Docker
VOLUME /var/lib/docker

# Default command to run tests
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

## Running Commands & Keyword-Driven Execution

### Q1: How does the running command look like?

Using Docker (production/CI):
```bash
E2E_IMAGE=goharbor/harbor-e2e-engine:playwright-ui

# Basic run - all tests
docker run -i \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/test-results:/app/test-results \
  -e BASE_URL=https://harbor.example.com \
  -e IP=harbor.example.com \
  -e HARBOR_PASSWORD=Harbor12345 \
  -w /app \
  $E2E_IMAGE npx playwright test

# With HTML report
docker run -i \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/playwright-report:/app/playwright-report \
  -e BASE_URL=https://harbor.example.com \
  -e IP=harbor.example.com \
  -w /app \
  $E2E_IMAGE npx playwright test --reporter=html
```

Direct execution (development):
```bash
cd src/portal
export BASE_URL=https://harbor.example.com
export IP=harbor.example.com
npx playwright test
```

Real examples from Harbor CI ([see workflow](https://github.com/bupd/harbor/blob/87b9f97/.github/workflows/playwright.yml)):
```bash
cd src/portal
npm ci
npx playwright install --with-deps
npx playwright test
```

### Q2: Does Playwright support keyword-driven execution?

Yes. Playwright supports keyword-driven execution through test filtering and grep patterns, similar to Robot Framework's tag-based execution.

Run tests by keyword/title:
```bash
# Single keyword
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test -g "trivy"

# Multiple keywords (OR)
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test -g "trivy|webhook"

# Exclude keywords
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test --grep-invert "slow"
```

Run specific test files:
```bash
# Single file
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test trivy.spec.ts

# Multiple files
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test trivy.spec.ts webhook.spec.ts
```

Control parallelism and retries:
```bash
# Sequential execution (like Robot)
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test --workers=1

# With retries
docker run -i -v $(pwd)/test-results:/app/test-results -w /app \
  $E2E_IMAGE npx playwright test --retries=2
```

Reference implementations:
- Initial setup: https://github.com/goharbor/harbor/pull/22462
- Dockerized tests: https://github.com/goharbor/harbor/pull/22591

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

- HTML Test Report - All Tests Passing
<img width="1014" height="690" alt="image" src="https://github.com/user-attachments/assets/fc87ad01-5350-467a-88f6-51734b83212e" />

- Video Recording in Test Reports
<img width="1395" height="770" alt="image" src="https://github.com/user-attachments/assets/9d3386ea-4487-4840-908e-abadf7b66cf2" />

- Interactive Debug Mode - Running Tests with Inspector
<img width="1183" height="770" alt="image" src="https://github.com/user-attachments/assets/709cc2bd-9507-468c-865e-1120e6107dd9" />

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
