# Proposal: Probe-Based Authentication Dispatch

Author: Harbor Community

Discussion: [goharbor/harbor#1572](https://github.com/goharbor/harbor/issues/1572), [goharbor/harbor#13372](https://github.com/goharbor/harbor/issues/13372), [goharbor/harbor#21300](https://github.com/goharbor/harbor/issues/21300), [goharbor/harbor#23458](https://github.com/goharbor/harbor/pull/23458)

## Abstract

Replace Harbor's single-backend `auth_mode` configuration with a flexible per-backend matching system. This fixes three critical production issues: admin lockout when OIDC provider is unavailable, security vulnerability where locked users authenticate as nil, and registry proxy bypassing per-user permissions. Enables fallback authentication chains while maintaining full backward compatibility.

## Background

Harbor currently uses a global `auth_mode` setting to select a single authentication backend:

```
auth_mode = "db"        # Database only
auth_mode = "ldap"      # LDAP only
auth_mode = "oidc"      # OIDC only
auth_mode = "http_auth" # HTTP Auth Proxy only
auth_mode = "uaa"       # UAA only
```

This design has caused multiple production issues:

### Issue 1: Admin Lockout in OIDC Mode
- OIDC provider becomes unavailable (misconfigured, IdP outage, network issue)
- No fallback to local database authentication
- Admin account becomes completely inaccessible
- Recovery requires Harbor restart and manual config editing

### Issue 2: Security Bug — Locked Users Authenticate as nil
- User account locked due to repeated login failures
- `Login()` returns `(nil, nil)` instead of error
- HTTP handlers treat nil as successful login with no user
- Locked accounts silently authenticate and bypass authorization checks

### Issue 3: Registry Proxy Ignores User Credentials
- Registry proxy always forwards shared service-account credential to upstream
- Per-user permissions completely bypassed
- Read-only user can push images (proxied as service account)
- No way to enforce repository-level access control

### Issue 4: HTTP Auth Proxy Mode Silently Broken
- `http_auth` mode missing from authentication dispatch entirely
- All authentication falls through to database only
- HTTP Auth Proxy configuration non-functional

## Proposal

### Core Solution

Replace single-backend dispatch with per-backend `Match()` method. Each backend reports whether it's configured and should be tried. The dispatcher tries backends in priority order; first success wins.

**Per-backend Match() interface:**
```
Match(ctx) → (bool, error)
  - (true, nil) = backend configured, should be tried
  - (false, nil) = backend not configured, skip
  - (false, err) = backend misconfigured, fatal error
```

### Authentication Dispatch Flows

**OIDC Mode** (with fallback):
```
1. Try OIDC
   ✓ Success → return user
   ✗ Fail → continue
2. Try Database (fallback)
   ✓ Success → return user (admin always accessible)
   ✗ Fail → reject login
```

**LDAP Mode** (no fallback):
```
1. Try LDAP
   ✓ Success → return user
   ✗ Fail → reject (clear error)
```

**HTTP Auth Proxy Mode** (new support):
```
1. Try HTTP Auth Proxy
   ✓ Success → create/update local user, return
   ✗ Fail → reject (clear error)
```

**Database Mode** (unchanged):
```
1. Try Database only
   ✓ Success → return user
   ✗ Fail → reject
```

### Security Fixes

**Locked User Fix:**
- `Login()` now returns `ErrAuth` for locked users instead of `(nil, nil)`
- Locked accounts properly rejected from all auth paths
- HTTP handlers can distinguish between auth failure and unauthenticated access

**Registry Proxy User Credential Passthrough:**
- Probe upstream registry to detect auth method (Bearer or Basic)
- Exchange user credentials for scoped Bearer token via token service
- Cache tokens per-repository scope (not globally; prevents privilege escalation)
- Fall back to probed credentials for unauthenticated requests
- Handle token service failures gracefully

### Registry Proxy Auth Probe

```
GET /v2/ with no credentials
  ↓
If 401 + Bearer realm header:
  → Use token service exchange for Bearer tokens
If 401 + Basic realm header:
  → Use Basic auth passthrough
If 200 (no auth required):
  → Allow anonymous access
```

## Non-Goals

- OAuth 2.0 as authentication mode (separate enhancement)
- Automatic auth backend selection (requires explicit configuration)
- Role-based auth backend routing (out of scope)
- User migration between auth backends (handled separately)
- Authentication performance optimization (orthogonal)

## Rationale

**Why per-backend Match()?** Allows each backend to report readiness independently, enabling smart fallback without complex conditional logic.

**Why OIDC + DB fallback?** Admin access is critical. If OIDC provider fails, ops need a way back in without restarting Harbor.

**Why probe-based registry auth?** Different registries use different auth methods. Probing detects the method automatically; no manual configuration needed.

**Why per-scope token caching?** Prevents privilege escalation. A token scoped to `repo1` cannot be reused for `repo2`.

**Why fix locked-user bug?** Nil authentication creates security gap. Locked accounts should be locked, not silently pass through.

## Compatibility

**No configuration changes required.** All existing `auth_mode` values work:

| auth_mode | Behavior | Change |
|-----------|----------|--------|
| `db` | Database auth only | No change |
| `ldap` | LDAP auth only | No change |
| `oidc` | OIDC + DB fallback | **New**: fallback added (was OIDC-only) |
| `http_auth` | HTTP Auth Proxy | **Fix**: now functional (was broken) |
| `uaa` | UAA auth only | No change |

**Backward Compatibility:**
- No database migrations required
- No API changes
- Existing authentication methods continue working
- Existing robot accounts continue working
- Configuration files need no updates

## Implementation

### Code Changes

**Core Authentication** (`src/core/auth/`):
- `authenticator.go` — New `Match()` interface; multi-backend dispatch; locked-user security fix
- `authproxy/auth.go`, `db/db.go`, `ldap/ldap.go`, `oidc/oidc.go`, `uaa/uaa.go` — Per-backend `Match()` implementations

**Registry Proxy** (`src/server/registry/`):
- `proxy.go` — Probe-based auth detection; credential passthrough; per-scope token caching
- `proxy_test.go` — 372 lines of test coverage

**V2 Auth Middleware** (`src/server/middleware/v2auth/`):
- `auth.go` — Correct Bearer challenge for Basic-auth clients; graceful token service error handling

**Config & UI** (`src/lib/config/`, `src/portal/`):
- Remove unused `AUTH_MODE` UI strings
- Remove context helpers `WithAuthMode` / `AuthModeFrom`
- Update i18n files

### Testing

**Unit Tests:**
- Registry proxy auth probing (3 cases)
- Token caching and expiry (2 cases)
- Scope extraction from request paths (8 cases)
- Basic auth exchange (1 case)
- Bearer challenge generation (1 case)

**Integration Tests:**
- Multi-backend dispatch with actual backends
- Registry proxy with upstream probe
- Token exchange with token service
- Fallback behavior across all `auth_mode` values

**E2E Tests:**
- Docker login with each `auth_mode`
- Registry push/pull with proxy and passthrough auth
- OIDC provider unavailability + admin fallback
- Locked user rejected from all paths
- HTTP Auth Proxy external endpoint integration

### Commits

PR organized into 16 commits across 3 logical units:

**Unit 1 — Security fixes** (4 commits)
- Locked user returns `ErrAuth` instead of nil
- Nil pointer dereference guards

**Unit 2 — Registry proxy** (5 commits)
- Probe-based auth detection
- User credential passthrough
- Per-scope token caching
- Test coverage

**Unit 3 — Core refactor** (7 commits)
- Per-backend `Match()` dispatch
- Remove global auth_mode switch
- Portal UI updates
- Config cleanup

## Known Limitations

- **Token cache in-memory only**: Distributed deployments re-exchange tokens per instance; future: distributed cache support
- **Per-scope tokens only**: Repository-level granularity not yet supported; future work for per-action (pull/push/delete) scoping
- **No auto-fallback config**: Operators must explicitly set `auth_mode = "oidc"` for fallback; no automatic selection
- **Token service errors**: Registry proxy degrades to Basic challenge on token service failure; tokens not cached

## Potential Future Enhancements

- Distributed token cache (Redis/Memcached) for multi-instance Harbor
- Per-action token scoping (pull vs push vs delete)
- Scheduled token cleanup from cache
- Auth backend success/failure metrics
- Detailed audit logging of auth backend decisions
- Role-based auth backend routing
- OAuth 2.0 support as native authentication mode

## Issues Resolved

| Issue | Title | Resolution |
|-------|-------|-----------|
| #1572 | Lack of brute force / account locking mechanism | **FIXED** — locked users now return ErrAuth |
| #13372 | Combine multiple authentication modes | **ADDRESSES** — multi-mode support via fallback dispatch |
| #21300 | Passthrough Authentication in Proxy Cache | **IMPROVES** — user credentials now passed to token service |
| #7965 | Support local user creation in http_auth mode | **FIXES** — http_auth mode now fully functional |
| #7964 | Config option for token login in http_auth mode | **FIXES** — http_auth mode now fully functional |
| #21853 | OIDC and LDAP at the same time as auth mode | **ADDRESSES** — OIDC + DB fallback achieves some co-existence |

## References

- **Implementation**: [goharbor/harbor#23458](https://github.com/goharbor/harbor/pull/23458)
- **Related Issues**: #1572, #13372, #21300, #7965, #7964, #21853
- **Code locations**: `src/core/auth/`, `src/server/registry/`, `src/server/middleware/v2auth/`
- **Related work**: Docker Registry V2 auth probe, Kubernetes bearer token handling, GitHub OAuth fallback chains
