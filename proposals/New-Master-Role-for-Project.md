# Proposal: New Master Role To Project

Author: He Weiwei

Discussion: [goharbor/harbor#6391](https://github.com/goharbor/harbor/issues/6391)



## Abstract

Introduce a new master role to project, the role's permissions is more than `developer` and less than `project admin`. So that some operations can by done by user of master role and no needed for `project admin`.



## Background

Current Harbor support three roles in project, these are `project admin`, `developer`, and `guest`. Users of these roles have different scopes for docker registry and different permissions for harbor portal. The more details are list in the following tables.



| Role          | Registry scope                  |
| ------------- | ------------------------------- |
| Project Admin | Pull, push image of the project |
| Developer     | Pull, push image of the project |
| Guest         | Pull image of the project       |

Table 1. Registry scope of the role



| Operation                            | Project admin | Developer | Guest |
| ------------------------------------ | ------------- | --------- | ----- |
| Delete Project                       | :heavy_check_mark: |                    |  |
| New Project Member                   | :heavy_check_mark: |                    |  |
| Edit Project Member                  | :heavy_check_mark: |  |  |
| Delete Project Member                | :heavy_check_mark: |  |  |
| List Project Members                 | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| List Project Logs                    | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| New Project Replication              |  |  |  |
| Edit Project Replication             |  |  |  |
| Delete Project Replication           |  |  |  |
| List Project Replications            | :heavy_check_mark: |  |  |
| Replicate                            |  |  |  |
| New Project Label                    | :heavy_check_mark: |  |  |
| Edit Project Label                   | :heavy_check_mark: |           |  |
| Delete Project Label                 | :heavy_check_mark: |           |  |
| List Project Labels                  | :heavy_check_mark: |           |       |
| Update Project Configuration         | :heavy_check_mark: |           |       |
| List Project Configurations          | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| New Repository (Push Image)        | :heavy_check_mark: | :heavy_check_mark: |  |
| Edit Repository                      | :heavy_check_mark: |           |       |
| Delete Repository                    | :heavy_check_mark: |  |  |
| List Repositories                    | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| Scan Image                           | :heavy_check_mark: |  |       |
| List Image Vulnerability             | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| View Image Build History             | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| Delete Image                         | :heavy_check_mark: |           |       |
| Retag Image                          | :heavy_check_mark: |           |       |
| Add Label to Image                   | :heavy_check_mark: | :heavy_check_mark: |       |
| Remove Label from Image              | :heavy_check_mark: | :heavy_check_mark: |       |
| Upload Helm Chart                    | :heavy_check_mark: | :heavy_check_mark: |       |
| Download Helm Chart                  | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| Delete Helm Chart                    | :heavy_check_mark: |           |       |
| Add Label to Helm Chart Version      | :heavy_check_mark: | :heavy_check_mark: |       |
| Remove Label from Helm Chart Version | :heavy_check_mark: | :heavy_check_mark: |       |

Table 2. Operations and permissions of project, repository, image, helm chart and others in Portal



Project `project admin` has all the permissions of the project,  `developer` has `write` permission on some operations and others are `read` permission, and `guest` only has `read` on some operations .



Harbor customers want grant more permissions to the project member, but not want to set the member to `project admin` , e.g. repository, image delete and image scan.



A solution is that introduce a new `master` role to project, which has more permissions than `developer` and less permission than `project admin`.  And the developer's permissions is limited the same as `guest` except that it can push image and upload helm chart.



The new operations and permissions of project is following

| Operation                            | Project admin | Master | Developer | Guest |
| ------------------------------------ | ----- | ----- | ----- | ----- |
| Delete Project                       | :heavy_check_mark: |  |                    |  |
| New Project Member                   | :heavy_check_mark: | :heavy_check_mark: |                    |  |
| Edit Project Member                  | :heavy_check_mark: |  |  |  |
| Delete Project Member                | :heavy_check_mark: |  |  |  |
| List Project Members                 | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| List Project Logs                    | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| New Project Replication              |                    |  |  |  |
| Edit Project Replication             |                    |  |  |  |
| Delete Project Replication           |  |  |  |  |
| List Project Replications            | :heavy_check_mark: |  |  |  |
| Replicate                            |  |  |  |  |
| New Project Label                    | :heavy_check_mark: | :heavy_check_mark: |  |  |
| Edit Project Label                   | :heavy_check_mark: | :heavy_check_mark: |           |  |
| Delete Project Label                 | :heavy_check_mark: | :heavy_check_mark: |           |  |
| List Project Labels                  | :heavy_check_mark: | :heavy_check_mark: |           |       |
| Update Project Configuration         | :heavy_check_mark: |  |           |       |
| List Project Configurations          | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| New Repository (Push Image)          | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |  |
| Edit Repository                      | :heavy_check_mark: | :heavy_check_mark: |           |       |
| Delete Repository                    | :heavy_check_mark: | :heavy_check_mark: |  |  |
| List Repositories                    | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| Scan Image                           | :heavy_check_mark: | :heavy_check_mark: |  |       |
| List Image Vulnerability             | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| View Image Build History             | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| Delete Image                         | :heavy_check_mark: | :heavy_check_mark: |           |       |
| Retag Image                          | :heavy_check_mark: | :heavy_check_mark: |           |       |
| Add Label to Image                   | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |       |
| Remove Label from Image              | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |       |
| Upload Helm Chart                    | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |       |
| Download Helm Chart                  | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| Delete Helm Chart                    | :heavy_check_mark: | :heavy_check_mark: |           |       |
| Add Label to Helm Chart Version      | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |       |
| Remove Label from Helm Chart Version | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |       |

Table 3. New operations and permissions of project, repository, image, helm chart and others in Portal




| Operation                            | Resource           | Action |
| ------------------------------------ | ----- | ----- |
| Delete Project                       | project | delete |
| New Project Member                   | member | create |
| Edit Project Member                  | member | update |
| Delete Project Member                | member | delete |
| List Project Members                 | member | list |
| List Project Logs                    | log | list |
| New Project Replication              | replication | create |
| Edit Project Replication             | replication | update |
| Delete Project Replication           | replication | delete |
| List Project Replications            | replication | list |
| Replicate                            | replication | execute |
| New Project Label                    | label | create |
| Edit Project Label                   | label | update |
| Delete Project Label                 | label | delete |
| List Project Labels                  | label | list |
| Update Project Configuration         | configuration | update |
| List Project Configurations          | configuration | list |
| New Repository (Push Image)          | repository | create |
| Edit Repository                      | repository | update |
| Delete Repository                    | repository | delete |
| List Repositories                    | repository | list |
| Scan Image                           | image | scan |
| List Image Vulnerability             | vulnerability | list |
| View Image Build History             | build-history | read |
| Delete Image                         | image | delete |
| Retag Image                          | image | retag |
| Add Label to Image                   | image | add-label |
| Remove Label from Image              | image | remove-label |
| Upload Helm Chart                    | helm-chart | upload |
| Download Helm Chart                  | helm-chart | download |
| Delete Helm Chart                    | helm-chart | delete |
| Add Label to Helm Chart Version      | helm-chart-version | add-label |
| Remove Label from Helm Chart Version | helm-chart-version | remove-label |

Table 4.  Resources and actions for operations




## Proposal

I propose the following solutions:



### Overview

Implement `RBAC` support in Harbor using [casbin](https://github.com/casbin/casbin) pkg. Add `Can` method to `security.Context` and in API use `Can` to check whether use can do action on the resource.



New pkg rbac will be introduced, it use casbin to provide a `HasPermission` function.

```go
package rbac

// Resource the type of resource
type Resource string

// Action the type of action
type Action string

// Effect tye type of effect
type Effect string

// Policy the type of policy
type Policy struct {
	Resource
	Action
    Effect
}

// Role the interface of role
type Role interface {
	GetRoleName() string
	GetPolicies() []*Policy
}

// User the interface of user
type User interface {
	GetUserName() string
	GetPolicies() []*Policy
	GetRoles() []Role
}

// HasPermission returns whether the user has action on resource
func HasPermission(user User, resource Resource, action Action) bool {
    return enforcerForUser(user).Enforce(user.GetUserName(), resource.Stirng(), action.String())
}
```



```go
package rbac

import (
	"fmt"

	"github.com/casbin/casbin"
	"github.com/casbin/casbin/model"
	"github.com/casbin/casbin/persist"
)

var modelText = `
# Request definition
[request_definition]
r = sub, obj, act

# Policy definition
[policy_definition]
p = sub, obj, act, eft

# Role definition
[role_definition]
g = _, _

# Policy effect
[policy_effect]
e = some(where (p.eft == allow)) && !some(where (p.eft == deny))

# Matchers
[matchers]
m = g(r.sub, p.sub) && keyMatch2(r.obj, p.obj) && (r.act == p.act || p.act == '*')
`

type userAdapter struct {
	User
}

func (a *userAdapter) getRolePolicyLines(role Role) []string {
	// ...
}

func (a *userAdapter) getUserPolicyLines() []string {
	// ...
}

func (a *userAdapter) getUserAllPolicyLines() []string{
	// ...
}

func (a *userAdapter) LoadPolicy(model model.Model) error {
	for _, line := range a.getUserAllPolicyLines() {
		persist.LoadPolicyLine(line, model)
	}

	return nil
}

// ...

func enforcerForUser(user User) *casbin.Enforcer {
	m := model.Model{}
	m.LoadModelFromText(modelText)
	return casbin.NewEnforcer(m, &userAdapter{User: user})
}

```



Project member, project role, project permission will be used to implement `rbac.User`, `rbac.Role` and `rbac.Policy` interface. Then `rbac.HasPermission` can be used to check whether project member has permission on resource of project.



New `security.Context` interface

```go
type Context interface {
	// IsAuthenticated returns whether the context has been authenticated or not
	IsAuthenticated() bool
	// GetUsername returns the username of user related to the context
	GetUsername() string
	// IsSysAdmin returns whether the user is system admin
	IsSysAdmin() bool
	// IsSolutionUser returns whether the user is solution user
	IsSolutionUser() bool
	// Get current user's all project
	GetMyProjects() ([]*models.Project, error)
	// Get user's role in provided project
	GetProjectRoles(projectIDOrName interface{}) []int
    // Can returns whether the user can do action on resource
	Can(action rbac.Action, resource rbac.Resource) bool
}
```



For API, e.g Repository Delete

```go
func (ra *RepositoryAPI) Delete() {
	// ...
    // ...

    // Currrent permission check
	if !ra.SecurityCtx.HasAllPerm(projectName) {
		ra.HandleForbidden(ra.SecurityCtx.GetUsername())
		return
	}
    
    // Change to this
    resource := rbac.Resource(fmt.Sprintf("/project/%s/repository", projectName))
    if !ra.SecurityCtx.Can(rbac.Action("delete"), resource) {
		ra.HandleForbidden(ra.SecurityCtx.GetUsername())
		return
	}
	
	// ...
    // ...
}
```



### UI

Core will provide a `GET` API `/api/users/current/permissions` to return all permissions for current authenticated user. These permissios will be used to check whether enable operations on portal.



| Param    | Type    | Required | Description                                                  |
| -------- | ------- | -------- | ------------------------------------------------------------ |
| scope    | String  | Yes      | Get the permissions under the scope, eg,  for scope`/project/1` will get all permissions of the project 1 for current authenticated user |
| relative | Boolean | No       | Returens whether resource in response is relative to the scope, eg for resource `/project/1/image` if `relative` is `true` then respone for it will be `image` |

Table 5. `/api/users/current/permissions` params



The response will be like this
```json
[
    { "resource": "resource1", "action": "action1" },
    { "resource": "resource2", "action": "action2" },
    { "resource": "resource3", "action": "action3" }
]
```



## Rationale

[None]



## Compatibility

No breaking changes for current customers