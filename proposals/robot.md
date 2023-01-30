Proposal: Support Robot account in Harbor

Author: Yan Wang

## Abstract

Robot account is a machine user that have the permission to access harbor resources, like pull/push docker images. It's a better way to integrate harbor into your CI/CD workflow without using a user account, especially in LDAP mode.

## Motivation

There are a lot of requirements from community would like to have the ability to work harbor with robot account. But, Harbor only has the capability of using the registered user to access resources, and do not support user to pull image with robot acccout.

## User Stories

### Story 1
As a project administrator, I want to be able to create a robot account and grant project read/write permission to it.

### Story 2
As a dev ops developer, I want to be able to use the token of robot account to pull image.

## Solution

This proposal only targets on the pull/push images workflow, and the design includes DB, API, authn/authz.

### DB scheme

1, the robot account is not a harbor user, so an new table introduced to store the robot info.

```yaml

CREATE TABLE robot (
 id SERIAL PRIMARY KEY NOT NULL,
 name varchar(255),
 /*
  The maximum length of token is 7k
  this could be removed if has security issue.
 */
 token varchar(7168),
 description varchar(1024),
 project_id int,
 disabled boolean DEFAULT false NOT NULL,
 creation_time timestamp default CURRENT_TIMESTAMP,
 update_time timestamp default CURRENT_TIMESTAMP,
 CONSTRAINT unique_robot UNIQUE (name, project_id)
);

```

### API

The project admin could manager the robot accounts of the project, all the api are project admin only. 

1, Adding a robot account

````

POST /api/project/${pid}/robots
Data: 
{
  name: "test1",
  desc: "test1_desc",
  access: [
    {"resource":"/projects/1/repo", "action":"pull"},
    {"resource":"/projects/1/repo", "action":"push"}
  ]
}

````

````

201 ok

Location /api/projects/1/robots/11

{
  name: "robot$test1",
  token: "rKgjKEMpMEK23zqejkWn5GIVvgJps1vKACTa6tnGXXyOlOTsXFESccDvgaJx047q"
}

````

2, Disable a robot account

````

PUT /api/project/${pid}/robots/${id} 
Data:
{
    Disable: true
}    

````

3, View a/all robot account

````

GET /api/project/${id}/robots
GET /api/project/${id}/robots/${id}

````

4, DELETE a/all robot account

````

DELETE /api/project/${pid}/robots/${id}

````

## Login 

### UI login
Not supported

````
The robot account cannot login to harbor portal.

No code change as all the robot accounts are stored in harbor_robots instead of harbor_user.
````

### Docker login

To distinguish the robot account from user, it will add a predefined prefix "robot$" to the name of robot, like "robot$example1".

1, with user/pwd

````

docker login harbor.example.com
Username: robot$robotexample
Password: rKgjKEMpMEK23zqejkWn5GIVvgJps1vKACTa6tnGXXyOlOTsXFESccDvgaJx047q

````

2, with config.json

````

{
  "auths": {
    “harbor.example.com”: {
      "auth": "Zmcm01Szl2eXc0elJOU2pkaEgvR1YrUjdCUXFIeWtQMTFkWWZXSUV0YU13cWhcbnllZjR1K2dUQytrYk81R002eUhqcmJFUGxHcW03WDU4UWtxd2JDbTdhMllnNi9SM2hl",
    }
  }
}

````

### AuthN/AuthZ

- The authn for robot account rely on the DB.

#### Add a new context modifier as below to handle the auth of robot account.

````

secretReqCtxModifier => robotsReqCtxModifier => basicAuthReqCtxModifier =>  sessionReqCtxModifier => unauthorizedReqCtxModifier

robotsReqCtxModifier --- robot login -- DB (harbor_robots)

````

```go

type robotAuthReqCtxModifier struct{}

func (b *robotAuthReqCtxModifier) Modify(ctx *beegoctx.Context) bool {
	username, password, ok := ctx.Request.BasicAuth()
	if !ok {
		return false
	}
	if !strings.HasPrefix("username", "robot$") {
		return false
	}
	log.Debug("got user information via basic auth")

    // Decode the token to validate it in the DB. 
    token, err := jwt.decode(password)
	if err != nil {
		log.Errorf("failed to authenticate %s: %v", username, err)
		return false
	}    
	user, err := dao.GetRobotByID(token.id)	
	if err != nil {
		log.Errorf("failed to authenticate %s: %v", username, err)
		return false
	}
	if user == nil {
		log.Debug("basic auth user is nil")
		return false
	}
	log.Debug("creating local database security context...")
	pm := config.GlobalProjectMgr
	securCtx := robot.NewSecurityContext(user)
	setSecurCtxAndPM(ctx.Request, securCtx, pm)
	return true
}


```

- The authz for robot account rely on the jwt token.

#### Token

##### Config items

| Item               | Value          | Level  | Note                  |
| ------------------ | -------------- | ------ | --------------------  |
| Robot_Token_Expire | 30             | User   | Hard code for 1 year  |
| Robot_Token_Key    | /etc/robot_key | System | Share the key of core |

##### Model

```go

type Token struct {
    Raw       string                 
    Method    SigningMethod          
    Header    map[string]interface{} 
    Claims    Claims                 
    Signature string                 
    Valid     bool                   
}

type Claims struct {
    Audience  string `json:"aud,omitempty"`
    ExpiresAt int64  `json:"exp,omitempty"`
    Id        string `json:"jti,omitempty"`
    IssuedAt  int64  `json:"iat,omitempty"`
    Issuer    string `json:"iss,omitempty"`
    NotBefore int64  `json:"nbf,omitempty"`
    Subject   string `json:"sub,omitempty"`
    Access []*ResourceActions `json:"access"`
}

type ResourceActions struct {
	Name    string   `json:"name"`
	Actions []string `json:"actions"`
}

```

##### Scpoe -- Implement a new security context for robot account

In the implementation of robot context, the func of Can could validate the token scope, and block all the request to harbor with forbidden. 

In Can(), will map the token access scope with the policy defined in the ram model.

```go

./src/common/security/robots/context.go

// SecurityContext implements security.Context interface based on database
type SecurityContext struct {
	robots *models.Robots
}

// NewSecurityContext ...
func NewSecurityContext(robots *models.Robots) *SecurityContext {
	return &SecurityContext{
		robots: robots,
		pm:   pm,
	}
}

// IsAuthenticated returns true if the user has been authenticated
func (s *SecurityContext) IsAuthenticated() bool {
	return s.robots != nil
}

// GetUsername returns the name of the authenticated robot account
// It returns null if the robot account has not been authenticated
func (s *SecurityContext) GetUsername() string {
	if !s.IsAuthenticated() {
		return ""
	}
	return s.robots.name
}

// IsSysAdmin ...
func (s *SecurityContext) IsSysAdmin() bool {
	return false
}

// IsSolutionUser ...
func (s *SecurityContext) IsSolutionUser() bool {
	return false
}

// HasReadPerm returns whether the user has read permission to the project
func (s *SecurityContext) HasReadPerm(projectIDOrName interface{}) bool {
	return s.Can(project.ActionPull, project.NewNamespace(projectIDOrName).Resource(project.ResourceImage))
}

// HasWritePerm returns whether the user has write permission to the project
func (s *SecurityContext) HasWritePerm(projectIDOrName interface{}) bool {
	return s.Can(project.ActionPush, project.NewNamespace(projectIDOrName).Resource(project.ResourceImage))
}

// HasAllPerm returns whether the user has all permissions to the project
func (s *SecurityContext) HasAllPerm(projectIDOrName interface{}) bool {
	return s.Can(project.ActionPushPull, project.NewNamespace(projectIDOrName).Resource(project.ResourceImage))
}


// GetProjectRoles ...
func (s *SecurityContext) Can(action ram.Action, resource ram.Resource) bool {
	// mapping the token scope and ram policy
	return false
}

// GetProjectRobots ...
func (s *SecurityContext) GetProjectRobots(projectIDOrName interface{}) []int {
	return nil
}


```
