# Proposal: `Support authentication based on Keystone`

Author: `pytimer`

## Abstract

It proposes an approach to enable Harbor to support non-OIDC Keystone authentication provider.

## Background

Harbor running in the Kubernetes cluster which using the Keystone as authentication, we hope the Kubernetes and Harbor using the same identity provider, so Harobr needs integration with keystone as identity provider.

## Proposal

To support the [user cases](#User cases) in the below section, we add Keystone authentication in Harbor. Admin can configure an Keystone identity provider, after that, user can use this Keystone identity provider as authentication way to login the Harbor's UI Portal. Besides that, user can also use docker CLI.

### User cases

* User running Harbor in the Openstack.
* User running Harbor in the Kubernetes which using the non-OIDC Keyston as authentication.

### Process flow

#### Administrator configure Keystone Endpoint and domain

The administrator or Harbor should be able to configure the Keystone identity provider via UI portal or configuration API.

The attributes of Keystone identity provider:

* **keystone_endpoint**: The endpoint URL of the Keystone identity provider. It protocol only support http now.
* **keystone_domain_name**: The domain of the Keystone identity provider. It is a required attribute.

#### User login to UI protal with Keystone identity provider

After the administrator configured the Keystone identity provider, the users that login to Harbor via Keystone flow for the first time, there will be an "onboard" process, which a user record will be inserted into Harbor's Database, so that it can be associated with projects, roles, etc. The "onboard" process happen only once, next time the same user authenticates against the Keystone provider, user should be logged in with the onboarded username.

**NOTE:**

There are some attributes in user's profile, such as email, it is setting during onboard process, it will try to use the calim in the token to fill in such values and user can modify it. The username is not modifiable once is onboarded.

#### User onboarded via the Keystone authentication flow accessing the API

After a user is onboarded via Keystone authentication flow and assigned proper permissions, user should be able to access the API of Harbor using the identity. It like a regular user.

#### User onboarded via the Keystone authentication flow using the docker CLI

After a user is onboarded via Keystone authentication flow and assigned proper permissions, he should be able to use docker CLI to pull/push images from/to Harbor. The operation like a regular user.

## Non-Goals

## Compatibility

[A discussion of any compatibility issues that need to be considered]

## Implementation

1. Create the configuration items for Keystone identity provider configuration.

2. Create the new `Keystone AuthenticateHelper` to handle the Keystone identity provider.

## Open issues (if applicable)

https://github.com/goharbor/harbor/issues/6979
