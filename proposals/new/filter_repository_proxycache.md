Proposal: Limit proxy cache repositories by filter

Author: stonezdj

## Abstract

Harbor proxy cache projects currently allow pulling any repository from the configured upstream registry. This proposal introduces a repository filter on proxy cache projects so administrators can explicitly allow only selected repositories. Requests that do not match the configured filter are denied before Harbor proxies content from upstream.

## Motivation

Many organizations use Harbor as the only approved image source for runtime environments, while direct access to public registries is restricted for security and compliance reasons. Proxy cache simplifies image consumption, but without repository filtering it also opens access to unintended or untrusted content.

Today users commonly work around this by creating many replication rules for individual repositories and tags. This is operationally expensive and hard to maintain at scale.

With proxy cache filters, administrators can define an allowlist such as:

- `library/**` -- doublestar matching for all repositories under `library`
- `goharbor/**` -- doublestar matching for all repositories under `goharbor`
- `myorg/.*` -- regex matching for all repositories under `myorg`

This keeps the proxy cache workflow while preserving repository governance.

## Issues

[Limit Proxy Cache Images - by adding filter](https://github.com/goharbor/harbor/issues/13231)

## Goals and Non-Goals

1. Add per-project proxy cache repository filter configuration.
2. Enforce filter matching before upstream proxy pull behavior is executed.
3. Keep backward compatibility: if no filter is configured, current behavior remains unchanged.
4. Provide API and UI support for creating and updating filter configuration as part of proxy cache project configuration.

1. This proposal does not add denylist precedence rules. Initial scope is allowlist-only.
2. This proposal does not introduce global/system-level proxy filter policy.
3. This proposal does not support tag-based filtering in this phase, because pull requests by tag are often converted to pull requests by digest in client side.
4. This proposal does not perform content trust or vulnerability policy evaluation as part of filter matching.

## Solution

Add a new optional setting for proxy cache projects: `repository_filter`.

Matching semantics:

1. If `repository_filter` is empty or not set, all repositories are allowed (same as today).
2. If `repository_filter` is configured, Harbor allows the pull only when the requested repository matches the configured pattern.
3. The filter format is JSON: `{"filter":"<pattern>","kind":"regex"|"doublestar"}`.
4. `kind` is optional. If omitted, Harbor uses `regex` matching by default.
5. If the repository does not match, Harbor returns `404 Not Found` and does not request content from upstream.

Pattern format:

- `regex`: regular expression matching against repository path.
- `doublestar`: glob-style matching with doublestar support (`*`, `**`, `{a,b}`, and related glob features).

## Implementation Details

### Request enforcement point

Enforcement should happen in proxy middleware before upstream manifest proxy operations:

- Entry point: proxy pre-check logic in `src/server/middleware/repoproxy/proxy.go`.
- After project and proxy configuration are resolved.
- Before issuing upstream manifest requests.

Processing flow:

1. Resolve current project and verify it is a proxy cache project.
2. Load project proxy filter configuration.
3. Build artifact request context (repository).
4. Evaluate against repository filter.
5. If not matched, return `404 Not Found`.
6. If matched, continue existing proxy logic unchanged.

Notes on behavior:

1. Invalid `repository_filter` JSON or invalid pattern is treated as non-match at runtime.
2. In project metadata API validation, invalid JSON or unsupported `kind` value is rejected with `400 Bad Request`.

### Data model

Store filter as project metadata, consistent with existing proxy project settings.

Proposed metadata key:

- `repository_filter`

Proposed JSON value:

```json
{
	"filter": "^library/.*",
	"kind": "regex"
}
```

Validation:

1. `filter` can be empty (empty means match all).
2. `kind` must be `regex` or `doublestar` when specified.
3. Invalid JSON is rejected during project metadata validation.

### API changes

Extend project APIs for proxy cache configuration:

1. `POST /api/v2.0/projects`
2. `PUT /api/v2.0/projects/{project_name_or_id}`
3. `GET /api/v2.0/projects/{project_name_or_id}` and list APIs should include configured filters in response.

`repository_filter` is metadata for proxy cache projects only. For non-proxy projects, this metadata is ignored on create/update and omitted from response.

Request example:

```json
{
	"project_name": "dockerhub-proxy",
	"registry_id": 1,
	"metadata": {
		"repository_filter": "{"filter":"library/**","kind":"doublestar"}"
	}
}
```

### UI changes

In proxy cache project create view, add a new configuration item:

- Label: `Repository filter`
- A text input for filter pattern -- input the pattern for repository filtering.
- A kind selector with options: `Regex` and `Doublestar`

Validation should happen both client-side and server-side.

### Audit and observability

1. Record project update audit entries when filter set is changed.
2. Add log item for blocked proxy pulls (project, repository, reason) to help operators tune filters.

## Database Schema Changes

No new table is required for initial implementation when storing as project metadata.


## Compatibility

1. Existing proxy cache projects without filters keep current behavior (allow all).
2. New behavior is opt-in by configuring `repository_filter`.
3. Clients receive `404 Not Found` for repositories that do not match the configured filter.

## Open issues

N/A
