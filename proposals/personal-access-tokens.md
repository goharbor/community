# Proposal: Personal Access Tokens (PAT)

Author: Ross Golder

Discussion: [goharbor/harbor#23370](https://github.com/goharbor/harbor/pull/23370)

## Abstract

Introduce Personal Access Tokens (PAT) as a modern, self-service authentication mechanism for Harbor. PATs provide named, time-limited credentials with audit trails, replacing the legacy OIDC CLI secret system. Tokens are scoped to projects and authenticate via HTTP Basic Auth (username + token).

## Background

Harbor's authentication for programmatic access currently relies on:

1. **User credentials** (username/password) - work everywhere but difficult to rotate
2. **Legacy CLI tokens** - created by admins, no expiration, no usage tracking
3. **Robot accounts** - project-level scope but admin-managed only

Users need a self-service way to create, rotate, and revoke authentication credentials without admin intervention. Credentials should be:
- **Revocable** without changing passwords
- **Time-limited** to reduce blast radius of leaks
- **Auditable** to track usage and enable cleanup of stale tokens
- **Scoped** to limit permissions per credential

## Proposal

### Core Features

**1. PAT Lifecycle Management**
- Users create, list, update, and delete their own PATs via API (`/api/v2.0/users/{user_id}/personal_access_tokens`)
- PAT properties: name, description, expiration (days or -1 for never), creation/update timestamps
- `last_used_at` timestamp tracks most recent authentication
- `disabled` flag allows revocation without deletion
- Automatic migration of legacy OIDC CLI secrets with `is_legacy` flag

**2. Token Format & Security**
- Format: `hbr_pat_` prefix + 32-character random secret
- Secrets hashed using PBKDF2-SHA256 with per-token salt
- Secrets never stored in plaintext; returned only on creation
- Disabled and expired tokens are rejected during authentication

**3. Authentication**
- PATs authenticate via HTTP Basic Auth (username + PAT secret)
- Works for Docker login and push/pull operations
- Works for API endpoint access
- Security middleware checks `hbr_pat_` prefix in credentials

**4. Authorization & Scope**
- PATs support project-level scope enforcement via JSON scope field
- Scope validated through existing Harbor authorization layer (RAM)
- Token access restricted to permitted projects only

**5. Audit Trail**
- All PAT operations logged: create, read, update, delete, usage
- `last_used_at` provides audit trail of token usage
- Compatible with Harbor's audit log system

### Database Schema

```sql
CREATE TABLE personal_access_token (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES harbor_user(user_id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    secret VARCHAR(7168) NOT NULL,  -- PBKDF2-SHA256 hash with salt
    salt VARCHAR(255) NOT NULL,
    expires_at BIGINT DEFAULT -1,   -- Unix timestamp, -1 = never expire
    creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at BIGINT,
    disabled BOOLEAN DEFAULT false,
    is_legacy BOOLEAN DEFAULT false,
    scope JSONB,
    UNIQUE(user_id, name)
);

CREATE INDEX idx_pat_user_id ON personal_access_token(user_id);
CREATE INDEX idx_pat_disabled ON personal_access_token(disabled);
CREATE INDEX idx_pat_expires_at ON personal_access_token(expires_at);
```

## Non-Goals

- OIDC/LDAP provider-specific integration (handled via separate auth systems)
- PAT login to Harbor UI (tokens are API-only; UI uses session auth)
- Hierarchical scopes beyond project level (future enhancement)
- Automatic expiration notifications (operational responsibility)
- Built-in rate limiting per PAT (use reverse proxy)
- Automatic token rotation (users manage via refresh endpoint)

## Rationale

**Why self-service?** Unlike legacy CLI tokens (admin-created), PATs empower developers to manage their own authentication without operational overhead.

**Why time-limited?** Expiring credentials reduce blast radius if a token is leaked. Default never-expire (-1) preserves backward compatibility while enabling policies.

**Why track last_used_at?** Enables security teams to audit token usage, identify stale tokens for cleanup, and detect unusual access patterns.

**Why per-token salt in hashing?** Each token is hashed independently, preventing credential reuse if the database is compromised.

**Alternate approaches considered:**
- OAuth 2.0 token endpoint - more complex; PAT approach simpler for Harbor-only use
- Per-project token limits - can be enforced via policy; not needed in core
- Automatic token rotation - manual refresh provides operator control

## Compatibility

**Backward compatible:**
- Existing user credentials (username/password) continue to work
- Existing robot accounts continue to work
- Existing OIDC CLI secrets migrated to legacy PATs on startup
- No configuration changes required
- Additive API endpoints only; no breaking changes

**Authentication middleware dispatch order** (ensures compatibility):
1. Secret/JWT handler (Harbor internal)
2. PAT handler (checks for `hbr_pat_` prefix)
3. Robot handler (checks for `robot$` prefix)
4. Basic Auth handler (username/password)
5. Session handler (cookie-based)
6. Unauthorized fallback

## Implementation

### Components

- **Data Model**: `/src/common/models/personal_access_token.go`, `/src/server/v2.0/models/`
- **Database Layer**: `/src/pkg/pat/dao/` (CRUD operations), `/src/pkg/pat/model/` (hashing/validation)
- **Service Layer**: `/src/core/service/token/token.go` (core token service)
- **API Handlers**: `/src/server/v2.0/handlers/userdata.go` (REST endpoints)
- **Security Middleware**: `/src/server/middleware/security/pat.go` (PAT authentication)
- **Controller**: `/src/controller/pat/` (business logic)
- **UI**: Harbor portal account settings - PAT management tab with create/list/delete/enable/disable/refresh operations

### Testing

- **Unit tests**: Token service, authentication middleware, DAO layer
- **Integration tests**: API endpoints, database persistence, user lookup, middleware chain
- **E2E tests**: Docker login with PAT, expired/disabled token rejection, scope enforcement

### Test Coverage

All passing:
- ✅ Token creation with various expiration configurations
- ✅ Secret hashing/verification with salt
- ✅ Expiration validation (expired tokens rejected)
- ✅ Disabled tokens rejected during authentication
- ✅ Scope parsing and enforcement
- ✅ Docker login authentication
- ✅ API CRUD operations
- ✅ Non-admin user self-service
- ✅ Last-used timestamp tracking
- ✅ Error handling for invalid inputs

### Release Notes

**Release**: v2.16.0+

**User-Facing**:
- Users can create/manage personal access tokens via API
- Tokens support configurable expiration
- Tokens can be disabled/enabled without deletion
- Tokens track creation, update, last-used timestamps
- Legacy OIDC CLI secrets auto-flagged as `is_legacy`
- Docker login now supports PAT credentials

**Operator**:
- New database table: `personal_access_token`
- Database migrations auto-apply on startup
- No configuration changes required
- Existing authentication methods continue working

**Breaking Changes**: None - fully backward compatible

## Known Limitations

- **Project-Level Scope**: Per-repository or per-action granularity (pull vs push) requires future schema expansion
- **No Secret Retrieval**: Secrets cannot be retrieved after creation; users must refresh if lost
- **No Expiration Notifications**: Expired tokens silently rejected; no automatic warnings
- **In-Memory Migration**: Legacy CLI tokens auto-migrated on first UI load; no background rotation

## Potential Future Enhancements

- Token expiration warning notifications
- Finer-grained scopes (per-repository, per-action)
- Rate limiting configuration per PAT
- Default expiration policies (system-wide or role-based)
- Automatic token rotation strategies
- Token usage analytics dashboard
- Revocation callbacks for CI/CD integration
- OAuth 2.0 token endpoint support

## References

- **Implementation**: [goharbor/harbor#23370](https://github.com/goharbor/harbor/pull/23370)
- **Code locations**: `src/core/service/token/`, `src/pkg/pat/`, `src/server/middleware/security/pat.go`
- **Related implementations**: Docker Registry V2 token auth, GitHub/GitLab PAT, Harbor Robot Accounts
