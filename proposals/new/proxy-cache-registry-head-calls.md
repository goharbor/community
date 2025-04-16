# Proposal: Cache proxy-cache registry HEAD calls

Author: Maxime Hubert / @mxm-tr

Discussion: [Harbor Community Meeting - April 16th](https://hackmd.io/CyQk5FdVQwWObMLVNqxW1w?both#April-16-2025)

[Original issue](https://github.com/goharbor/harbor/issues/21859)

## Abstract

Reduce the volume of HEAD requests by caching proxy cache ManifestExist calls.

## Background

When pulling many artifacts at the same time on a container proxy-cache, we can still trigger the rate limiting on the upstream registries and get 429 Too Many Requests errors.

This is in part caused by HEAD requests being sent for each artifact pull.

## Proposal

The solution could consist of a cache for calls to [HeadManifest](https://github.com/goharbor/harbor/blob/main/src/controller/proxy/controller.go#L258)

These cache entries can be valid for a fixed period of time, for a few seconds (10s)

## Non-Goals

N/A

## Rationale

The cache lifetime could be configurable via a parameter, but the current implementation has already some [hardcoded values](https://github.com/goharbor/harbor/blob/f8f1994c9ee97e41067870c4ed46b15eb21da3b6/src/controller/proxy/controller.go#L43), setting a fixed low value should be enough to not trigger rate-limiting on servers.

## Compatibility

N/A

## Implementation

1. Use a new cache key in the [proxy controller cache](https://github.com/goharbor/harbor/blob/bfc29904f96e17248a4e6204d12058c1d7d05ab8/src/controller/proxy/controller.go#L78), such as:

```
cache:manifestexists:<repo>:<ref>
```

2. Define its lifetime to a value that would prevent rate limiting from being triggered (10s?) in the [proxy-controller](https://github.com/goharbor/harbor/blob/bfc29904f96e17248a4e6204d12058c1d7d05ab8/src/controller/proxy/controller.go#L41-L48)

```golang
manifestExistsCacheInterval = 10 * time.Second
```

3. Before running [remote.ManifestExist](https://github.com/goharbor/harbor/blob/main/src/controller/proxy/controller.go#L258), run a cache fetch on the proxy controller cache.

If the cache is invalid or the key is not found, run remote.ManifestExist, and save a boolean in the proxy controller cache.

## Open issues (if applicable)

https://github.com/goharbor/harbor/issues/21859
