# Proposal: `Support "Webhook Token Authentication" in authentication of docker CLI`

Author: `reasonerjt`

## Abstract

In HTTP Auth Proxy mode, support the scenario user input a token as password, and backend can verify the token following 
the `Token Review` process of Kubernetes: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#webhook-token-authentication

## Background

In HTTP Auth Proxy mode, user's authenticated by sending request to an "auth proxy".  For some users, this Docker CLI's 
approach to save credentials locally becomes a risk.  To mitigate the problem they want to have other credential for authenticating
the same user, while the verification of the credentials should be tied to the "auth proxy", i.e. creating another set 
of password managed by Harbor locally is less than favorable.

## Proposal

Given the fact that the auth proxy will return a token to user if the authentication is successful.
We propose Harbor should support the use case that user use the token as password while issuing command via Docker CLI.
Harbor will verify the token by calling the configured webhook, the interaction with this webhook will follow the process 
of "Webhook Token Authentication" in Kubernetes: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#webhook-token-authentication

## Rationale

In the proposal regarding OIDC, there is a mechanism proposed to generate `cli secret` mapped to token and user can use that 
secret for authentication in CLI.  That approach may have some issue for the scenario in this proposal, for example the 
token in the scenario in this proposal may not support refresh, users may have their own way to get the token and Harbor
will only need to verify the token against the configured endpoint.
Additionally, in practice we want to control the dependency of effort, after the work flow in OIDC is verified and refined
we may consider to extend the `cli secret` flow to other auth modes.

## Implementation

1. Add configuration item for configuring the webhook endpoint
2. Add modifier in the filter to handle the token verification by calling the webhook.

