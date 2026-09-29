# Proposal: Custom Project Roles
Author: Max Graustenzel (@maxgraustenzel-create)
Discussion: #18124

## Abstract

Add support for custom project roles in Harbor, allowing system administrators to create roles with flexible permission combinations beyond the five built-in roles. This extends the existing RBAC system to enable runtime role creation without code changes, addressing long-standing community requests for role customization while maintaining full backward compatibility.

## Background

Harbor currently provides five hardcoded project roles (Project Admin, Maintainer, Developer, Guest, Limited Guest) with fixed permissions defined in `rbac_role.go`. Organizations have diverse security and workflow requirements that cannot be met by these predefined roles alone.

**Current Limitations:**
- Role permissions are hardcoded in Go source code
- Adding new roles requires code changes and Harbor releases
- Organizations cannot adapt roles to specific workflows (e.g., "DevOps Engineer" with artifact management + robot creation but no member management)
- No middle-ground between overly permissive and overly restrictive built-in roles

**Community Demand:**
- Issue #18124 and related issues (#18143, #21306, #12062, #8632, #1486) have 60+ positive reactions
- Consistent feedback requesting role customization capabilities
- Organizations work around limitations by creating multiple projects or granting excessive permissions

**Example Use Cases:**
- **DevOps Engineer:** Push/pull artifacts + manage robot accounts, but cannot manage project members
- **Security Auditor:** Read-only access + trigger vulnerability scans, but cannot modify artifacts
- **Release Manager:** Manage artifacts + set tag immutability, but cannot delete repositories

## Proposal

Extend Harbor's existing RBAC infrastructure to support custom roles by linking the existing `role` table to the `permission_policy` table through the `role_permission` table.

**Core Changes:**

1. **Database:** Move role permissions from hardcoded `rbac_role.go` to database (`role_permission` table)
2. **API:** Add role CRUD endpoints for system administrators
3. **UI:** Add role management interface in System Administration section
4. **Security:** Implement privilege escalation prevention and audit logging

**Key Design Decisions:**

- **Reuse existing infrastructure:** `role`, `permission_policy`, `role_permission`, and `project_member` tables already exist
- **Minimal schema changes:** Only extend `role` table with metadata columns (`is_builtin`, `description`, `modified`, `created_by`, `modified_by`, timestamps)
- **Discriminator pattern:** `role_permission.role_type` distinguishes 'project-role' (users/groups) from 'robotaccount' (direct permissions)
- **System admin only:** Only system administrators can create/modify custom roles (project admins assign roles, existing workflow unchanged)
- **Built-in role protection:** Built-in roles are inmutable. They can not be modified nor deleted
- **Caching is out of scope for this proposal:** Instance-scoped caching may offer a means to mitigate the performance impact of the additional per-request database query. However, a caching implementation must be carefully aligned with Harbor's overall architecture and codebase, and therefore requires further discussion that is intentionally deferred and not part of this proposal.



**Technical Architecture:**

```
┌──────────────────────────────────────────────────────────────┐
│ Before: Hardcoded in rbac_role.go                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│         ┌─────────────────┐                                  │
│         │ users/groups    │                                  │
│         └────────┬────────┘                                  │
│                  ↑                                           │
│                  │                                           │
│         ┌─────────────────┐                                  │
│         │ project_member  │                                  │
│         └────────┬────────┘                                  │
│                  │                                           │
│                  ↓                                           │
│         ┌─────────────────┐                                  │
│         │  role (table)   │                                  │
│         └────────┬────────┘                                  │
│                  │                                           │
│                  ↓                                           │
│            permissions                                       │
│          (hardcoded in                                       │
│           rbac_role.go)                                      │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ After: Database-driven                                       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│         ┌─────────────────┐                                  │
│         │ users/groups    │                                  │
│         └────────┬────────┘                                  │
│                  │                                           │
│                  ↑                                           │
│         ┌─────────────────┐        ┌─────────────────┐       │
│         │ project_member  │───────→│  role (table)   │       │
│         └─────────────────┘        └────────┬────────┘       │
│                                             ↑                │
│                                             │                │
│                                    ┌─────────────────┐       │
│                                    │ role_permission │       │
│                                    │ (role_type=     │       │
│                                    │ 'project-role') │       │
│                                    └────────┬────────┘       │
│                                             │                │
│                                             ↓                │
│                                    ┌─────────────────┐       │
│                                    │ permission_     │       │
│                                    │ policy (table)  │       │
│                                    └─────────────────┘       │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

**User Workflow:**

1. **System Admin:** Creates custom role "DevOps Engineer" with specific permissions
2. **Project Admin:** Assigns "DevOps Engineer" role to user/group (same as built-in roles)
3. **User Login:** Permissions loaded from database
4. **Authorization:** Permission checks load permissions from database

## Non-Goals

**Explicitly out of scope for this proposal:**

1. **Repository-level permissions:** Permissions apply at project level (all repositories in project). Repository-level permission assignment is tracked separately in Issue #10159
2. **Global role assignments:** Custom roles are assigned per-project (user can have different roles in different projects). Global role assignment is tracked in Issue #8351
3. **Role templates/marketplace:** No predefined custom role templates in initial release
4. **Role inheritance/composition:** Roles are flat, not hierarchical
5. **Robot account roles:** Robots continue using direct permission assignment (no role concept)

## Rationale

**Why extend existing RBAC vs. creating a new system:**

✅ **Advantages:**
- Leverages existing, battle-tested permission infrastructure
- Minimal code changes (extend, don't replace)
- No breaking changes to APIs or database schema
- Consistent with Harbor's architectural patterns
- Easy to understand for existing Harbor users and contributors

❌ **Alternative: New parallel permission system:**
- Would require maintaining two RBAC systems
- Breaking changes to existing code
- Higher risk of bugs and security issues
- More complex for users to understand

**Why database-driven vs. more built-in roles:**

✅ **Advantages:**
- Organizations have diverse, unpredictable needs
- Reduces Harbor maintenance burden (no code changes for role requests)
- Enables rapid adaptation to new workflows
- Doesn't clutter built-in role list

❌ **Alternative: Add more built-in roles:**
- Cannot cover all use cases
- Each new role requires code review, testing, release cycle
- Built-in role list becomes overwhelming
- Organizations still request customization

**Why system admin only for role creation:**

✅ **Advantages:**
- Centralized governance and security control
- Prevents permission sprawl
- Aligns with enterprise security models
- Simpler initial implementation

❌ **Alternative: Project admins create custom roles:**
- Higher risk of permission sprawl
- Inconsistent roles across projects
- More complex audit trail
- Can be added later if needed


## Compatibility

**Backward Compatibility: Fully maintained**

✅ **No breaking changes:**
- All existing APIs maintain contracts
- Built-in roles function identically
- Existing role assignments preserved
- Authentication/authorization flow unchanged
- Database migration is reversible

✅ **Migration strategy:**
- Zero-downtime migration
- Built-in role permissions migrated from `rbac_role.go` to `role_permission` table
- Existing roles automatically marked `is_builtin=true`
- All user/group assignments preserved
- If required for future versions, modifications of built-in roles and definition of new built-in role is done through database migration sql files
- Rollback: Standard Harbor rollback procedure (custom roles become inaccessible but data preserved)

**API Compatibility:**

- **New endpoints:** `/api/v2.0/roles/*` (no conflicts with existing endpoints)
- **Extended endpoint:** `/api/v2.0/permissions` (already existed for robots, now includes role permissions)
- **Unchanged endpoints:** All existing role assignment APIs work with custom roles (transparent)

**UI Compatibility:**

- New "Roles" section in System Administration (no impact on existing UI)
- Project member assignment dropdown includes custom roles (alongside built-in roles)
- No changes to existing workflows

**Performance Impact:**

 **Requests:** The naive per-request permission query adds latency to authorization checks — early, un-optimized measurements suggest roughly a 25% increase in request return time.
- **Database:** One additional query plus permission evaluation per request.
- **Mitigation:** Instance-scoped caching is a natural optimization but is deferred (see Key Design Decisions); the figures above represent the un-cached baseline.

**Version Compatibility:**

- Harbor instances without custom roles: No impact
- Harbor instances with custom roles: Rollback preserves data but makes custom roles inaccessible
- Upgrade path: Standard Harbor upgrade (no special steps)

## Implementation

**Repository:**
- Fork: https://github.com/maxgraustenzel-create/harbor
- Branch: `origin/18124-custom-role-feature`

## Open Issues

### 1. Permission Granularity
**Question:** Is project-level permission granularity sufficient, or should we support repository-level permissions?

**Current Decision:** Project-level only (permissions apply to entire project, not individual repositories)  
**Rationale:** 
- Permissions are defined system-wide in `permission_policy` table
- Applied per-project via `project_member` role assignments
- Repository-level permissions would require different scope model and significant additional complexity
- Project-level covers 70%+ of use cases
- Repository-level permissions tracked separately in Issue #10159

**Open for Discussion:** Should repository-level permission assignment be part of this proposal or remain a separate future enhancement?

### 2. Global vs. Project-Scoped Custom Roles
**Question:** Should custom roles be system-wide (reusable across projects) or per-project?

**Current Decision:** System-wide roles, assigned per-project (matches built-in role model)  
**Rationale:** Consistent with existing Harbor model, easier to manage  
**Open for Discussion:** Per-project custom roles could be added later if needed

### 3. Role Templates
**Question:** Should we provide predefined custom role templates (e.g., "Read-Only Auditor", "CI/CD Bot Manager")?

**Current Decision:** No templates in initial release  
**Rationale:** Keep initial scope focused, templates can be added based on community usage patterns  
**Open for Discussion:** Community can contribute templates as documentation/examples

### 4. Built-in Role Modification Policy
**Question:** Should built-in roles be modifiable or immutable?

**Current Decision:** Modifiable (with tracking and reset capability)  
**Rationale:** Maximum flexibility, modifications are tracked, can be reset to defaults  
**Alternative:** Immutable built-in roles (forces use of custom roles for any changes)  
**Open for Discussion:** Security-conscious organizations may prefer immutable built-in roles

### 5. Permission Change Propagation
**Question:** How quickly should permission changes take effect?

**Current Decision:** Immediate — permissions are evaluated per request via a database query, so a changed role takes effect on the user's next request.
**Trade-off:** This adds one query plus evaluation per request (see Performance Impact). Caching (instance-scoped or session-based) could reduce this cost but introduces a propagation-delay window; caching design is out of scope for this proposal (see Key Design Decisions).
**Open for Discussion:** Whether the per-request query cost is acceptable for the initial release.

---

**Feedback Welcome**

This proposal is open for community discussion. Please provide feedback on:
- Architecture and design approach
- Security model and concerns
- API design and compatibility
- UI/UX and usability
- Documentation clarity
- Implementation timeline
- Open issues and alternatives

**Contact:** Max Graustenzel (@maxgraustenzel-create)
