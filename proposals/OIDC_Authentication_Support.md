# Proposal: `Support authentication based on OIDC token`

Author: `reasonerjt` `ktbartholomew`

## Abstract

It proposes an approach to enable Harbor to support SSO via 3rd party OIDC provider. 

## Background

There has been several requests asking for support SSO/OIDC in Harbor, meanwhile, Harbor needs a more extensible way to 
integrate with external ID managers.

## Proposal

I propose we make enhancement so that a unified workflow for user to configure and integrate external OIDC providers with 
Harbor.  Admin can configure an OIDC provider, after that, user can use this OIDC provider as authentication
approach to kick off an SSO flow to log into Harbor's UI Portal.  Besides that, user should be able to use a valid OIDC token
to access Harbor's API, the user should also be able to use docker and helm CLI.

More details for each major use case as follow:

* #### Administrator Configuring OIDC Endpoint

The Administrator of Harbor should be able to configure the OIDC Provider via Portal or configuration API.
The OIDC authentication will be exclusive to other authentication methods, i.e. when admin set to OIDC authentication, 
user registration will be disabled.

The attributes of OIDC provider:

* **Name**: This is the name of the OIDC provider.   
* **Endpoint URL**: The Endpoint URL of the OIDC provider.  It has to be https protocol and is a required attribute. 
* **Scope**: By default, the value will be `openid, email, profile`.  This attribute may be hidden from the UI to avoid 
user error.
* **Client ID**: The registered Client ID for accessing the OIDC provider.  It is a required attribute.
* **Client Secret**: The secret of the registered client for accessing the OIDC provider, it is an optional attribute.
* **Verify Certificate**: This is a switch so user can turn it off to false to skip the certificate verification, in case the 
OIDC provider service is running with self-signed certificate.

**There will be some limitations:**
* Minimized attributes: Some OIDC providers may require additional attributes in configuration, for them the flow may not 
work.
* Only one OIDC endpoint will be supported:  There is some limitation in Harbor's configuration management that there is
no good way to support list as a configuration group.

* #### User login to UI portal via SSO with OIDC provider

After the administrator configured the OIDC provider, there should be a link on the UI login page.  By clicking that link
the user will kick off the OIDC SSO flow: 

   ![Login flow](images/oidc/harbor-oidc-login.png)
   
For the users that login to Harbor via OIDC flow for the first time, there will be an "onboard" process, in which a record
will be inserted into Harbor's Database, so that it can be associated with projects, roles... like a regular user.  In this
process, user will be asked to set the username and it will be shown in the user list, or be used when a project admin is 
adding a member.  The onboard process should happen only once, next time the same user authenticates against the OIDC provider,
he should be logged in with the onboarded username. 

**NOTE:**
There are other attributes in user's profile, such as email, it is not modifiable during onboard process, the code will try 
to use the claim in the token to fill in such values and user can modify it after onboard.  The username is not modifiable once 
is onboarded.

* #### User onboarded via the OIDC authentication flow accessing the API.

After a user is onboarded via OIDC authentication flow and assigned proper permissions, he should be able to trigger API 
of Harbor using his identity.
When a request is sent to trigger Harbor's API, the code in Harbor should be able to validate a OIDC token based on the 
setting of OIDC provider, and map to a user in DB, such that the permission can be checked according to the user.  This 
implies this user has to be onboarded to Harbor when he makes the call to API with OIDC token.

**NOTE:**
For the users authenticated via OIDC provider, the basic auth will not be supported for accessing the API, because Harbor 
cannot verify the password in the request.

* #### User onboarded via the OIDC authentication flow using docker/helm CLI 
After a user is onboarded and assigned proper permissions, he should be able to  use docker/helm CLI to pull/push artifacts 
from/to Harbor.
There's a gap in this scenario given the fact that the CLI tools does not support redirection, that user cannot authenticate 
against the external OIDC provider.  To avoid adding extra dependencies to user, we don't want to create another CLI tool.

To solve this problem, we propose to introduce `cli secret` to OIDC users, when user is onboarded via OIDC, the secret will 
be generated, mapped to the user and associated to the `id_token` and `refresh_token` returned by the OIDC provider.  This 
secret will be obtainable from UI, and user can use it as password in CLI commands such as `docker login` and `helm fetch`,
the backend will match the username and secret, and verify the `id_token`, if the `id_token` expired, it will use `refresh_token`
to refresh tokens against OIDC provider.  Such that in the CLI authentication flow the credentials are verified against the OIDC 
provider.  When user logs out from Harbor the secret will not be destroyed, so the verification flow will still work.

**NOTE:**
In the initial implementation in v1.8.0, some details regarding the `cli secret`:
1. There will be one secret mapped to one user, it's generated automaticly once user is onboarded, providing API to manage
secret is not considered P0 in the timeframe.
2. We don't wanna persist user's token.  The secret will be stored in memory, so when Harbor is restarted the secret is gone,
user will need to re-login to get this secret.
3. With certain OIDC providers and settings combination, it's not possible to get a `refresh_token`, for example 
https://github.com/dexidp/dex/blob/master/Documentation/connectors/saml.md#caveats
In this scenario, user will have to frequently login to UI to force the secret to refresh.
4. Due to limitation in `docker` CLI, it does not have capability to render customized error message, so if errors happen
while refreshing the token, there may not be a good way to inform the user about the detail of the error, user will have to 
check the log for details.

## Non-Goals

* Integration with non-OIDC identity managers such as Keystone
* Support multiple identity managers, such as OIDC/LDAP, OIDC/DB at the same time.

## Compatibility

For verification, we'll need to ensure it works with the following OIDC providers:
* [dex](https://github.com/dexidp/dex) -- P0
* [Keycloak](https://github.com/keycloak/keycloak), Google -- P1

## Implementation
1. Create configuration items for OIDC provider configuration, and update UI to enable the configuration via Portal.
2. Update `systeminfo` API so UI can render a SSO login link in the login page.
3. Create `controller` to handle the redirect from OIDC provider, and finish the oAuth flow.  This `controller` should 
support the `state` query string to prevent CSRF.
4. Create table for `sub` and `username` mapping, and support the onboard flow (including UI)
5. Add filter to handle OIDC token so the request carrying an OIDC token can be verified and mapped to local user record,
such that `local security context` can be used for permission checking.
6. Create the structure to map `cli secret` to `id_token` and `refresh_token`, and create filter to handle the verification of 
cli secret based on the setting of OIDC.

