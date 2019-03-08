# Proposal: Allow Harbor user to create password for Docker/Helm CLI.

Author: `reaonserjt`, ``

## Abstract

Provide API and UI in Harbor for user to create a password for CLI, which can be used for command like 
`docker login`, `helm push`.

## Background

Currently, when a user in Harbor wants to push/pull images or charts to/from Harbor, he has to provide username/password
he used to login Harbor's portal.  This mechanism has following issues:
  * Risk of exposing the credentials, especially in cases where Harbor is integrated with enterprise identity managers like LDAP
  * Due to limitation of the CLI tool, the OAuth2-like SSO flow is not supported, user cannot be redirected to the Authentication
  service when using the CLI.

## Proposal

We propose introducing the CLI password, which can be used as an alternative way to help user authenticate using `docker`
or `helm` CLI tools.  
After user login to Harbor's portal, he can generate the CLI password, which is a random string to be returned by the API.  
Once it is created, he can use his username and the password to authenticate himself while using `docker` and `helm` CLI.
Each user can have only one CLI password.  It can be reset or revoked by himself or system admin, but cannot be viewed.
The CLI password will stay valid until it's reset or revoked.

## Rationale

1. To simplify the management of the CLI password, in the initial implementation we won't support setting expiration or
allowing user to set the password, it may be supported in future releases based on requirement.
2. An alternative approach to cover the scenario is `access token`.  We decide not to choose access token because we want 
the credential to reflect the permission of the user rather than allowing regular user to manage the scope of the token.  

## Compatibility

We need to make sure this mechanism works with the docker and helm CLI that are supported now, i.e. there should not be 
a case that the user can authenticate using his password for Harbor but not the CLI password he created for himself.

## Implementation

_Details needed_
1. Database: A table should be created to store the hash/salt and user's ID, the way to verify the hash can be the same 
how user's password is handled in `db_auth`
2. API for CLI password management: 
POST /api/users/:id/clipassword -- generate CLI password, the password should be returned in response body.
DELETE /api/users/:id/clipassword  -- delete the CLI password.
3. A filter to cover the API for Chart read/write, which authenticate the 
4. Token service for registry needs to be able to verify 
5. UI

