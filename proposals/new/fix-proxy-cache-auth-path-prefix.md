# Proposal: Fix proxy cache authentication for registries with URL path prefixes

Author: Mathieu c.

Discussion:
* https://github.com/goharbor/harbor/pull/22989
* https://github.com/goharbor/harbor/issues/22891

## Abstract

When a registry endpoint is configured with a URL path prefix (e.g. `https://artifactory.example.com/docker-virtual`), Harbor's proxy cache correctly routes API requests to the right URL but fails to authenticate them. The auth discovery mechanism hardcodes the probe to `scheme://host/v2/`, discarding the path prefix. This is a bug in existing, partially working functionality — not a new feature.

## Background

Harbor already supports creating registry endpoints with a URL path component. The `ValidateHTTPURL` function in `src/lib/endpoint.go` explicitly preserves the path, the registry model stores it, and all V2 API URL builders (`buildManifestURL`, `buildBlobURL`, etc.) correctly concatenate `endpoint + /v2/ + repo + ...`, producing valid requests like `https://hostname/path/v2/library/nginx/manifests/latest`.

There is no UI validation preventing such registries from being created, and the data path (manifest pulls, blob pulls) targets the correct URLs. The only broken piece is authentication: the authorizer's `initialize` method reconstructs the auth challenge endpoint as `scheme://host/v2/`, stripping the path. This causes:

1. **Auth discovery hits the wrong endpoint** — probing `/v2/` instead of `/path/v2/`, potentially getting a different (or no) auth challenge.
2. **`isTarget()` silently drops credentials** — since the stored URL path is `/v2/` but actual requests use `/path/v2/`, the mismatch causes `isTarget()` to return false, so no `Authorization` header is attached.

The net effect: proxy cache for path-prefixed registries works only when the remote allows anonymous pulls. Any registry requiring authentication (bearer or basic) silently fails with 401s.

### Real-world use case: JFrog Artifactory

JFrog Artifactory is a widely deployed enterprise registry that supports a [Repository Path method](https://docs.jfrog.com/artifactory/docs/additional-docker-information#get-started-with-docker-using-a-reverse-proxy) for Docker access, where the registry is addressed as `https://artifactory.example.com/artifactory/api/docker/docker-virtual`. While Artifactory also supports subdomain-based access, the repository path method is common in enterprise environments where creating distinct FQDNs for every registry endpoint can be impractical (requires DNS changes, wildcard certificates, etc.).

Harbor users wanting to set up a proxy cache for such Artifactory instances can create the registry endpoint and the proxy project today, but pulls fail authentication.

Example from Artifactory [API documentation](https://{artifactory_host}/artifactory/api/docker/{repo-key}/v2/{imageName}/tags/list), for registries using the Repository Path method, the V2 API is exposed under a specific sub-path rather than the root:
https://{artifactory_host}/artifactory/api/docker/{repo-key}/v2/{imageName}/tags/list

### Evidence from NGINX logs

Harbor correctly targets the path prefix but fails the auth challenge:

```
10.42.0.39 - [12/Mar/2026:00:21:32 +0000] "HEAD /hardcoded-path/v2/2.1.0/xwz-tbr-bom/manifests/2.1.0-20094027 HTTP/1.1" 401
```

When authentication is injected externally (e.g. via NGINX bearer token injection), the same request succeeds:

```
10.42.0.39 - [12/Mar/2026:22:41:15 +0000] "HEAD /hardcoded-path/v2/2.1.0/xwz-tbr-bom/manifests/2.1.0-20094027 HTTP/1.1" 200
```

## Proposal

A minimal fix to `src/pkg/registry/auth/authorizer.go`: extract the path prefix before `/v2/` from the first outgoing request URL and include it when constructing the auth probe URL. This is a 4-line change.

**Before:**
```go
url, err := url.Parse(u.Scheme + "://" + u.Host + "/v2/")
```

**After:**
```go
prefix := ""
if idx := strings.Index(u.Path, "/v2/"); idx > 0 {
    prefix = u.Path[:idx]
}
url, err := url.Parse(u.Scheme + "://" + u.Host + prefix + "/v2/")
```

No other code changes are needed:
- `isTarget()` already compares `req.URL.Path[:index+4]` against `a.url.Path`, so once the stored URL includes the prefix, it matches correctly.
- The bearer scope regexes in `scope.go` are unanchored and already extract the correct repository name from path-prefixed URLs.
- All V2 URL builders already concatenate the endpoint (including path) correctly.

A working implementation with tests is available at [PR #22989](https://github.com/goharbor/harbor/pull/22989). Codecov confirms 100% coverage of modified lines, and overall project coverage increased.

## Non-Goals

- Adding UI-level path prefix configuration or validation fields to the registry creation form.
- Changing how the registry URL is stored or normalized.
- Supporting Harbor itself being deployed under a path prefix.
- Adding path-prefix-aware logic to replication (it uses the same authorizer, so it benefits automatically).

## Rationale

### Why not reject path-prefixed URLs at creation time?

The feature partially works today. URL builders, health checks, and the data path all handle the path correctly. Blocking path-prefixed URLs would be a regression for users who rely on anonymous pulls through path-prefixed registries. The correct fix is to make the auth layer consistent with the rest of the code.

### Why not require users to set up a reverse proxy / subdomain instead?

In enterprise environments, creating a dedicated FQDN for each registry endpoint requires DNS changes, wildcard certificates, and reverse proxy configuration. The repository path method exists precisely to avoid this overhead. Artifactory, one of the most common enterprise registries, [explicitly documents and supports this approach](https://docs.jfrog.com/artifactory/docs/additional-docker-information#the-repository-path-method-for-docker).

### Why not use a separate configuration field for the path prefix?

The URL already contains the path. Adding a separate field would create redundancy and require changes to the API, database schema, UI, and every adapter. The current approach of extracting the prefix from the URL is zero-configuration and backward compatible.

## Compatibility

- **Fully backward compatible.** For registries without a path prefix, `strings.Index(path, "/v2/")` returns 0, so `prefix` remains empty and behavior is identical to before.
- No database, API, or configuration changes.
- No changes to the registry creation flow or validation.
- Existing proxy cache projects continue to work unchanged.

## Implementation

The implementation is complete and available at [PR #22989](https://github.com/goharbor/harbor/pull/22989):

1. Fix `initialize()` in `src/pkg/registry/auth/authorizer.go` to preserve the URL path prefix (4 lines changed).
2. Add unit tests for `initialize()` and `isTarget()` with path prefixes (new file: `authorizer_test.go`).
3. Add unit tests confirming bearer scope parsing handles path prefixes (appended to existing `scope_test.go`).

All CI checks pass. Coverage of the modified file increased from 45% to 68%.

## Open issues

- Should Harbor add UI validation to warn users about path-prefixed registry URLs, given that this is a less common configuration? This is orthogonal to the bug fix itself.
