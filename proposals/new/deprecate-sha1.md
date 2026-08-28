# Proposal: Deprecate and Remove the Legacy SHA-1 Password Verification Path

Author: Yan Wang (yan-yw.wang@broadcom.com)

## Abstract

Harbor still carries a legacy local-database password verification path based
on PBKDF2-HMAC-**SHA1**. It exists only to authenticate user accounts whose
password hashes were created before the SHA-256 migration in Harbor 1.9.1.

This proposal describes a phased plan to **transparently migrate legacy SHA-1
credentials to the modern PBKDF2-HMAC-SHA256 scheme on successful login
(upgrade-on-login)**, followed by a clearly announced deprecation window, and
eventually the **removal of the SHA-1 verification code** in a future major
release.

## Background

Local-database password verification lives in
`src/common/utils/encrypt.go` and `src/pkg/user/manager.go`.

Current behavior:

- Each user row stores a `password`, `salt`, and `password_version`.
- `password_version` may be one of:
    - `sha1` — legacy PBKDF2-HMAC-SHA1, iteration count `4096`
    - `sha256` — legacy PBKDF2-HMAC-SHA256, iteration count `4096`
    - `pbkdf2_sha256` — current scheme, PBKDF2-HMAC-SHA256, iteration count `600000`
- The `sha1` value was assigned to all users created before Harbor 1.9.1
  by migration `make/migrations/postgresql/0011_1.9.1_schema.up.sql`.
  The column default is now `sha256` / `pbkdf2_sha256`.
- Verification in `MatchLocalPassword` is **version-aware**: it re-hashes
  the supplied password using the stored `password_version` and compares.
- A legacy hash is only upgraded to `pbkdf2_sha256` on an **explicit
  password change or admin reset** (`UpdatePassword` → `injectPasswd`).
  There is **no upgrade-on-login** today, so legacy `sha1` hashes persist
  indefinitely until the credential is changed.

### Why this matters

- SHA-1 is a deprecated hash primitive. Even though it is used here inside
  PBKDF2 (not as a bare hash), continuing to ship a `crypto/sha1` import in
  the auth path triggers security scanners (e.g. gosec G401/G505) and
  raises questions in downstream/regulated distributions.
- The legacy path also uses a very low PBKDF2 iteration count (`4096`),
  which is far below current OWASP guidance (`600000`). Users who have
  never changed their password since the migration are still protected by
  this weak work factor.
- Removing the path outright would **permanently lock out** any legacy OSS
  user who has not changed their password since the 1.9.1 migration, with
  no offline remediation possible (plaintext is not available). So removal
  must be gated behind a safe migration mechanism and a deprecation window.

## Goals

- Provide a safe, transparent migration path off SHA-1 (and the legacy
  low-iteration SHA-256) for existing users.
- Strengthen the work factor for migrated credentials to the current
  `pbkdf2_sha256` scheme.
- Allow the SHA-1 verification code to be removed in a future major
  release without breaking legacy users who actively log in.
- Give operators visibility into how many legacy credentials remain.

## Non-Goals

- Forcing password resets for all users.
- Breaking authentication for users during the deprecation window.
- Changing external auth backends (LDAP, OIDC, etc.); this only concerns
  local DB authentication.

## User stories

- As a legacy user whose password hash is still `sha1`, I can log in as
  usual and have my credential transparently upgraded to the modern scheme
  with no action required on my part.
- As a system admin, I can see how many local users still have a legacy
  `password_version` so I can gauge readiness for removal.
- As a system admin, I am notified through release notes and documentation
  that the SHA-1 path is deprecated and when it will be removed.
- As a legacy user who never logged in during the deprecation window, I can
  regain access via admin reset / forgot-password after removal.

## Proposal

### Phase 1 — Upgrade-on-login (transparent rehash)

When a user authenticates successfully via `MatchLocalPassword` and the
stored `password_version` is a legacy scheme (`sha1` or `sha256`, or any
version below `pbkdf2_sha256`), Harbor re-hashes the just-verified
plaintext password with the current scheme and persists it.

Because the plaintext is available at exactly that moment (the user just
typed it), this is safe and requires no user action.


### Phase 2 — Visibility & deprecation announcement

- Add an internal metric/log (and optionally an admin-facing count) of how
  many local users still have a legacy `password_version`. This lets
  operators gauge readiness for removal.
- Publish a deprecation notice in the release notes and documentation:
  the SHA-1 verification path is deprecated and will be removed in a future
  major release. Users with legacy hashes who never log in during the
  window must reset their password (admin reset) before upgrading to the
  removal release.

### Phase 3 — Removal (future major release)

In a future major release (e.g. the next Harbor major / "2.0"-style
lifecycle boundary), after the deprecation window:

- Remove the `crypto/sha1` import and the `sha1` entry from `HashAlg`.
- Treat any remaining `password_version == "sha1"` record as
  non-authenticatable; affected users must use admin reset / forgot-password
  to regain access.
- Optionally also retire the legacy low-iteration `sha256` path the same
  way, since upgrade-on-login covers it as well.

## Compatibility

- Phase 1 is fully backward compatible and can ship in a minor release.
- The deprecation window length should be defined by the community
  (suggestion: at least one full minor-release line, e.g. spanning two
  minor releases, before removal).
- Removal is a **breaking change** and must land only on a major-version
  boundary with explicit release-note callouts.

## Implementation

The change is concentrated in the local-DB authentication path.

Sketch (conceptual, not final code):

```go
func (m *manager) MatchLocalPassword(ctx context.Context, usernameOrEmail, password string) (*commonmodels.User, error) {
    l, err := m.dao.List(ctx, q.New(q.KeyWords{"username_or_email": usernameOrEmail}))
    if err != nil {
        return nil, err
    }
    for _, entry := range l {
        if utils.Encrypt(password, entry.Salt, entry.PasswordVersion) == entry.Password {
            // Transparent upgrade-on-login for legacy schemes.
            if entry.PasswordVersion != utils.PBKDF2SHA256 {
                if err := m.UpdatePassword(ctx, entry.UserID, password); err != nil {
                    log.G(ctx).Warningf("failed to upgrade password hash for user %d: %v", entry.UserID, err)
                }
            }
            entry.Password = ""
            return entry, nil
        }
    }
    return nil, nil
}
```

Key properties:

- The rehash is **best-effort**: if persisting the upgraded hash fails, the
  login still succeeds. We simply retry on the next login.
- No behavior change for users; no new configuration required.
- Over time, the population of `sha1`/legacy `sha256` credentials drains to
  only those accounts that never log in.

### Security considerations

- Upgrade-on-login improves security by moving legacy credentials from
  PBKDF2-SHA1 / low-iteration SHA-256 to PBKDF2-HMAC-SHA256 at `600000`
  iterations.
- No plaintext is stored or logged; the rehash reuses the password already
  supplied for verification.
- The change reduces the long-term attack surface and eventually removes a
  flagged weak primitive from the codebase.

## Open questions

- Should Phase 1 also expose the legacy-credential count via an admin API
  or just logs/metrics?
- What deprecation window does the community want before removal?
- Which major release should be the removal target?

