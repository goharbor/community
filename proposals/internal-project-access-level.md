# Proposal: `Internal (auth_only) Project Access Level`

Author: [`Hanna Czifrus`](https://github.com/czifrushanna)

Discussion: [`Disable anonymous user #10760`](https://github.com/goharbor/harbor/issues/10760)

## Abstract

Add a third project access level, `Internal`, alongside the existing `Public` and `Private` levels. An `Internal` project is readable (pull, list, view metadata) by any authenticated Harbor user, regardless of project membership, but remains invisible and inaccessible to anonymous/unauthenticated requests. Write operations (push, delete, configuration changes, etc.) still require an explicit project role, exactly as they do for private projects.

## Background

Harbor currently supports two project access levels, controlled by the `public` project metadata flag:

- **Public** (`public=true`) — readable by anyone, including anonymous/unauthenticated clients.
- **Private** (`public=false`) — readable only by explicit project members (or system admins).

In organizations that run Harbor behind SSO/authentication for all users, there is no way to expose a project as "readable by everyone in the organization" without either:

- making it fully `Public`, which also exposes it to anonymous/unauthenticated access if the deployment allows it, or
- adding every user (or a very broad group) as an explicit `Guest` member of the project, which does not scale and pollutes the member list.

There is no middle ground between "world-readable" and "readable only by an explicit member list." This proposal adds that middle ground.

## Proposal

### New access level

Introduce a new value for the project `public` metadata field: `auth_only`. The field now accepts three values: `"true"` (public), `"false"` (private), `"auth_only"` (internal). The `auth_only` value is exposed in the portal as **Internal**.

- `Project.IsAuthOnly()` — new method on the project model, mirroring `IsPublic()`.
- `ProjectAuthOnly = "auth_only"` constant added next to the existing `ProjectPublic`/`ProjectPrivate` constants.
- Both `CreateProject` and `UpdateProject` validate that `metadata.public` is one of `"true"`, `"false"`, or `"auth_only"`.

### Permission model

`auth_only` grants the same **read-only** policy set that public projects already grant (`getPoliciesForPublicProject`: pull, list repositories/tags/artifacts, read scan results, etc.) — but only to requests that are authenticated:

- `rbacUser` gains an `isAuthenticated` flag, set based on whether the request carries a resolved Harbor user (as opposed to the anonymous/unauthenticated visitor).
- `GetPolicies()` grants the read-only public-project policy set when either the project `IsPublic()`, or the project `IsAuthOnly()` **and** the visitor `isAuthenticated`.
- Anonymous requests against an `auth_only` project get no implicit policies (same as private today) — they must still fall back to explicit membership, which by definition an anonymous request never has.
- Explicit project roles (Guest, Developer, Maintainer, Project Admin) work exactly as they do today and layer on top — e.g. a `Developer` member of an `auth_only` project can still push, while a non-member authenticated user can only pull.
- System admins retain full access, unaffected by this change.

### Listing, searching, and filtering projects

- `MemberQuery` and `NamesQuery` gain a `WithAuthOnly` flag, mirroring the existing `WithPublic` flag, so `ListProjects` can union in `auth_only` projects for authenticated non-admin users and project-scoped robot accounts (in addition to their own memberships and, where applicable, public projects).
- `Project.FilterByPublic` handles all three values explicitly: `true` → `value = 'true'`, `false` → `value = 'false'` (strict — private only, does **not** implicitly include `auth_only`), `"auth_only"` → `value = 'auth_only'`.
- The portal's `?public=<bool>` query parameter only accepts a boolean, so there is no direct way to ask the REST API for "only `auth_only` projects" through that parameter. Instead, an explicit `auth_only` filter is expressed through the generic advanced query string, `q=public=auth_only`, which the `ListProjects` handler recognizes and treats as an explicit request: rather than dropping the `public` keyword (which is done when `auth_only` projects are being unioned in as part of a broader "everything I can read" listing), the handler ANDs it against the member/robot union, narrowing the result down to strictly `auth_only` projects.
- Global search (`/search`) includes `auth_only` projects in the "projects I can read" set (`WithAuthOnly: true` on the member query) for authenticated users, alongside their own projects and public ones. The `ProjectPublic` flag on individual search hits, however, reflects only true public/anonymous-readable status — `auth_only` projects are surfaced in search results for authenticated users but are not mislabeled as public.
- The system `/statistics` endpoint reports a new `auth_only_project_count` field, and `private_project_count` is adjusted to `total - public - auth_only` so the three counts stay mutually exclusive and add up to the total.

### Event/webhook/replication payloads

Webhook payloads (artifact push, quota exceeded, scan completed) and the replication push-artifact/create-tag event handlers previously derived a single public/private (`RepoType`/`repository.metadata.public`) flag from `project.IsPublic()`. They now propagate the project's actual access level: `public`, `private`, or `auth_only`, so downstream webhook consumers and replication targets can distinguish `auth_only` projects instead of having them silently collapse into `private`.

### Portal UI

- The project policy/config page replaces the previous `Public` on/off checkbox with a three-way radio control: **Private / Internal / Public**, backed by the same `public` metadata field (`"false" | "auth_only" | "true"`).
- The create-project dialog gets the same three-way choice.
- The project detail page's access-level badge recognizes and labels `auth_only` projects as **Internal** (rather than falling back to "Private").
- The project list page gains an **Internal Projects** filter option (`All / Private / Internal / Public`), alongside the existing Private/Public filters. Because the REST `public` query parameter is boolean-only, this filter is implemented via the `q=public=auth_only` advanced-query mechanism described above.
- The system statistics panel gains an **Internal Projects** count tile alongside the existing public/private counts.
- New translation keys (`PROJECT.AUTH_ONLY`, `PROJECT.INTERNAL_PROJECTS`, `STATISTICS.INDEX_AUTH_ONLY`, etc.) are added across all shipped locale files.

### API/Swagger

- `ProjectMetadata.public`'s description is updated to document the `auth_only` value and its meaning.
- `Statistic.auth_only_project_count` is added to the statistics response schema.

## Non-Goals

- This proposal does not introduce a fourth/custom access-level system or pluggable access-level policies — `auth_only` is a fixed, built-in third level alongside `public`/`private`.
- It does not change write permissions: `auth_only` is strictly a read-only grant to authenticated non-members. Push, delete, and configuration changes still require an explicit project role.
- It does not change anonymous access behavior for existing `public` or `private` projects.
- It does not add a way to filter by `auth_only` through the dedicated boolean `public` query parameter itself; this is handled through the existing generic `q=` advanced query mechanism instead of widening the boolean parameter's type.

## Rationale

An alternative considered was to keep the `public` field strictly boolean and instead model "internal" as a convention on top of project groups/LDAP groups (e.g. auto-adding all authenticated users to a well-known group and granting that group `Guest` membership on projects). This was rejected because it requires per-project administrative action, does not compose with existing group-based membership, and does not give a single, discoverable, first-class access-level value comparable to `public`/`private` in the UI, API, and audit trail.

Making `auth_only` a value of the existing `public` metadata field (rather than a separate new field) was chosen to minimize schema/API churn: no new project-metadata key, no new column, and every code path that already branches on public/private only needed a third branch added, rather than a second independent flag to reconcile against the first.

## Compatibility

- The `public` metadata field remains backward compatible: existing values `"true"`/`"false"` are unaffected, and any code that does a boolean-style check via `IsPublic()`/`isTrue()` continues to treat `auth_only` projects as non-public, i.e. the same as private, unless it has been explicitly updated to also check `IsAuthOnly()`.
- The `FilterByPublic(false)` semantics were deliberately kept **strict** (`value = 'false'`, private only) rather than "not public" (which would have implicitly swept in `auth_only` projects) to avoid silently changing the meaning of `?public=false` for any existing integration.
- `private_project_count` in `/statistics` changes in value (no longer includes `auth_only` projects) for any deployment that starts using the new access level, but the field's meaning ("count of private projects") is unchanged and the response schema is additive (new field only).
- No database migration is required: `auth_only` is simply a new allowed value for the existing `project_metadata` `public` key/value pair.

## Implementation

Implemented by Hanna Czifrus on branch `feat/internal-project-access-level`, in the following stages:

1. Core model and RBAC: `auth_only` metadata value, `IsAuthOnly()`, `WithAuthOnly` query flags, `FilterByPublic`/`FilterByMember`/`FilterByNames` handling, and the `rbacUser` authenticated-read-only policy grant, with unit tests in `src/pkg/project/models` and `src/common/rbac/project`.
2. Portal UI: three-way access-level radio control in create-project and project-policy-config, project-detail badge, and translations for all shipped locales.
3. Propagation fixes: `auth_only` access level surfaced correctly in webhook payloads (artifact/quota/scan), replication event payloads, and search results, with regression tests.
4. Filtering/statistics correctness passes: `ListProjects` keyword handling for the member/robot union vs. an explicit `q=public=auth_only` request, `/statistics` `auth_only_project_count` (moved from `List` to `Count` for efficiency), and restoring strict `public=false` semantics.
5. Project list **Internal Projects** filter in the portal, driven through the `q=public=auth_only` advanced query since the `public` query parameter is boolean-only.
6. Test coverage pass across the above (RBAC evaluator, security context, project model filters, webhook/replication handlers, search, project listing).

## Open issues

- The REST API's dedicated `public` query/request parameter remains boolean-only; filtering strictly for `auth_only` projects requires the generic `q=public=auth_only` advanced query syntax rather than a first-class parameter value. A future revision could widen `public` to accept `auth_only` directly if this proves confusing to API consumers.
