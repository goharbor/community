# Proposal: JWT Authentication Support for Robot Accounts (aka Federated Authentication or Secretless authentication)

Author: David Schneider

Related issues:
- https://github.com/goharbor/harbor/issues/17520 
- https://github.com/goharbor/harbor/issues/22027
- https://github.com/goharbor/harbor/issues/10894

Partially related issues:
- https://github.com/goharbor/harbor/issues/21392
- https://github.com/goharbor/harbor/issues/17477
- https://github.com/goharbor/harbor/issues/19944

## Abstract

This feature introduces JWT (JSON Web Token) authentication as an alternative authentication method for robot accounts.

## Background

Many systems provide an identity to their workload in the form of a JWT.
For example:
- [GitLab CI](https://docs.gitlab.com/ci/secrets/id_token_authentication/#token-payload)
- [Github Actions](https://docs.github.com/en/actions/reference/security/oidc)
- [Kubernetes Service Accounts](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#schema-for-service-account-private-claims)

By leveraging JWTs we can trust an external system instead of issuing static secrets.
This way you no longer have to rotate tokens but instead rely on short-lived JWTs issued by the external system.

Classical use cases would be:
- access to Harbor from a CI pipeline (e.g. GitLab CI, GitHub Actions)
- image pull from Kubernetes

## Proposal

- Allow to configure an authentication method for a robot account. Either `secret` (the default) or the new `jwt`
- Introduce a resource JWKS provider, which references the public keys used to verify JWTs (usually via JWKS URL)
- If authentication method `jwt` is used on a robot account you also have to configure a JWKS provider which will be used to validate the JWT
- Allow requiring certain claims to be present in the JWTs (e.g. bind to specific subject with `sub`)

## Compatibility

The approach integrates into the existing robot account architecture. Instead of passing a static secret as password, a JWT is passed.

## Implementation

Here you find the PoC implementation https://github.com/dvob/harbor/tree/robot-account-jwt-authentication [3ead887](https://github.com/dvob/harbor/tree/3ead8870b942424cb6a6b9b3ef96a02fee04b705).

Until now robot accounts could only authenticate via a secret. The change introduces the `auth_type` on robot accounts which is either `secret` or `jwt`.
If the `auth_type` of a robot account is of type `jwt`, you also have to specify the `jwks_provider_id` which references a JWKS provider which will be used to validate the JWT.

A JWKS provider is a new global resource which basically points to a public key used to verify JWTs. In the PoC implementation the public key is referenced via the `jwks_url` but other implementations would be possible here (e.g. OIDC discovery, static key in database).

If a robot account is configured to use the `jwt` authentication method, it has to send a JWT token instead of the static secret. Based on the configured JWKS provider, Harbor does validate the JWT token.

In addition to the basic check if the token is valid (signature, expiry) you can configure claim checks on two levels, the robot account and/or the JWKS provider.
The claim checks in the current implementation are very basic and only allow to check if a claim in the JWT is set to a certain value.

Setting the checks on two levels can be used as follows:
- Claim Checks on JWKS Provider level: Broad checks which have to hold true for all robot accounts using this JWKS provider. Here you could check things like `iss`, `aud` or maybe on Github restrict access to a certain organization (`repository_owner`)
- Claim Check on Robot Account level: Narrow down the allowed tokens resp. bind the robot account to a particular identity (e.g. using the `sub` claim)

To get a better understanding take a look at the code of the PoC implementation and the following example configurations:
- Push Image from GitHub Actions: https://gist.github.com/dvob/77f05fb749fb26f46de3bbf9493a989e#file-github-md
- Push Image from GitLab CI: https://gist.github.com/dvob/77f05fb749fb26f46de3bbf9493a989e#file-gitlab-md
- Pull Image using Kubernetes Service Account and Credential Provider: https://gist.github.com/dvob/77f05fb749fb26f46de3bbf9493a989e#file-kubernetes-md

## Open issues

- Currently the claim checks are very limited. For example checking for nested claims or pattern matching is not supported. As alternative or extension we might use [CEL](https://cel.dev/) expressions which would offer a lot of flexibility. In the branch [robot-account-jwt-authentication-cel](https://github.com/dvob/harbor/tree/robot-account-jwt-authentication-cel) I implemented this for the JWKS provider level checks in an experimental fashion.
- JWKS providers could be extended to allow other ways to point to the public keys like for example a OIDC discovery URL or by configuring a static public key. Also, currently the keys are cached in memory per process. We probably want to store the obtained public keys in the database or Redis.
- UI part is not implemented yet

# Appendix

## Example Configuration Github Actions
- Claims: https://docs.github.com/en/actions/reference/security/oidc
- JWKS URL: https://token.actions.githubusercontent.com/.well-known/jwks

Harbor configuration:
```
harbor_host=harbor.yourdomain.com
harbor_url=https://${harbor_host}/api/v2.0
username=admin
password=Harbor12345

# create project
curl "$harbor_url/projects" \
  -X POST \
  -H 'Content-Type: application/json' \
  -u "$username:$password" \
  --data-raw '{"project_name":"myproject"}'

# create jwks provider
curl "$harbor_url/jwks_providers" \
  -X POST \
  -H 'Content-Type: application/json' \
  -u "$username:$password" \
  --data-raw '{
      "name": "github",
      "description": "Github.com",
      "jwks_url": "https://token.actions.githubusercontent.com/.well-known/jwks",
      "required_claims": {
	      "iss": "https://token.actions.githubusercontent.com",
	      "aud": "https://harbor.yourdomain.com"
      }
}'

jwks_provider_id=$( curl "$harbor_url/jwks_providers" -u "$username:$password" | jq -r '.[] | select(.name == "github") | .id' )

curl -v "$harbor_url/robots" \
  -X POST \
  -H 'Content-Type: application/json' \
  -u "$username:$password" \
  --data-raw '{
  "name": "my-github-robot",
  "auth_type": "jwt",
  "jwks_provider_id": '"$jwks_provider_id"',
  "required_claims": {
    "sub": "repo:your-github-org/github-jwt-test:ref:refs/heads/main"
  },
  "description": "Github Repository",
  "duration": -1,
  "level": "project",
  "permissions": [
    {
      "access": [
        {
          "resource": "repository",
          "action": "push"
        },
        {
          "resource": "repository",
          "action": "pull"
        },
        {
          "resource": "repository",
          "action": "read"
        }
      ],
      "kind": "project",
      "namespace": "myproject"
    }
  ]
}'
```

Github action:
```
name: Push to Harbor using JWT
on: [push]

permissions:
  id-token: write
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: 
        id: harbor-creds
        run: |
          HARBOR_TOKEN=$( curl -f -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=https://harbor.yourdomain.com" | jq -r .value )

          echo $HARBOR_TOKEN | docker login --username 'robot$myproject+my-github-robot' harbor.yourdomain.com --password-stdin

          docker pull busybox
          img=harbor.yourdomain.com/myproject/busybox
          docker tag busybox $img
          docker push $img
```

## Example Configuration GitLab CI

- Claims: https://docs.gitlab.com/ci/secrets/id_token_authentication/#token-payload
- JWKS URL: https://gitlab.com/oauth/discovery/keys

Harbor configuration:
```
harbor_host=harbor.yourdomain.com
harbor_url=https://${harbor_host}/api/v2.0
username=admin
password=Harbor12345

# create project (if not already exists)
curl "$harbor_url/projects" \
  -X POST \
  -H 'Content-Type: application/json' \
  -u "$username:$password" \
  --data-raw '{"project_name":"myproject"}'

# create jwks provider
curl "$harbor_url/jwks_providers" \
  -X POST \
  -H 'Content-Type: application/json' \
  -u "$username:$password" \
  --data-raw '{
      "name": "gitlab",
      "description": "Gitlab.com",
      "jwks_url": "https://gitlab.com/oauth/discovery/keys",
      "required_claims": {
	      "iss": "https://gitlab.com",
	      "aud": "https://harbor.yourdomain.com"
      }
}'

jwks_provider_id=$( curl "$harbor_url/jwks_providers" -u "$username:$password" | jq -r '.[] | select(.name == "gitlab") | .id' )

curl -v "$harbor_url/robots" \
  -X POST \
  -H 'Content-Type: application/json' \
  -u "$username:$password" \
  --data-raw '{
  "name": "my-gitlab-robot",
  "auth_type": "jwt",
  "jwks_provider_id": '"$jwks_provider_id"',
  "required_claims": {
    "sub": "project_path:your-gitlab-org/your-repo-name:ref_type:branch:ref:main"
  },
  "description": "Gitlab Repository",
  "duration": -1,
  "level": "project",
  "permissions": [
    {
      "access": [
        {
          "resource": "repository",
          "action": "push"
        },
        {
          "resource": "repository",
          "action": "pull"
        },
        {
          "resource": "repository",
          "action": "read"
        }
      ],
      "kind": "project",
      "namespace": "myproject"
    }
  ]
}'
```

Example `.gitlab-ci.yml`:
```
push_image:
  id_tokens:
    HARBOR_TOKEN:
      aud: https://harbor.yourdomain.com
  image: docker:25.0.0
  stage: build
  services:
    - docker:25.0.0-dind
  script:
    - |
      echo $HARBOR_TOKEN | docker login --username 'robot$myproject+my-gitlab-robot' harbor.yourdomain.com --password-stdin
      docker pull busybox
      img=harbor.yourdomain.com/myproject/busybox
      docker tag busybox $img
      docker push $img
```

## Example Configuration Kubernetes Credential Provider

- Claims: https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#schema-for-service-account-private-claims

Harbor configuration:
```
harbor_host=harbor.yourdomain.com
harbor_url=https://${harbor_host}/api/v2.0
username=admin
password=Harbor12345

# create project (if not already exists)
curl "$harbor_url/projects" \
  -X POST \
  -H 'Content-Type: application/json' \
  -u "$username:$password" \
  --data-raw '{"project_name":"myproject"}'

# obtain project id
project_id=$( curl "$harbor_url/projects" -u "$username:$password" | jq '.[] | select(.name == "myproject") | .project_id' )

# create jwks provider
curl "$harbor_url/jwks_providers" \
  -X POST \
  -H 'Content-Type: application/json' \
  -u "$username:$password" \
  --data-raw '{
      "name": "kubernetes",
      "description": "My Kubernetes Cluster",
      "jwks_url": "https://k8s.yourdomain.com/openid/v1/jwks",
      "required_claims": {}
}'

jwks_provider_id=$( curl "$harbor_url/jwks_providers" -u "$username:$password" | jq -r '.[] | select(.name == "kubernetes") | .id' )

curl -v "$harbor_url/robots" \
  -X POST \
  -H 'Content-Type: application/json' \
  -u "$username:$password" \
  --data-raw '{
  "name": "my-kubernetes-robot",
  "auth_type": "jwt",
  "jwks_provider_id": '"$jwks_provider_id"',
  "required_claims": {
    "sub": "system:serviceaccount:mynamespace:mysa"
  },
  "description": "Service Account mysa of namespace mynamespace in mycluster",
  "duration": -1,
  "level": "project",
  "permissions": [
    {
      "access": [
        {
          "resource": "repository",
          "action": "pull"
        },
        {
          "resource": "repository",
          "action": "read"
        }
      ],
      "kind": "project",
      "namespace": "myproject"
    }
  ]
}'
```

Add an image:
```
docker login pull busybox
docker tag busybox $harbor_host/myproject/busybox
docker push $harbor_host/myproject/busybox
```

Kubernetes config for image pull:
```
kubectl create ns mynamespace

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mysa
  namespace: mynamespace
  annotations:
    echo-provider.io/username: "robot$myproject+my-kubernetes-robot"
---
# Test pod that pulls from private registry using service account token
apiVersion: v1
kind: Pod
metadata:
  name: test-pull
  namespace: mynamespace
spec:
  serviceAccountName: mysa
  containers:
  - name: test
    image: harbor.yourdomain.com/myproject/busybox
    command: ["ls"]
  restartPolicy: Never
EOF
```

Credential provider configuration:
```
apiVersion: kubelet.config.k8s.io/v1
kind: CredentialProviderConfig
providers:
  - name: echo-provider
    matchImages:
      - "harbor.yourdomain.com"
      - "harbor.yourdomain.com/*"
    defaultCacheDuration: "10m"
    apiVersion: credentialprovider.kubelet.k8s.io/v1
    tokenAttributes:
      serviceAccountTokenAudience: "https://harbor.yourdomain.com"
      cacheType: "Token"
      requireServiceAccount: true
      requiredServiceAccountAnnotationKeys:
        - "echo-provider.io/username"
```

Credential provider implementation:
```go
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	credentialproviderv1 "k8s.io/kubelet/pkg/apis/credentialprovider/v1"
)

const (
	usernameAnnotationKey = "echo-provider.io/username"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	data, err := io.ReadAll(os.Stdin)
	if err != nil {
		return fmt.Errorf("failed to read request: %w", err)
	}

	var req credentialproviderv1.CredentialProviderRequest
	if err := json.Unmarshal(data, &req); err != nil {
		return fmt.Errorf("failed to unmarshal request: %w", err)
	}

	if req.ServiceAccountToken == "" {
		return errors.New("service account token is empty")
	}

	username, ok := req.ServiceAccountAnnotations[usernameAnnotationKey]
	if !ok {
		return fmt.Errorf("annotation %q not found in service account", usernameAnnotationKey)
	}

	response := &credentialproviderv1.CredentialProviderResponse{
		TypeMeta: metav1.TypeMeta{
			Kind:       "CredentialProviderResponse",
			APIVersion: "credentialprovider.kubelet.k8s.io/v1",
		},
		CacheKeyType: credentialproviderv1.ImagePluginCacheKeyType,
		Auth: map[string]credentialproviderv1.AuthConfig{
			req.Image: {
				Username: username,
				Password: req.ServiceAccountToken,
			},
		},
	}

	if err := json.NewEncoder(os.Stdout).Encode(response); err != nil {
		return errors.New("error marshaling response")
	}

	return nil
}
```

