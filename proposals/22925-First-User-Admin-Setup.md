# Proposal: One-Time Admin Password Setup via Web UI

Author: Harsh Varandani / [HARSHVARANDANI](https://github.com/HARSHVARANDANI)

Discussion: [goharbor/harbor#22925](https://github.com/goharbor/harbor/issues/22925)

## Abstract

Introduce a secure, one-time web-based setup flow for the Harbor `admin` account.
When Harbor starts with no `HARBOR_ADMIN_PASSWORD` configured, the admin user
exists in the database but has no password set (`salt=''`). Instead of seeding
the well-known default password `Harbor12345`, Harbor presents a setup page on
first visit where the operator sets the admin password through the browser. Once
set, the page disappears permanently and normal login takes over.

## Background

On a freshly installed Harbor instance, the admin account is initialized in one
of two ways:

1. **Hardcoded default:** `Harbor12345` (common in dev/demo setups, frequently
   left unchanged in production)
2. **Environment variable:** `HARBOR_ADMIN_PASSWORD` must be set before first
   startup

Both approaches have significant drawbacks:

- **Default passwords are a security anti-pattern.** Shared default credentials
  (`admin`/`Harbor12345`) are well-known and frequently targeted by automated
  scanners and botnets. A freshly deployed Harbor instance with default
  credentials is immediately vulnerable.
- **Environment variables require pre-configuration.** The operator must know
  about `HARBOR_ADMIN_PASSWORD` and set it before the first startup. If
  forgotten or misconfigured, the admin either gets a known default or an empty
  password (depending on the deployment method), both of which are problematic.
- **No feedback loop.** The system provides no indication to the first visitor
  that security setup is incomplete.

This is a long-standing concern in the community:

- [goharbor/harbor#22925](https://github.com/goharbor/harbor/issues/22925) — Secure one-time admin setup flow (this issue)
- [goharbor/harbor#13712](https://github.com/goharbor/harbor/issues/13712) — Security hardening: remove default admin password

### Precedent in Other Open-Source Projects

This "first-visitor claims admin" pattern is well-established across major
open-source projects:

| Project        | Implementation                                                                                                                           |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **WordPress**  | "Famous 5-minute install"; first visitor gets a wizard to set site title, admin username, password, and email                            |
| **Gitea**      | Initial configuration page on first visit. The first registered user automatically becomes admin. `INSTALL_LOCK` flag prevents re-access |
| **Nextcloud**  | Installation wizard; enter admin username and password on first browser visit                                                            |
| **Open WebUI** | The first account created automatically gets immutable administrator privileges                                                          |
| **FusionAuth** | Setup wizard creates first admin with email/password, then logs them in                                                                  |
| **Mattermost** | Initialization wizard on first access; creates admin account and initial team                                                            |

## Proposal

### Overview

The core idea is simple: use the existing `harbor_user.salt` column as a
source of truth. A freshly created admin row (user_id=1) with an empty `salt`
means "unclaimed." No new database columns or migrations are needed.

The solution introduces two lightweight HTTP endpoints on the existing Beego
controller layer (`/c/setup/status` and `/c/setup`), a new Angular setup page
component, and route guards that redirect users to the setup page when the admin
account is unclaimed.

### Priority Order

The startup logic follows a clear priority chain:

1. **`HARBOR_ADMIN_PASSWORD` env var / config is set** → Existing behavior
   (password applied on startup, no setup page). Full backwards compatibility.
2. **Admin already has a password** (salt is non-empty) → Mark initialized, no
   changes. Existing deployments are unaffected on upgrade.
3. **Neither** (fresh install, no password configured) → Admin row has empty
   salt. Setup page is served to the first visitor.

### Definitions

- **`admin_initialized`**: A new boolean config key persisted in Harbor's
  configuration store. When `true`, the one-time setup is complete.
- **Setup Required**: The condition where `admin.Salt == ""` — the admin user
  has no password set in the database.
- **Claiming admin**: The act of the first visitor setting the admin password
  via the setup page, after which the setup page is no longer accessible.

### Architecture

```
Browser                        Harbor Core (Go)                  Database
  │                                  │                              │
  │  GET /c/setup/status             │                              │
  │ ──────────────────────────────►  │  SELECT salt FROM            │
  │                                  │    harbor_user WHERE id=1    │
  │  { setup_required: true/false }  │ ◄────────────────────────────│
  │ ◄──────────────────────────────  │                              │
  │                                  │                              │
  │  POST /c/setup                   │                              │
  │  { password: "..." }             │                              │
  │ ──────────────────────────────►  │  1. Check salt == ""         │
  │                                  │  2. Validate password        │
  │                                  │  3. UPDATE harbor_user       │
  │                                  │     SET password, salt       │
  │                                  │     WHERE id=1 AND salt=''   │
  │                                  │  ──────────────────────────► │
  │                                  │  4. Set admin_initialized    │
  │  200 { ok: true }               │                              │
  │ ◄──────────────────────────────  │                              │
```

### Backend

#### Startup Logic (3-Branch)

The existing `updateInitPassword` call in `src/core/main.go` is replaced with
three-branch logic:

```go
adminUser, adminErr := pkguser.Mgr.Get(ctx, adminUserID)
if adminErr != nil {
    log.Fatalf("failed to get admin user: %v", adminErr)
}

if adminUser.Salt != "" {
    // Branch 1: Existing deployment — admin already has a password
    if !adminInitialized {
        cfgMgr.Set(ctx, common.AdminInitialized, true)
        cfgMgr.Save(ctx)
        log.Info("Admin already has a password. Set admin_initialized=true.")
    }
} else if password != "" {
    // Branch 2: Fresh install with HARBOR_ADMIN_PASSWORD set
    updateInitPassword(ctx, adminUserID, password)
    cfgMgr.Set(ctx, common.AdminInitialized, true)
    cfgMgr.Save(ctx)
    log.Info("Admin password seeded from config.")
} else {
    // Branch 3: Fresh install, no password configured → setup pending
    log.Info("No admin password configured. One-time setup page will be available.")
}
```

#### Config Metadata

A new boolean config key `admin_initialized` is registered in the metadata list
with `SystemScope`, defaulting to `false`:

```go
{Name: common.AdminInitialized, Scope: SystemScope, Group: BasicGroup,
 EnvKey: "", DefaultValue: "false", ItemType: &BoolType{}, Editable: false}
```

#### API Endpoints

Two new routes are registered on `CommonController`, following the existing
pattern of `/c/login` and `/c/userExists`:

| Method | Path              | Handler         | Description                                                         |
| ------ | ----------------- | --------------- | ------------------------------------------------------------------- |
| `GET`  | `/c/setup/status` | `SetupStatus()` | Returns `{ "setup_required": bool }` based on admin salt            |
| `POST` | `/c/setup`        | `Setup()`       | Accepts `{ "password": "..." }`, validates, and sets admin password |

##### `GET /c/setup/status` — Response

```json
{
  "setup_required": true
}
```

| Field            | Type    | Description                                       |
| ---------------- | ------- | ------------------------------------------------- |
| `setup_required` | boolean | `true` if admin password has not been initialized |

##### `POST /c/setup` — Request

```json
{
  "password": "SecurePassword123"
}
```

##### `POST /c/setup` — Response

Success (`200 OK`):

```json
{
  "ok": true
}
```

Error responses:

| Status | Meaning                                            |
| ------ | -------------------------------------------------- |
| `400`  | Invalid request body or weak password              |
| `403`  | Setup already completed (`salt` is non-empty)      |
| `409`  | Admin password was claimed by a concurrent request |
| `500`  | Internal server error                              |

The `Setup()` endpoint enforces several preconditions:

1. **Admin salt must be empty** — returns `403 Forbidden` if already set
2. **Content-Type must be `application/json`** — returns `400 Bad Request` otherwise
3. **Password is required** — returns `400 Bad Request` if empty
4. **Password strength validation** — 8-128 characters, at least 1 uppercase,
   1 lowercase, and 1 number (matching Harbor's existing password policy)
5. **Atomic database update** — `UPDATE ... WHERE salt = ''` prevents race
   conditions when two visitors submit simultaneously

```go
func (cc *CommonController) Setup() {
    ctx := cc.Ctx.Request.Context()
    admin, _ := pkguser.Mgr.Get(ctx, 1)

    // Precondition: admin must be unclaimed
    if admin.Salt != "" {
        cc.CustomAbort(http.StatusForbidden, "Setup has already been completed.")
        return
    }

    // Validate password strength
    if !validSetupPassword(req.Password) {
        cc.CustomAbort(http.StatusBadRequest, "Password does not meet requirements.")
        return
    }

    // Atomic set — only succeeds if salt is still empty
    if err := pkguser.Mgr.SetInitialPassword(ctx, 1, password); err != nil {
        if errors.IsConflictErr(err) {
            cc.CustomAbort(http.StatusConflict, "Admin password was set by another request.")
            return
        }
        // ...
    }

    cfgMgr.Set(ctx, common.AdminInitialized, true)
    cfgMgr.Save(ctx)
}
```

#### Password Validation

Password strength is validated using the same rules as the rest of Harbor
(`requireValidSecret` in `src/server/v2.0/handler/user.go`):

```go
func validSetupPassword(password string) bool {
    if len(password) < 8 || len(password) > 128 {
        return false
    }
    return hasLower.MatchString(password) &&
           hasUpper.MatchString(password) &&
           hasNumber.MatchString(password)
}
```

### Frontend

#### Setup Service

A new `SetupService` encapsulates all communication with the backend setup
endpoints. It caches the status result to avoid redundant HTTP calls across
guard checks:

```typescript
@Injectable({ providedIn: "root" })
export class SetupService {
  private cachedStatus: boolean | null = null;

  isSetupRequired(): Observable<boolean> {
    if (this.cachedStatus !== null) {
      return of(this.cachedStatus);
    }
    return this.http.get<SetupStatusResponse>("/c/setup/status").pipe(
      map((res) => res.setup_required),
      tap((val) => (this.cachedStatus = val)),
      catchError(() => of(false)),
    );
  }

  setupAdminPassword(password: string): Observable<any> {
    return this.http.post("/c/setup", { password }).pipe(
      tap(() => {
        this.cachedStatus = false;
      }),
    );
  }
}
```

#### Initial Setup Page

A new `InitialSetupComponent` at the route `/account/initial-setup` provides
the password setup form. The page visually matches Harbor's existing login page
(Clarity UI `login-wrapper` pattern) for a consistent experience:

- Two password fields (password + confirm) with eye-toggle visibility
- Real-time password strength hint (8-128 chars, uppercase, lowercase, number)
- Mismatch detection between password and confirmation
- Status states: `normal` → `ongoing` (spinner) → `success` (redirect to login)
  or `error` (inline message)
- On success, a 2-second delay with a success message before redirecting to
  sign-in

#### Route Guards

Three route guards are involved:

| Guard                           | Behavior                                                                                                                          |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **`SetupGuard`** (new)          | Protects `/account/initial-setup`. Allows access only when `setup_required` is `true`; redirects to sign-in otherwise.            |
| **`SignInGuard`** (modified)    | Protects `/account/sign-in`. If `setup_required` is `true`, redirects to the setup page instead of allowing sign-in.              |
| **`AuthCheckGuard`** (modified) | Protects authenticated routes. On auth failure, checks setup status first — redirects to setup if required, otherwise to sign-in. |

The guard interaction flow:

```
User visits any page
  └─► AuthCheckGuard
        ├─ authenticated? → allow
        └─ not authenticated?
              └─► SetupService.isSetupRequired()
                    ├─ true  → redirect to /account/initial-setup
                    └─ false → redirect to /account/sign-in

User visits /account/sign-in
  └─► SignInGuard
        └─► SetupService.isSetupRequired()
              ├─ true  → redirect to /account/initial-setup
              └─ false → proceed normally

User visits /account/initial-setup
  └─► SetupGuard
        └─► SetupService.isSetupRequired()
              ├─ true  → allow
              └─ false → redirect to /account/sign-in
```

#### Internationalization

All user-facing strings are externalized via `ngx-translate` under the
`INITIAL_SETUP` key namespace. Translations are added to all 10 locale files
(`en-us`, `zh-cn`, `zh-tw`, `de-de`, `es-es`, `fr-fr`, `ko-kr`, `pt-br`,
`ru-ru`, `tr-tr`), with English strings as the initial fallback for non-English
locales.

## Non-Goals

- **This does NOT add a full setup wizard** (database config, storage config,
  LDAP/OIDC settings, etc.) — only admin credential initialization.
- **This does NOT affect LDAP/OIDC auth modes.** The superuser (`user_id=1`)
  always uses database auth regardless of the configured auth mode.
- **This does NOT allow choosing the admin username.** The admin account is
  always `admin` (user_id=1). Allowing custom admin usernames could be explored
  in a future proposal.
- **This does NOT add email setup** to the initial setup page. Email
  configuration is a separate concern handled through the admin settings after
  login.

## Rationale

### Why not just remove the default and require the env var?

Requiring `HARBOR_ADMIN_PASSWORD` before startup adds friction for new users
and doesn't provide a feedback loop. If the operator forgets or misconfigures
the variable, the system either falls back to a default or fails silently. The
web-based setup provides an intuitive, self-documenting experience.

### Why not use a full setup wizard like WordPress?

Harbor's infrastructure configuration (database, storage backend, Redis, etc.)
is handled by `harbor.yml` / Helm values and is quite complex. A web wizard
for these settings would be a massive undertaking with little benefit, since
these settings must be correct _before_ Harbor can start. The admin password is
the one credential that can safely be deferred to runtime.

### Why use `admin.Salt == ""` instead of a new DB column?

The salt column is already present and is empty by default for a freshly
inserted admin row. Using it as the source of truth avoids database migrations,
keeps the change minimal, and is semantically accurate — an empty salt means
no password has been set.

### Why add `admin_initialized` config key if `salt` already indicates state?

The `salt` field remains the **primary source of truth**. The `admin_initialized`
config key serves as:

- **Startup optimization** — avoids repeated database queries during
  initialization by providing a fast-path check via the config manager.
- **Operational visibility** — administrators can inspect the configuration
  state through Harbor's configuration manager without querying the user table.
- **Future extensibility** — allows expansion of the setup flow (e.g., adding
  email or username setup) without relying solely on database heuristics.

The system remains correct even if the flag is missing or inconsistent, since
the `salt` field is authoritative. On startup, the 3-branch logic reconciles
any discrepancy.

### Why not expose setup status through `/api/v2.0/systeminfo`?

Adding fields to the public systeminfo API would expose internal setup state to
any unauthenticated caller. The dedicated `/c/setup/status` endpoint is
purpose-built, follows the existing `/c/` controller pattern, and can be
independently secured or rate-limited in the future if needed.

## Security Considerations

This proposal improves Harbor's default security posture by eliminating the
well-known shared default credential (`admin` / `Harbor12345`). However, the
"first visitor claims admin" model introduces several considerations that are
addressed below.

### Unauthorized First Visitor

If Harbor is exposed to a public network before setup is completed, an
unauthorized visitor could claim the admin account.

**Mitigation strategies:**

- Harbor is typically deployed behind internal networks, VPNs, or Kubernetes
  ingress policies.
- Operators deploying Harbor on a public-facing network should set
  `HARBOR_ADMIN_PASSWORD` explicitly, which bypasses the setup page entirely.
- Documentation will recommend completing initial setup before exposing Harbor
  publicly.
- This is consistent with the security model used by other OSS platforms such
  as WordPress, Nextcloud, and Gitea, all of which rely on the same assumption.

### Race Conditions

Multiple visitors may attempt to claim the admin account simultaneously. This is
mitigated by the atomic database update condition:

```sql
UPDATE harbor_user
SET password = ?, salt = ?
WHERE user_id = 1 AND salt = ''
```

Only the first request succeeds. Subsequent requests receive `HTTP 409 Conflict`.
No application-level locking is required.

### Brute Force Attempts

The setup endpoint has a very limited attack window:

- `/c/setup` is only functional while `admin.Salt == ""`.
- Once setup completes, `/c/setup/status` returns `setup_required=false` and
  `/c/setup` returns `403 Forbidden`.
- The endpoint enforces password strength requirements, preventing weak
  passwords even during the brief window.

## High Availability Considerations

Harbor deployments often run multiple `core` instances behind a load balancer
(e.g., in Kubernetes). This design remains safe in HA environments because:

- The **database is the single source of truth** (`harbor_user.salt`).
- The admin claim operation uses an **atomic SQL update with a WHERE condition**.
- All Harbor core nodes observe the same database state.

Example race scenario with two pods:

```
User A → Core Pod 1 → POST /c/setup
User B → Core Pod 2 → POST /c/setup

Both attempt:
  UPDATE harbor_user SET password=?, salt=? WHERE user_id=1 AND salt=''

Only one transaction succeeds (database row-level locking).
The losing request receives 409 Conflict.
```

No distributed locks or leader election are required.

## Failure Recovery

**If the setup request fails before the database update completes:**

- The admin account remains unclaimed (`salt=''`).
- The setup page continues to be available.
- The user can simply retry.

**If Harbor crashes after the password update but before writing
`admin_initialized=true`:**

- The database `salt` is already populated.
- `/c/setup/status` reads from the database and will return `setup_required=false`.
- On the next startup, Branch 1 of the startup logic detects the non-empty salt
  and sets `admin_initialized=true`.

Thus the setup process is **idempotent and crash-safe**. The `admin_initialized`
flag is a performance optimization, not a correctness requirement.

## Compatibility

- **Existing deployments (upgrade):** On first startup after upgrade, the
  startup logic detects that admin already has a salted password, sets
  `admin_initialized=true`, and continues normally. No user action required.
- **Existing deployments using `HARBOR_ADMIN_PASSWORD`:** Behavior is identical
  to today. The env var takes precedence; the password is seeded on startup and
  the setup page is never shown.
- **Fresh installs with `HARBOR_ADMIN_PASSWORD` set:** Same as above — the env
  var seeds the password and the setup page is skipped.
- **Fresh installs without `HARBOR_ADMIN_PASSWORD`:** The only changed case.
  Instead of seeding `Harbor12345`, the system shows the setup page.
- **No database migration required.** The solution uses the existing
  `harbor_user.salt` column and Harbor's config metadata system.
- **No configuration migration required.** The new `admin_initialized` config
  key defaults to `false` and is automatically set on first startup.
- **Helm deployments:** Operators can continue to provide `harborAdminPassword`
  via Helm values. If this value is omitted, the interactive setup page will be
  used instead. No Helm chart changes are required.

## Implementation

The implementation is structured into the following components, all included in
a single PR:

### 1. Backend — Config & Startup Logic

- Add `AdminInitialized` constant to `src/common/const.go`
- Register config metadata in `src/lib/config/metadata/metadatalist.go`
- Implement 3-branch startup logic in `src/core/main.go`
- Update `make/harbor.yml.tmpl` with documentation comments

### 2. Backend — Setup Endpoints

- Add `SetupStatus()` and `Setup()` methods to `CommonController` in `src/core/controllers/base.go`
- Register routes in `src/server/route.go`
- Unit tests: `src/core/controllers/setup_test.go` (14 test cases for password validation) and route registration in `controllers_test.go`

### 3. Frontend — Setup Flow

- `SetupService` in `src/portal/src/app/services/setup.service.ts`
- `InitialSetupComponent` (`.ts`, `.html`, `.scss`) in `src/portal/src/app/account/initial-setup/`
- `SetupGuard` in `src/portal/src/app/shared/router-guard/setup-guard.service.ts`
- Route registration and module updates in `account.module.ts`
- Guard modifications: `AuthCheckGuard`, `SignInGuard`

### 4. Frontend — Tests & i18n

- Unit tests for `SetupService`, `InitialSetupComponent`, and updated guard specs
- `INITIAL_SETUP` translation keys added to all 10 locale files

### File Summary

| #     | File                                                                 | Status   | Purpose                           |
| ----- | -------------------------------------------------------------------- | -------- | --------------------------------- |
| 1     | `src/common/const.go`                                                | Modified | `AdminInitialized` constant       |
| 2     | `src/lib/config/metadata/metadatalist.go`                            | Modified | Config metadata entry             |
| 3     | `src/core/main.go`                                                   | Modified | 3-branch startup logic            |
| 4     | `src/core/controllers/base.go`                                       | Modified | `SetupStatus` + `Setup` endpoints |
| 5     | `src/core/controllers/setup_test.go`                                 | New      | Password validation tests         |
| 6     | `src/core/controllers/controllers_test.go`                           | Modified | Route registration in tests       |
| 7     | `src/server/route.go`                                                | Modified | Route registration                |
| 8     | `make/harbor.yml.tmpl`                                               | Modified | Config template comments          |
| 9     | `src/portal/.../services/setup.service.ts`                           | New      | Setup API service                 |
| 10    | `src/portal/.../services/setup.service.spec.ts`                      | New      | Service tests                     |
| 11    | `src/portal/.../initial-setup/initial-setup.component.ts`            | New      | Setup page component              |
| 12    | `src/portal/.../initial-setup/initial-setup.component.html`          | New      | Setup page template               |
| 13    | `src/portal/.../initial-setup/initial-setup.component.scss`          | New      | Setup page styles                 |
| 14    | `src/portal/.../initial-setup/initial-setup.component.spec.ts`       | New      | Component tests                   |
| 15    | `src/portal/.../router-guard/setup-guard.service.ts`                 | New      | Setup route guard                 |
| 16    | `src/portal/.../account/account.module.ts`                           | Modified | Route + module config             |
| 17    | `src/portal/.../router-guard/auth-user-activate.service.ts`          | Modified | Setup redirect logic              |
| 18    | `src/portal/.../router-guard/auth-user-activate.service.spec.ts`     | Modified | Mock provider                     |
| 19    | `src/portal/.../router-guard/sign-in-guard-activate.service.ts`      | Modified | Setup redirect logic              |
| 20    | `src/portal/.../router-guard/sign-in-guard-activate.service.spec.ts` | Modified | Mock provider                     |
| 21–30 | `src/portal/src/i18n/lang/*-lang.json` (10 files)                    | Modified | i18n translations                 |
