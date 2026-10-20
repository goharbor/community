# Proposal: `Proxy cache: check upstream on HEAD blob when the blob is not cached`

Author: `Ben Woolston / @Trillient`

Discussion: https://github.com/goharbor/harbor/issues/22609

## Abstract

In a proxy cache project, a HEAD on a blob that Harbor hasn't cached yet returns 404, while a GET of the same blob is served from upstream. This proposal makes the HEAD ask upstream, only when the blob isn't cached locally, so HEAD and GET agree.

## Background

The HEAD blob route runs only the local blob check (`blob.HeadBlobMiddleware`). The GET blob route also runs `repoproxy.BlobGetMiddleware`, which proxies upstream on a local miss. A client that sends HEAD before GET gets 404 for every layer of an image Harbor hasn't seen, and stops.

Clients that do this today:

- a `distribution/distribution` pull through cache in front of Harbor. `proxyBlobStore.ServeBlob` calls `remoteStore.Stat` (a HEAD) before `Open` (a GET) and returns `BLOB_UNKNOWN` on the 404. This is a common way to run a per-cluster cache in front of a central Harbor.
- `oras blob fetch` (reported on #22609).

The original pull through proxy cache proposal (`proposals/new/pull_through_proxy_cache.md`) does not send blob HEADs upstream, to protect upstream rate limits. That concern is addressed under Rationale.

## Proposal

For a HEAD blob request on a proxy cache project:

1. Requests from the proxy cache itself (the proxy cache service account, used when Harbor checks whether it has cached a blob yet) are handled locally, unchanged.
2. The existing GET rules apply in the same order: Docker Hub default library redirect, repository filter, upstream registry health, and "use the local blob if it exists".
3. Otherwise Harbor sends a HEAD for the blob to the upstream registry, inside the project's existing upstream connection limit. If upstream confirms the blob, Harbor returns 200 with its `Content-Length`, `Docker-Content-Digest` and `Etag`, and no body. Nothing is downloaded or stored.
4. If upstream rate limits the HEAD, the client gets 429, the same as when Harbor's own upstream connection limit is hit. If upstream says the blob doesn't exist, or the call fails in any other way, the request is handled locally exactly as today.

Non proxy cache projects are unchanged.

## Non-Goals

- Caching the blob on HEAD. Caching stays on GET.
- Changing manifest HEAD handling, which already goes upstream.
- Any new configuration option. Proxy cache projects already promise to serve what upstream has.

## Rationale

Rate limits. The extra upstream request only happens on a local miss, is a HEAD, and is bounded by the existing per-project upstream connection limit. Docker Hub documents that HEAD requests don't count towards its pull limit (https://docs.docker.com/docker-hub/usage/pulls/). In the pull through cache case, each of these HEADs is immediately followed by a GET that Harbor proxies anyway. Like the GET path, each upstream HEAD builds a remote helper, so for Docker Hub it also fetches a bearer token from auth.docker.io; that is the same per request cost the GET path has today.

Recursion. Harbor checks whether it has cached a blob by sending a HEAD to its own core URL. Those requests are passed through to the local registry, both when they verify as the proxy cache session and whenever they carry a proxy secret at all, so the check can't be proxied back into the new code even if a secret has expired. A client forging that header only gets the local view.

Alternatives considered:

- Fix it in the downstream client (for example distribution falling back to GET when HEAD 404s). That has to be done in every client, and it works around a registry that answers HEAD and GET differently for the same blob, which the OCI distribution spec doesn't expect.
- A project setting to opt in. It adds configuration for behaviour that most users would expect by default, and the fallback in point 4 keeps the existing behaviour whenever upstream doesn't answer.
- Return 200 from HEAD and let GET handle it, without asking upstream. That would report blobs that don't exist upstream.

## Compatibility

HEAD responses change from 404 to 200 only for blobs that are not cached locally and that upstream confirms exist. Every other case returns what it does today. No API, schema or configuration changes. The registry adapter interface gains one method (`BlobStat`), and all adapters get it from the embedded native registry client.

## Implementation

PR: https://github.com/goharbor/harbor/pull/24175. It adds `BlobStat` to the registry client and the proxy remote interface, a `BlobHeadMiddleware` in `repoproxy` wired before `blob.HeadBlobMiddleware` on the HEAD blob route, and shares the upstream connection limiter with the GET path. Unit tests cover the client and the middleware. End to end it was tested on a v2.15.4 build with a `registry:3` pull through cache in front of a Docker Hub proxy cache project.

Author: @Trillient, available to address review and present at a community meeting.

## Open issues

None known.
