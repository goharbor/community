Proposal: Robot account enhancement

Author: Yan Wang

Discussion: [goharbor/harbor#10774](https://github.com/goharbor/harbor/issues/10774) [goharbor/harbor#11286](https://github.com/goharbor/harbor/issues/11286)

## Abstract

Robot account limited into one specific project, it cannot access multiple projects. 

## Motivation

In the current release, Harbor uses jwt as its token, but it cannot satisfy user's requirement, like manage multiple projects or edit access scope or expiration date. 

## Solution

This proposal wants to try to introduce a way to enable robot account access scope edition without creating a new robot, and system level robot account creation.

## Non Goal

1.  Do not migrate old mode robot, keep it as it is. The old mode robot account can be used as before, but cannot show/edit the access scope. 
2.  Do not support add a robot account into a project as a member to get the permission suite(Role binding).
3.  Do not support customize the pre-defined scope.
4.  Do not support update level of robot account, like from project level to system level.

## Personas and User Stories

This section lists the user stories for the different personas interacting with robot account.

* Personas

Robot Account is a System Administrator and Project Administrator operation in Harbor.

* User Stories

1.  As a system admin, I can create a system level robot account with the selected projects and access scope.
2.  As a system admin, I can edit a system level robot account to enhance/reduce the access scope.
3.  As a system admin, I can edit a system level robot account to enhance/reduce the project scope.
4.  As a system admin, I can extend the expiration data of a system level robot account.
5.  As a system admin, I can view the token of a system level robot account and refresh the token.
6.  As a system/project admin, I can create a project level robot account with the selected access scope.
7.  As a system/project admin, I can edit a project level robot account to enhance/reduce the access scope.
8.  As a system/project admin, I can extend the expiration data of a project level robot account.
9.  As a system/project admin, I can view the token of a project level robot account and refresh the token.

## Main Points

1.  Replace JWT token with the secret.
2.  Store all things of robot into data base, expiration date, token and permissions.
3.  Support both old and new robot mode authenticate.

## DB Scheme Change

Update the robot table to record the new format robot account.

```yaml

CREATE TABLE robot (
 id SERIAL PRIMARY KEY NOT NULL,
 name varchar(255),
 description varchar(1024),
 expiresat bigint,
 /*
  project_id 
    0 means, it's a system level robot
    non-0 means, it's a project level robot
  */
 project_id int,
 /*
  token string used as the password of robot account.
  For v2.2, it stores the secret.
  */
 token varchar(255),
 /*
  permissions string used as the access scope.
  */
 permissions varchar(1024),
 disabled boolean DEFAULT false NOT NULL,
 creation_time timestamp default CURRENT_TIMESTAMP,
 update_time timestamp default CURRENT_TIMESTAMP,
 CONSTRAINT unique_robot UNIQUE (name, project_id)
);

```

## API

* Create a project level robot account (v2.1 or previous), it will be reserved but not used in the v2.2 UI.
```
POST api/v2.0/projects/{id}/robots

STATUS       : 201 Accepted
HEADERS      :
   Connection: keep-alive
   Content-Length: 0
   X-Request-Id: 92e7d4be-0291-4c50-92bd-889d71e1ec78
BODY         :

{
   "name":"robotaccount",
   "expires_at":-1,
   "description":"robot account 2",
   "access":[
      {
         "resource":"/project/1/repository",
         "action":"push"
      },
      {
         "resource":"/project/1/helm-chart",
         "action":"read"
      },
      {
         "resource":"/project/1/helm-chart-version",
         "action":"create"
      }
   ]
}

```

* Create a project level robot account (v2.2)
```
POST api/v2.0/robots

STATUS       : 201 Accepted
HEADERS      :
   Connection: keep-alive
   Content-Length: 0
   X-Request-Id: 92e7d4be-0291-4c50-92bd-889d71e1ec78
BODY         :

{
   "name":"robotaccount",
   "description":"robot account",
   "expires_at":-1,
   "level": "project",
   "permissions":[
      {
         "project_id":1,
         "access":[
            {
               "Resource":"/project/1/repository",
               "Action":"push",
               "Effect":""
            },
            {
               "Resource":"/project/1/helm-chart",
               "Action":"read",
               "Effect":""
            },
            {
               "Resource":"/project/1/helm-chart-version",
               "Action":"create",
               "Effect":""
            }
         ]
      }
   ]
}

```

* Create a system level robot account

```
POST api/v2.0/robots

STATUS       : 201 Accepted
HEADERS      :
   Connection: keep-alive
   Content-Length: 0
   X-Request-Id: 92e7d4be-0291-4c50-92bd-889d71e1ec78
BODY         :

{
   "name":"robotaccount",
   "description":"robot account",
   "expires_at":-1,
   "level": "system",
   "permissions":[
      {
         "project_id":1,
         "access":[
            {
               "Resource":"/project/1/repository",
               "Action":"push",
               "Effect":""
            },
            {
               "Resource":"/project/1/helm-chart",
               "Action":"read",
               "Effect":""
            }
         ]
      },
      {
         "project_id":2,
         "access":[
            {
               "Resource":"/project/2/repository",
               "Action":"push",
               "Effect":""
            },
            {
               "Resource":"/project/2/helm-chart",
               "Action":"read",
               "Effect":""
            },
            {
               "Resource":"/project/2/helm-chart-version",
               "Action":"create",
               "Effect":""
            }
         ]
      }
   ]
}

```

* Update permissions of a project level robot account

```
PUT api/v2.0/robots/{id}

STATUS       : 200 OK
HEADERS      :
   Connection: keep-alive
   Content-Length: 0
   X-Request-Id: 92e7d4be-0291-4c50-92bd-889d71e1ec78
BODY         :

{
   "id": 2,
   "name":"robotaccount",
   "description":"robot account",
   "project_id":1,
   "disable":false,   
   "expires_at":-1,
   "level": "project",
   "permissions":[
      {
         "project_id":1,
         "access":[
            {
               "Resource":"/project/1/repository",
               "Action":"push",
               "Effect":""
            },
            {
               "Resource":"/project/1/helm-chart",
               "Action":"read",
               "Effect":""
            }
         ]
      }
   ]
}

```

* Get all system level robot accounts

```
GET api/v2.0/robots?level=system
```

* Get all robot accounts of a specific project

```
GET api/v2.0/robots?level=project&project_id=1
```

For the old mode robot account, the permissions and expiration date are not editable.

![robot_control](../images/robot-account-2/robot_ctr.png)

* Refresh token of a robot account.

```
POST api/v2.0/robots/{id}/refresh

STATUS       : 201 Accepted
HEADERS      :
   Connection: keep-alive
   Content-Length: 0
   X-Request-Id: 92e7d4be-0291-4c50-92bd-889d71e1ec78
BODY         :

{}

```

## Auth

Add a robot2 authenticator after robot. For the multiple projects handling on robot2, just merge all accesses into one security context.

![auth_flow](../images/robot-account-2/robot_auth.png)


```
func NewSecurityContext(robot *model.Robot, level string, policy []*types.Policy) *SecurityContext {
	...
}
```

## How to distinguish robot with harbor user

Tow options:

1.  Reserve the prefix, but with another different character, like "@", "+" or ":", these are not need to be escaped in shell script.
2.  Remove the prefix (robot$), and set the password of robot as all lower case, as harbor cannot set all lower case as the password of user.

## Mock up UI

The UI of creating a system level robot

![mock_ui](../images/robot-account-2/robot_create.png)

### To Be Discussed 

* The pre-defined access scope for robot creation, no Spec so far.
* Whether to provide Kubernetes pull secret for the robot account.
* Whether to provide Docker credentials config for the robot account.



