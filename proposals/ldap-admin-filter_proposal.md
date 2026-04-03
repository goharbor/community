Proposal: LDAP Admin Group Filter

Author: `Prasanth Baskar / @bupd`

Discussion: https://github.com/goharbor/harbor/issues/8122

## Abstract

Add `ldap_group_admin_filter` configuration to Harbor for flexible LDAP-based admin group filtering. This enables admin privileges for users from multiple LDAP groups and supports nested group membership evaluation.

## Background

Harbor's `ldap_group_admin_dn` field accepts only a single group DN. Users must be direct members of that group to receive admin privileges.

Enterprise environments commonly use:
- Multiple admin groups maintained by different teams
- Nested group structures where permissions are inherited
- Groups derived from organizational structure

### Example Scenario
```
ou=groups
  Managers1 (admin group)
    Alexa (user) - has admin access
    Bobby (user) - has admin access
    harbor-managers (nested group)
      Charlie (user) - NO admin access (BUG)
```

Charlie is a member of `harbor-managers` nested under `Managers1` but does not inherit admin privileges. Harbor does not evaluate nested membership.

Issue #8122 has been open since Harbor 1.8.0 (2019) with consistent community requests.

## Proposal

Add `ldap_group_admin_filter` that accepts standard LDAP filter syntax, mirroring the existing `ldap_filter` for user authentication.

### Configuration
```json
{
  "ldap_group_admin_dn": {
    "value": "cn=managers1,ou=groups,dc=ad,dc=example,dc=com"
  },
  "ldap_group_admin_filter": {
    "value": "(memberof:1.2.840.113556.1.4.1941:=cn=managers1,ou=groups,dc=ad,dc=example,dc=com)"
  }
}
```

### Behavior
- When `ldap_group_admin_filter` is set, Harbor uses this filter to evaluate admin membership
- When empty, falls back to existing `ldap_group_admin_dn` behavior

### Example Filters

Single group with nested membership (Active Directory):
```ldap
(memberof:1.2.840.113556.1.4.1941:=cn=managers1,ou=groups,dc=example,dc=com)
```

Multiple admin groups:
```ldap
(|(memberOf=cn=Managers1,ou=Groups,dc=example,dc=com)
   (memberOf=cn=Managers2,ou=Groups,dc=example,dc=com))
```

### UI Changes
New input field "LDAP Group Admin Filter" added below "LDAP Group Admin DN" in authentication settings.

## Non-Goals

- Nested group resolution for regular (non-admin) user groups
- Modifying existing `ldap_group_admin_dn` behavior
- UI-based group selector or browser

## Rationale

### Alternatives Considered

#### Multiple DN List
Extend `ldap_group_admin_dn` to support semicolon-separated DNs.

Cons: Does not support nested group evaluation.

#### Hardcoded Nested Group Checkbox
Add checkbox to enable nested groups with hardcoded filter.

Cons: Limited flexibility, cannot support multiple groups, does not adapt to diverse LDAP schemas.

### Why LDAP Filter

1. Consistency with existing `ldap_filter` for users
2. Flexibility through standardized LDAP filter syntax
3. Enterprise-ready without code changes for different LDAP schemas

### Security

The same complexity exists in current `ldap_filter` for users. LDAP administrators are expected to understand filter syntax. The field is optional.

## Compatibility

- Fully backward compatible
- Existing `ldap_group_admin_dn` unchanged
- `ldap_group_admin_filter` is optional
- No migration required

### LDAP Server Support
- Active Directory: Full support with `LDAP_MATCHING_RULE_IN_CHAIN` OID
- OpenLDAP: Standard filter support
- Other servers: Standard filter syntax supported

## Implementation

Reference: https://github.com/goharbor/harbor/pull/21806

### Remaining Work
- Documentation updates
- Integration testing with various LDAP servers

## Open Issues

### Test Coverage
Additional unit tests needed for core filter logic and validation.

## References

- Issue #8122: https://github.com/goharbor/harbor/issues/8122
- Issue #9492: https://github.com/goharbor/harbor/issues/9492
- PR #21806: https://github.com/goharbor/harbor/pull/21806
- AD Nested Group OID: `1.2.840.113556.1.4.1941`
