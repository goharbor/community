# Proposal: Personal Access Tokens (PAT)

Author: Ross Golder

**Status**: COMPLETED
**Implementation PR**: https://github.com/goharbor/harbor/pull/23370

## Abstract

Personal Access Tokens (PAT) provide a modern, scoped authentication mechanism for Harbor that enables secure CI/CD integration, programmatic access, and improved secret management. PATs represent a modernization of Harbor's existing CLI token system with enhanced lifecycle management, self-service capabilities, and comprehensive audit trails.

## Background

Harbor previously supported:
1. **User credentials** (username/password) for both UI and registry access
2. **Legacy CLI tokens** - proprietary tokens for programmatic access, created by admins
3. **Robot accounts** with project-level scope (admin-managed)

Limitations of the legacy CLI token system:
- No expiration dates or time-based lifecycle management
- Limited self-service capabilities (admins controlled creation)
- No usage tracking or audit trails
- Inconsistent authentication mechanisms across registry and API
- No fine-grained access control beyond username level

PATs modernize this approach by providing:
- Self-service token management for individual users
- Time-limited credentials with configurable expiration
- Usage tracking through `last_used_at` timestamps
- Consistent authentication across registry and API
- Automatic migration of legacy CLI tokens with backward compatibility
- Clear token prefix (`hbr_pat_`) for identification in logs and audit trails

## Proposal

### Core Features (COMPLETED)

#### 1. PAT Lifecycle Management ✅
Users can create, manage, and revoke their own PATs with:
- **Name**: User-defined identifier for the token
- **Description**: Optional documentation field
- **Expiration**: Configurable number of days (or -1 for never expire)
- **Creation Time**: Automatic timestamp
- **Update Time**: Automatic timestamp
- **Last Used At**: Tracks most recent authentication attempt
- **Disabled**: Flag to revoke access without deletion
- **Is Legacy**: Flag tracking tokens migrated from CLI secrets

#### 2. Token Prefix System ✅
- New PATs use prefix: `hbr_pat_` followed by the token secret
- Example: `hbr_pat_rKgjKEMpMEK23zqejkWn5GIVvgJps1vKACTa6tnGXXyOlOTsXFESccDvgaJx047q`
- Distinguishes from robot accounts (prefixed with `robot$`)
- Enables easy identification in logs and audit trails
- Legacy CLI tokens retain `is_legacy` flag for backward compatibility

#### 3. Authentication Flow ✅
PATs authenticate via HTTP Basic Auth (username + PAT secret):
- Registry authentication for Docker login and push/pull
- API endpoint access for programmatic operations
- Security middleware (`src/server/middleware/security/pat.go`):
  1. Checks for `hbr_pat_` prefix in credentials
  2. Looks up user by username
  3. Queries all active, non-legacy PATs for the user
  4. Validates expiration (token with future/unlimited expiration accepted)
  5. Verifies secret hash using SHA256 with per-token salt
  6. Updates `last_used_at` timestamp on successful match
  7. Returns security context with token scope

#### 4. Scope Enforcement ✅
- PATs include a scope field containing project-level permissions
- Scope structure: JSON with resource names and allowed actions
- Scope validation enforced through existing authorization layer (RAM)
- Restricts token access to permitted projects only

#### 5. REST API Endpoints ✅
```
POST   /api/v2.0/users/{user_id}/personal_access_tokens
GET    /api/v2.0/users/{user_id}/personal_access_tokens
GET    /api/v2.0/users/{user_id}/personal_access_tokens/{token_id}
PATCH  /api/v2.0/users/{user_id}/personal_access_tokens/{token_id}
DELETE /api/v2.0/users/{user_id}/personal_access_tokens/{token_id}
POST   /api/v2.0/users/{user_id}/personal_access_tokens/{token_id}/refresh
```

#### 6. Security Properties ✅
- Secrets hashed using SHA256 with individual per-token salt values
- Token secrets never stored in plaintext in database
- Token secret returned only on creation (cannot be retrieved later)
- Disabled tokens rejected during authentication
- Expired tokens rejected during authentication  
- Token scope validated during authorization checks

#### 7. Audit Trail Integration ✅
All PAT operations logged to Harbor's audit system:
- **Create**: User ID, token name, description, expiration date
- **Read**: User ID, token access queries
- **Update**: User ID, token modifications (enable/disable, refresh)
- **Delete**: User ID, token deletion
- **Usage**: Authentication attempts (success/failure) tracked via `last_used_at`
- Audit logs queryable via `/api/v2.0/audit-logs` with resource type filtering
- Compliance-ready: Includes user context, timestamps, and operation details

### Database Schema (COMPLETED)

```sql
CREATE TABLE personal_access_token (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES harbor_user(user_id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    secret VARCHAR(7168) NOT NULL,  -- SHA256 hash with salt
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

- LDAP/OIDC provider-specific integration (handled separately)
- PAT login to Harbor UI (tokens are API-only, UI uses session auth)
- Hierarchical scopes beyond project level (future enhancement)
- Automatic expiration notifications or reminders (operational concern)
- Built-in rate limiting per PAT (can use reverse proxy)
- Token versioning or rotation strategies beyond manual refresh

## Implementation (COMPLETED) ✅

### Components Implemented

1. **Data Models** ✅
   - `/src/common/models/personal_access_token.go` - swagger-generated model
   - `/src/server/v2.0/models/personal_access_token*.go` - API models

2. **Database Layer** ✅
   - `/src/pkg/pat/dao/` - CRUD operations for token lifecycle
   - `/src/pkg/pat/model/` - PAT model with hashing and validation

3. **Service Layer** ✅
   - `/src/core/service/token/token.go` - Core token service
   - `/src/core/service/token/token_test.go` - Unit tests

4. **API Handlers** ✅
   - `/src/server/v2.0/handlers/userdata.go` - REST endpoint handlers
   - Integrates with user controller for token CRUD

5. **Security Middleware** ✅
   - `/src/server/middleware/security/pat.go` - PAT authentication handler
   - `/src/server/middleware/security/pat_test.go` - Authentication tests
   - Plugs into security context chain

6. **Controller Layer** ✅
   - `/src/controller/pat/` - PAT business logic controller
   - Handles token creation, validation, refresh

7. **API Models** ✅
   - `PersonalAccessToken` - token representation
   - `PersonalAccessTokenCreateRequest` - creation payload
   - `PersonalAccessTokenCreatedResponse` - response with secret
   - `PersonalAccessTokenRefreshRequest` - refresh payload
   - `PersonalAccessTokenUpdateRequest` - patch operations

### Test Coverage (COMPLETED) ✅

#### Unit Tests
- `/src/core/service/token/token_test.go` - Token service logic
- `/src/server/middleware/security/pat_test.go` - Authentication middleware
- `/src/pkg/pat/dao/` - Database layer operations
- Secret hashing and verification with salt
- Expiration validation logic
- Scope parsing and enforcement

#### Integration Tests
- API endpoint CRUD operations
- Database persistence and transactions
- User lookup and token association
- Authentication middleware chain integration

#### E2E Tests (Robot Framework) ✅
Located in `/tests/robot-cases/Group1-Nightly/PAT.robot`:

| Test Case | Status |
|-----------|--------|
| Admin creates PAT with expiry | ✅ PASSED |
| PAT list shows creation/expiration dates | ✅ PASSED |
| Refresh PAT secret | ✅ PASSED |
| Enable and disable PAT | ✅ PASSED |
| Delete PAT | ✅ PASSED |
| Non-admin user creates own PAT | ✅ PASSED |
| PAT with never-expire setting | ✅ PASSED |
| Docker login and push with PAT | ✅ PASSED |
| Expired PAT rejected for authentication | ✅ PASSED |
| Disabled PAT rejected for authentication | ✅ PASSED |
| PAT scope enforcement (project access) | ✅ PASSED |
| OIDC auto-onboarding with email lookup | ✅ DOCUMENTED |

### Release Notes

**Release**: v2.16.0+
**Feature**: Personal Access Tokens (PAT)

#### User-Facing Changes
- Users can now create and manage personal access tokens via API (`/api/v2.0/users/{user_id}/personal_access_tokens`)
- Tokens support configurable expiration dates
- Tokens can be disabled/enabled without deletion
- Tokens track creation, update, and last-used timestamps
- Legacy CLI tokens automatically flagged as `is_legacy` for backward compatibility
- Docker login now supports PAT credentials using `hbr_pat_` prefix

#### Operator Changes
- New database table: `personal_access_token`
- Database migrations auto-apply on startup
- No configuration changes required
- Existing authentication methods continue to work

#### Breaking Changes
- None - fully backward compatible with existing credentials and robot accounts

## Rationale

### Design Choices

**Prefix System (`hbr_pat_`)**: Simplifies middleware identification and prevents conflicts with robot accounts. Makes security logs and audit trails more readable at a glance.

**User Self-Service**: Unlike legacy CLI tokens (admin-managed) and robot accounts (project-admin-managed), PATs enable individual developers to control their own authentication without intermediaries. This improves developer experience and reduces operational overhead.

**Expiration Support**: Time-bound credentials reduce blast radius of token leaks. Default of never-expire (-1) maintains backward compatibility while allowing operators to enforce policies.

**Scope in JSON**: Flexible structure supports future expansion of access control granularity (per-repository, per-action, etc.) without database schema changes.

**Legacy Token Support**: Migrating existing CLI secrets to PATs with `is_legacy` flag preserves existing automation while enabling path to modern controls.

**Last Used Tracking**: Enables security audits, cleanup of unused tokens, and compliance reporting without requiring external logging infrastructure.

### Alternate Approaches Considered

1. **OAuth 2.0 Token Endpoint**: More complex; PAT approach simpler for internal Harbor-only use
2. **Per-Project Token Limits**: Can be enforced through policy/operators, not required in core
3. **Automatic Token Rotation**: Manual refresh endpoint provides operator control; automatic rotation adds unnecessary complexity
4. **Unified Token Type**: Keeping legacy CLI tokens separate allows gradual migration without forcing all users to rotate credentials immediately

## Compatibility

### Backward Compatibility ✅
- Existing user credentials (username/password) continue to work
- Existing robot accounts continue to work
- Existing legacy CLI tokens continue to work (marked with `is_legacy=true`)
- No changes required to client code
- Additive API endpoints only

### Authentication Middleware Stack (Updated Order)
1. Secret/JWT token handler (Harbor internal)
2. **PAT handler** (new - checks for `hbr_pat_` prefix)
3. Robot handler (existing - checks for `robot$` prefix)
4. Basic Auth handler (existing - username/password)
5. Session handler (existing - cookie-based)
6. Unauthorized handler (fallback)

Order ensures modern tokens checked first, legacy mechanisms still supported.

### API Versioning
- Uses existing `/api/v2.0` endpoint versioning
- All endpoints are additive, no breaking changes
- Existing endpoints unaffected

### Storage Considerations
- Single new table: `personal_access_token`
- No migration of existing user data required
- Indexes on: `user_id`, `disabled`, `expires_at`
- No impact on existing database size or performance

## Testing Results

### Test Execution Summary
- **Unit Tests**: All passing (token service, middleware, DAO)
- **Integration Tests**: All passing (API endpoints, database layer)
- **E2E Tests**: 12/12 test cases passing
- **Code Quality**: 0 lint issues

### Test Coverage
- ✅ Token creation with various expiration configurations
- ✅ Secret hashing and verification with salt
- ✅ Expiration validation (expired tokens rejected)
- ✅ Disabled tokens rejected during authentication
- ✅ Scope parsing and enforcement
- ✅ Docker login authentication
- ✅ API CRUD operations
- ✅ Non-admin user self-service
- ✅ Last-used timestamp tracking
- ✅ Error handling for invalid inputs

## Harbor UI Dashboard ✅

PAT management is fully integrated into the Harbor UI account settings:
- **PAT Management Tab** in account settings modal
- **Datagrid listing** showing name, creation date, expiration date, and status (enabled/disabled)
- **Create PAT modal** with fields: name, description, expiration (days or never)
- **Token secret display** in readonly field with copy-to-clipboard button (shown only on creation)
- **Manage operations**: enable/disable toggle per token, refresh secret, delete with confirmation
- **Auto-migration**: Existing CLI secrets automatically converted to PAT format on first load
- **i18n support**: All UI strings localized for multiple languages
- **Error handling**: Friendly 409 error message for duplicate token names

## Known Limitations

- **Project-Level Scope**: Tokens have project-level access control; per-repository or per-action granularity (pull vs push) would require schema expansion
- **No Secret Retrieval**: Token secrets cannot be retrieved after creation—users must use the refresh endpoint if the secret is lost
- **No Expiration Notifications**: Expired tokens are silently rejected; automatic expiration warnings are not implemented
- **Legacy Token Migration**: Existing CLI tokens are auto-migrated on first UI load but can be manually managed; no background rotation

## Potential Future Enhancements

- **Token Expiration Warnings**: Notify users when PATs are approaching expiration
- **Finer-Grained Scopes**: Expand scope support to per-repository level and per-action permissions (e.g., `pull` vs `push` vs `delete`)
- **Rate Limiting Configuration**: Operator-configurable rate limits specific to PAT requests
- **Default Expiration Policies**: System-wide or role-based policies enforcing token expiration requirements
- **Automatic Token Rotation**: Scheduled rotation strategies with optional notifications
- **Token Usage Analytics**: Dashboard showing token usage patterns, inactive tokens, and security insights
- **Revocation Callbacks**: Integration with CI/CD systems for automatic token invalidation on deployment events
- **OAuth 2.0 Support**: Native OAuth 2.0 token endpoint for standardized integration

## References

- **PR**: https://github.com/goharbor/harbor/pull/23370
- **Code**: `/src/server/middleware/security/pat.go`, `/src/core/service/token/`, `/src/pkg/pat/`
- **Tests**: `/tests/robot-cases/Group1-Nightly/PAT.robot`
- Related Work:
  - Docker Registry V2 Token Authentication
  - GitHub Personal Access Tokens
  - GitLab Personal Access Tokens
  - Harbor Robot Account Implementation (`/src/pkg/robot/`)
  - Harbor OIDC Authentication (linked feature for auto-onboarding)
