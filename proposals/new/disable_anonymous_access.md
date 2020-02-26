# Proposal: `Enable / Disable Anonymous Access`

Author: `Ye Liu / cafeliker`

Discussion: `https://github.com/goharbor/harbor/issues/10760`

## Abstract

Add the system configuration to enable / disable anonymous access

## Background

Anonymous access is good for community purpose; and for Enterprise, the public repo should be only visible for authenticated people to protect the content and IP.

It's a required feature to allow administrator enable / disable the anonymous access

## Proposal

Add a configuration item named "Disable anonymous access" in the System Setting page with a checkbox:
1. When "Disable anonymous access" is checked, non authenticated users can't access any resources include the public project in the Harbor instance;
2. When "Disable anonymous access" is unchecked, keep the existing behavior that any user can query the public project and pull docker images under a public project without login.

## Implementation

1. Add the new "Disable anonymous access" checkbox into the system-settings.component.html file under the portal package
2. The docker pull / push permission can be controlled through the rbac package
3. Add the anonymous access check login in the List() method on project.go under the core/api package.

The proposed code change can be found at the PR https://github.com/goharbor/harbor/pull/10825

