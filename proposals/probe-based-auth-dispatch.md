# Proposal: Probe-Based Authentication Dispatch

Author: Harbor Community

**Status**: IN REVIEW
**Implementation PR**: https://github.com/goharbor/harbor/pull/23458 (Open)

## Abstract

Probe-based authentication dispatch replaces Harbor's single-backend `auth_mode` configuration with a flexible per-backend matching system. This fixes critical production issues: admin lockout when OIDC is unavailable, security vulnerability with locked users authenticating as nil, and registry proxy bypassing per-user permission enforcement. The solution enables fallback authentication paths, corrects HTTP Auth Proxy support, and maintains backward compatibility with existing deployments.

## Background

Harbor's authentication has historically relied on a global `auth_mode` configuration that rigidly selects a single authentication backend:

```
auth_mode = "db"      # Database only
auth_mode = "ldap"    # LDAP only
auth_mode = "oidc"    # OIDC only
auth_mode = "http_auth"  # HTTP Auth Proxy only
auth_mode = "uaa"     # UAA only
```

### Limitations

**1. Admin Lockout in OIDC Mode**
- OIDC provider becomes unavailable (misconfigured, IdP outage, network issue)
- No fallback to local database authentication
- Admin account becomes completely inaccessible
- Recovery requires Harbor restart and manual config edit

**2. Security Bug: Locked Users Authenticate as nil**
- User account locked due to repeated login failures
- `Login()` returns `(nil, nil)` instead of error
- HTTP handlers treat nil as successful login with no user
- Locked accounts silently authenticate and pass authorization checks
- Permission enforcement is bypassed for locked accounts

**3. Registry Proxy Ignores User Credentials**
- Registry proxy always forwards shared service-account credential to upstream
- Per-user permissions are completely bypassed
- Read-only user can push images (proxied as service account)
- No way to enforce repository-level access control

**4. HTTP Auth Proxy Mode Silently Broken**
- `http_auth` mode missing from authentication dispatch switch
- All authentication falls through to database only
- HTTP Auth Proxy configuration non-functional despite config support
- Users cannot implement external authentication proxy pattern

### Design Issues

The root cause: single global `auth_mode` creates an inflexible all-or-nothing dispatch. Enterprise environments often need:
- OIDC as primary + database fallback (for admin access when IdP is down)
- Multiple auth backends with explicit fallback chains
- Per-user credential passthrough for registry proxy use cases
- HTTP Auth Proxy as first-class authentication method

## Proposal

### Core Changes

#### 1. Per-Backend Match() Interface ✅

Each authentication backend implements `Match()` to report whether it should be tried:

```go
type Authenticator interface {
    // Login authenticates user with given credentials
    Login(ctx context.Context, m *models.AuthModel) (*models.User, error)
    
    // Match reports if this backend is configured and should be tried
    // Returns (true, nil) if configured; (false, nil) if not; (false, err) if misconfigured
    Match(ctx context.Context) (bool, error)
    
    // OnBoardUser provisions new user if backend supports it
    OnBoardUser(ctx context.Context, u *models.User) error
    
    // PostAuthenticate post-processes authenticated user (groups, attributes)
    PostAuthenticate(ctx context.Context, u *models.User) error
}
```

#### 2. Multi-Backend Dispatch Logic ✅

The authenticator dispatcher tries backends in priority order; first success wins:

```
Try backends in priority order:
1. OIDC (if configured)
2. LDAP (if configured)
3. UAA (if configured)
4. HTTP Auth Proxy (if configured)
5. Database (always available as fallback)
6. Robot accounts (always via database)
7. Superuser (always via database)

First successful authentication wins.
Errors from non-matching backends are ignored.
Errors from matching backends are fatal.
```

#### 3. Locked User Security Fix ✅

`Login()` now returns `error` for locked users instead of `(nil, nil)`:

```go
// Before: Login returned (nil, nil) for locked users
user, err := authenticator.Login(ctx, model)
if user == nil && err == nil {  // WRONG: treated as successful nil-user login
    // allowed locked user to pass through
}

// After: Login returns ErrAuth for locked users
user, err := authenticator.Login(ctx, model)
if err == ErrAuth {  // Correct: explicitly failed auth
    // reject locked user
    return http.StatusUnauthorized
}
```

#### 4. Registry Proxy User Credential Passthrough ✅

Registry proxy now:
- **Probes** upstream registry to detect auth method (Bearer or Basic)
- **Exchanges** user credentials for scoped Bearer token via token service
- **Caches** tokens per-repository scope (not globally)
- **Falls back** to probed credentials for unauthenticated requests
- **Handles** token service failures gracefully

**Token Caching Strategy:**
- Key: `<user_id>:<repository_scope>` (e.g., `user123:library/myapp`)
- Storage: In-memory with TTL matching token expiration
- Isolation: Separate token per repository scope, preventing privilege escalation
- Fallback: If caching unavailable, exchanges token on each request

#### 5. Auth Probe Detection ✅

Registry proxy probes upstream to detect which auth method to use:

```
GET /v2/ with no credentials
-> If returns 401 with Bearer realm:
   -> Use token service exchange for Bearer tokens
-> If returns 401 with Basic realm:
   -> Use Basic auth passthrough
-> If returns 200:
   -> Anonymous access supported
```

#### 6. HTTP Auth Proxy Mode Support ✅

`http_auth` mode now fully functional:
- HTTP Auth Proxy backend checked in dispatch order
- External auth endpoint validated via `Match()`
- User credentials forwarded to auth proxy
- Local user created on first successful auth (via `OnBoardUser()`)

### Authentication Dispatch Flows

#### OIDC Mode (with fallback)
```
user login
  → try OIDC
    ✓ OIDC succeeds → return user
    ✗ OIDC fails → continue
  → try Database
    ✓ DB succeeds → return user (admin always accessible)
    ✗ DB fails → reject login
```

**Scenario**: OIDC provider down, admin needs access
- Admin logs in with database credentials
- OIDC probe fails, database login succeeds
- Admin regains access without config edit

#### LDAP Mode (no fallback, fails clearly)
```
user login
  → try LDAP
    ✓ LDAP succeeds → return user
    ✗ LDAP fails → reject (clear error message)
  (Database skipped; LDAP is primary)
```

#### HTTP Auth Proxy Mode
```
user login with credentials
  → try HTTP Auth Proxy
    ✓ Proxy accepts → create/update local user, return
    ✗ Proxy rejects → reject (clear error message)
  (no other backends tried)
```

#### Database Mode
```
user login
  → try Database only
    ✓ DB succeeds → return user
    ✗ DB fails → reject
```

### Registry Proxy Auth

#### Probe-based Passthrough
```
Docker push myapp:latest
(user: alice, password: secret)
  → probe upstream for auth method
    returns: 401 Unauthorized, WWW-Authenticate: Bearer realm="..."
  → exchange alice:secret with token service for Bearer token
  → cache token with scope "myapp" for user alice
  → forward image layers with Bearer token
```

#### Per-Scope Token Caching
```
User alice pushes to:
  1. library/myapp → request Bearer token for "library/myapp" scope
     → cache as alice:library/myapp
  2. library/otherapp → request Bearer token for "library/otherapp" scope
     → cache as alice:library/otherapp (separate token)
  3. library/myapp again → reuse cached alice:library/myapp token

Prevents privilege escalation via token reuse across repos.
```

### Configuration

No configuration changes required. Existing `auth_mode` values work:

| auth_mode | Behavior | Change from v2.15 |
|-----------|----------|-------------------|
| `db` | Database auth only | No change |
| `ldap` | LDAP auth only | No change |
| `oidc` | OIDC + DB fallback | **New**: fallback added (was OIDC only) |
| `http_auth` | HTTP Auth Proxy | **Fix**: now functional (was broken) |
| `uaa` | UAA auth only | No change |

## Implementation (IN REVIEW)

### Components

**Core Authentication (`src/core/auth/`)**
- `authenticator.go` — `Match()` interface method; multi-backend dispatch; locked-user fix
- `authproxy/auth.go` — HTTP Auth Proxy `Match()` implementation
- `db/db.go`, `ldap/ldap.go`, `oidc/oidc.go`, `uaa/uaa.go` — Per-backend `Match()` implementations

**Registry Proxy (`src/server/registry/`)**
- `proxy.go` — Probe-based auth detection; credential passthrough; scope-keyed token cache
- `proxy_test.go` — 372 new lines of test coverage

**V2 Auth Middleware (`src/server/middleware/v2auth/`)**
- `auth.go` — Correct Bearer challenge for Basic-auth clients; graceful token service error handling

**Config & UI (`src/lib/config/`, `src/portal/`)**
- Removed unused `AUTH_MODE` UI strings from portal
- Removed context helpers `WithAuthMode` / `AuthModeFrom` from `src/lib/context.go`
- Updated i18n files to remove `AUTH_MODE` keys

### Test Coverage

**Unit Tests**
- Registry proxy auth probing (3 test cases)
- Token caching and expiry (2 test cases)
- Scope extraction from request paths (8 test cases)
- Basic auth exchange (1 test case)
- Bearer challenge generation (1 test case)

**Integration Tests**
- Registry push/pull with passthrough auth
- LDAP authentication flow
- OIDC + database fallback
- HTTP Auth Proxy endpoint validation

**Existing Tests**
- All existing auth tests continue to pass
- Backward compatibility verified

### Commits

PR organized into 16 commits across 3 logical units:

**Unit 1 — Security fixes (4 commits)**
- Locked user returns `ErrAuth` instead of nil
- Nil pointer dereference guards

**Unit 2 — Registry proxy (5 commits)**
- Probe-based auth detection
- User credential passthrough
- Token scope caching
- Test coverage

**Unit 3 — Core refactor (7 commits)**
- Per-backend `Match()` dispatch
- Remove global auth_mode switch
- Portal UI updates
- Config cleanup

## Backward Compatibility ✅

**Configuration**: No changes required. All existing `auth_mode` values continue to work.

**Database**: No migrations. Existing `auth_mode` configuration persisted as-is.

**API**: No changes to public authentication APIs.

**Behavior Changes** (all improvements):
- OIDC mode now has fallback to database (admin always accessible)
- HTTP Auth Proxy mode now functional (was broken)
- Registry proxy now respects per-user credentials (was security issue)
- Locked users now properly rejected (was security issue)

## Issues Resolved

| Issue | Title | Status |
|-------|-------|--------|
| #1572 | Harbor project lack of brute force mechanism | **FIXED** — locked users now return ErrAuth |
| #13372 | Combine multiple authentication modes | **ADDRESSES** — achieves multi-mode via fallback dispatch |
| #21300 | Passthrough Authentication in Proxy Cache | **IMPROVES** — user credentials now passed to token service |
| #7965 | Support local user creation in http_auth mode | **FIXES** — http_auth mode now fully functional |
| #7964 | Config option for token login in http_auth mode | **FIXES** — http_auth mode now fully functional |
| #21853 | OIDC and LDAP at the same time as auth mode | **ADDRESSES** — OIDC mode now falls through to DB |

## Non-Goals

- OAuth 2.0 as authentication mode (separate enhancement)
- Automatic auth backend selection (requires explicit configuration)
- Role-based auth backend routing (out of scope for this phase)
- User migration between auth backends (handled separately)
- Authentication performance optimization (orthogonal concern)

## Known Limitations

- **Token cache in-memory only**: Distributed Harbor deployments will re-exchange tokens on each instance. Distributed cache support is a future enhancement.
- **Per-scope tokens only**: Repository-level granularity not yet supported; future work to add per-action (pull/push) scoping.
- **No auto-fallback config**: Operators must set `auth_mode = "oidc"` to get fallback behavior; no automatic mode selection.
- **Token service errors**: Registry proxy gracefully degrades to Basic challenge on token service failure; tokens are not cached in this case.

## Potential Future Enhancements

- **Distributed token cache**: Redis or Memcached-backed token storage for multi-instance deployments
- **Per-action scoping**: Fine-grained Bearer token scopes (pull vs push vs delete)
- **Scheduled token cleanup**: Automatic removal of expired tokens from cache
- **Auth backend metrics**: Counters for authentication success/failure rates per backend
- **Audit logging**: Detailed logging of auth backend probe results and fallback decisions
- **Role-based routing**: Different auth backends for different user roles
- **OAuth 2.0 support**: Native OAuth 2.0 authentication mode alongside existing backends

## Testing Strategy

### Unit Testing
- `Match()` implementation per backend (all paths tested)
- Locked user error handling
- Probe-based detection logic
- Token scope extraction and caching
- Bearer challenge generation

### Integration Testing
- Multi-backend dispatch with actual auth backends
- Registry proxy with upstream probe
- Token exchange with token service
- Fallback behavior across all `auth_mode` values

### E2E Testing (Robot Framework)
- Docker login with each `auth_mode`
- Registry push/pull with proxy and passthrough auth
- OIDC provider unavailability + admin fallback
- Locked user rejected from all auth paths
- HTTP Auth Proxy external endpoint integration

### Regression Testing
- All existing auth tests continue to pass
- Existing `auth_mode` configurations work without changes
- Database schema compatible (no migrations)

## Migration Path

**Phase 1 (v2.x)** — This PR
- Implement probe-based dispatch and multi-backend `Match()`
- Registry proxy user credential passthrough
- Security fixes for locked users and nil authentication
- HTTP Auth Proxy support

**Phase 2 (v2.x+1)**
- Add distributed token cache option
- Implement per-action (pull/push) token scoping
- Auth backend metrics and audit logging

**Phase 3 (v3.x)**
- Consider removing legacy `auth_mode` config in favor of explicit backend configuration
- OAuth 2.0 authentication support

## References

- **PR**: https://github.com/goharbor/harbor/pull/23458
- **Code**: `src/core/auth/`, `src/server/registry/`, `src/server/middleware/v2auth/`
- **Related Issues**: #1572, #13372, #21300, #7965, #7964, #21853
- Related Implementations:
  - Docker Registry V2 auth probe
  - GitHub token scoping strategy
  - GitLab HTTP Auth support
  - Kubernetes bearer token handling
