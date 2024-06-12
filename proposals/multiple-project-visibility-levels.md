# Proposal: Multiple Visibility Levels and Control

Author: [Vadim Bauer](https://github.com/Vad1mo) - [8gears Container Registry](https://container-registry.com/)
Created time: 11 June 2024
Last updated: 

## Abstract

This proposal extends Harbor with additional project visibility and permission levels
and upgrades the current public/private project visibility and access.

Once this proposal has been implemented, additional uses cases will become possible, which will be outlined in the proposal.

In addition, it also eliminates the confusion about the consequences of the current visibility of public-private projects.

## Background

The current only two possible options for public and private projects are too limited
and unsuitable for many use cases and organizations.
This is also reflected in many issues and feature requests from the Harbor community.

Harbor has a wide popularity and recognition for its proxy and replication capabilities.
With this proposal,
we can leverage the existing features
and extend them to a wider audience and use cases.

Here are some related issues from the Harbor Community.
- https://github.com/goharbor/harbor/issues/10760
- https://github.com/goharbor/harbor/issues/12306
- https://github.com/goharbor/harbor/issues/5447

Similar Proposal:
- https://github.com/goharbor/community/pull/124


## Proposal

Extend the current public and private project visibility levels with additional options.

- **Private (Existing)**
  Same behavior as the current private project visibility.
  Only users and groups
  that are explicitly added as members to the project to get access,
  based on their access level.
- **Internal View Only**
  All authenticated (hence authenticated)
  users can view and pull artifacts from this project.
  But they are not allowed to pull any artifact from this project unless they are explicitly added as members to the project.
- **Internal**
  All authenticated users can view and pull artifacts from this project
- **Public View Only**
  Unauthenticated Users without a Harbor account can view artifacts and artifacts in this project,
  but they cannot pull artifacts, without being authenticated.
- **Public (Existing)**
  Same behavior as the currently project visibility. Users don’t need to have an account to pull artifacts from this project.


For reference, here is the visibility levels in GitLab for projects:
![img.png](./images/multiple-project-visibility-levels/ref_gitlab_visibility.levels.png)


### Project Level 
On the project level, the project owner can set the visibility level of the project.

### System Level

On the system level, the system admin can set the maximum visibility level for new projects.
For example,
If the maximum visibility level for new projects is set to "private",
then newly created projects would have the visibility level "private"
and the project admin would not be able to change it.

A system admin can change the visibility level for projects regardless of the system level setting.

### Internal Project
Internal projects are a bit special in terms of internal visibility accessibility.
On the one hand,
we want the internal projects
to be visible and accessible inside the organization but private to the outside.
The same would apply to pulling artifacts,
internally without a pull secret and externally just like a private project with a pull secret.

To handle this the internal use case we would need
to have a functionality
that can distinguish between access from internal or external networks. 


### Robot Accounts in Context of Internal Project
Robot accounts for access to projects inside the organization aren't needed for pulling artifacts. 


## Rationale

Looking at how Harbor is used in enterprise environments,
where there are multiple teams and departments,
using different projects,
but also share and common in projects across teams and departments.

Shared projects can be, for example, projects with base artifacts that are offered
internally to the whole organization.

It becomes obvious that in all these use cases, it becomes unfeasible to use the
existing Harbor functionality to cope with the requirements.

Adding every user in the organization to a project makes the project visible to
the user on one hand, but there is no option for the user to build upon this in
automation, deployment or CI/CD.
Robot account can only be created by project owners.

Another use case that would become easier to use is proxy cache projects. Proxy
projects are often used within an entire organization
and would be set to internal visibility.
As those 3rd party sources represent publicly awaitable artifacts, it makes sense
to set it up in a way that the entire
organization to pull or view artifacts in that project would make their adoption
and integration easier.


## Non-Goals

### Project Level

TBD

### System Level

If maximal project visibility restriction is enabled
and the sysadmin changes the setting from a less restrictive to more restrictive option.
Existing projects visibility will not be altered, settings will only apply for newly created projects.  


## Implementation

- Database Schema Updates: The database schema needs to be modified to accommodate the new visibility levels. 
- API Changes: The Harbor API needs to be updated to support the new visibility levels
- User Interface Changes Project Configuration: The Harbor user interface needs to be updated to allow users to set and view the visibility level of projects. This would involve changing the controls in the project settings page.
- User Interface Changes on System Level: Implement the system-level settings that allow a system administrator to set the maximum visibility level for new projects
- Authorization Logic: The authorization logic in Harbor needs to be updated to enforce the new visibility levels.


## Internal Project Detection 
Depending on the underlying infrastructure and deployments,
some Harbor installations might only be reachable from external (internet) networks.
In such cases, the internal project visibility level would make no sense. 
In addition the internal network detection would need
to be implemented in Harbor.
The easiest way to achieve this would be a Header-based detection,
that is set in the reverse proxy or load balancer in front of Harbor.  

For this case Harbor evaluate the HTTP Header`CNCF_HARBOR_INTERNAL` header for presence.

If the environment variable or configuration `HARBOR_INTERNAL_NETWORK_HEADER` is set to a value,
Harbor will evaluate the header with the value of the environment variable.
This environment variable or config need to be set,
otherwise the internal project visibility level will not be displayed or selectable in the UI or by the sysadmin.
