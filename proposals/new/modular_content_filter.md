# Proposal: Modular Content Filter (replication first)

Author: `Vlad Mocanu / vtmocanu`

Discussion: [goharbor/harbor#19864](https://github.com/goharbor/harbor/issues/19864)

Related: [goharbor/community#280](https://github.com/goharbor/community/pull/280) — "Limit proxy cache repositories by filter" (a per-project repository allowlist for proxy cache). This proposal is intended to align with that effort over time, not to absorb or replace it. Co-design with the author of #280 is required before any implementation overlap.

## Abstract

Introduce a small content-filter package in Harbor (`pkg/contentfilter` — name TBD) used by replication today and structured so future consumers (proxy cache, others) can adopt it without re-inventing filter semantics. The first concrete user is replication's per-platform filter to close [issue #19864](https://github.com/goharbor/harbor/issues/19864).

A second design constraint: **when filtering multi-arch artifacts, the manifest list / OCI image index is copied verbatim — not rewritten**. Only the matching children are transferred. This preserves Cosign signatures (both per-arch and list-level) and accessory linkages. The accepted trade-off is that the destination index references children that may not exist in the destination — pulling an unselected platform returns `manifest unknown`, which is informative behaviour for users who explicitly opted in to a subset.

## Background

Today Harbor has filtering scattered across subsystems with limited dimensions:

- **Replication** (`src/pkg/reg/model/policy.go`, `src/pkg/reg/filter/`): closed-set filter chain with four types — `resource`, `name`, `tag`, `label`. Filters operate at fetch time on listing metadata only; nothing inspects manifest content. Issue #19864 (selective architecture replication, open since 2024) cannot be solved at this layer because architecture lives one level deeper than tag listing.
- **Proxy cache**: no per-content filtering exists today. PR #280 proposes adding a per-project `repository_filter` allowlist (regex / doublestar glob on repository names), scoped to repository names only and living inside proxy-cache code paths.
- **Manifest-list rewriting precedent**: `src/controller/proxy/manifestcache.go:109` (`updateManifestList`) walks a `*manifestlist.DeserializedManifestList`, filters children, and rebuilds via `manifestlist.FromDescriptors`. The pattern proves the primitives but lives in proxy-cache and handles only Docker manifest lists (returns "manifest list type unknown" for OCI image indexes).

Two adjacent feature requests — PR #280 and issue #19864 — point at a shared concern: filtering content based on a policy, along different dimensions. Implementing each ad-hoc duplicates effort and drifts in semantics. This proposal lands the smallest module that lets replication address #19864 cleanly, with hooks designed so PR #280 (or a successor) could plug in later without redesigning the abstraction.

## Proposal

### A small package: `pkg/contentfilter`

Public surface intentionally narrow for v1:

```go
package contentfilter

// Verdict for a single artifact / child.
type Decision int
const (
    Keep Decision = iota
    Drop
)

// Cost class — tells consumers when a predicate can be evaluated.
type CostClass int
const (
    PrePull  CostClass = iota // operates on listing data only (name, tag, label, type)
    PostPull                  // requires the manifest payload (platform)
)

// Subject is an opaque view of the artifact under evaluation.
type PreSubject struct {
    Repository string
    Tag        string
    Digest     string
    Type       string                       // "image", "chart", "cnab", ...
    Labels     []string
}

type PostSubject struct {
    PreSubject
    Manifest distribution.Manifest          // populated for PostPull predicates
    Platform *v1.Platform                   // populated when iterating manifest-list children
}

// Predicate interfaces are split to compile-enforce the cost class.
type PrePullPredicate interface {
    Evaluate(s PreSubject) Decision
    Spec() FilterSpec
}

type PostPullPredicate interface {
    Evaluate(s PostSubject) Decision
    Spec() FilterSpec
}

// Built-in predicates, v1:
func ByName(pattern string) PrePullPredicate
func ByTag(pattern string, exclude bool) PrePullPredicate
func ByLabel(labels []string, exclude bool) PrePullPredicate
func ByType(types []string) PrePullPredicate
func ByPlatform(platforms []string) PostPullPredicate   // os/arch[/variant], normalised via containerd/platforms

// Serialisation: a single JSON shape that DB / API speak.
type FilterSpec struct {
    Type  string          `json:"type"`              // "name", "tag", "label", "resource", "platform"
    Value json.RawMessage `json:"value,omitempty"`   // type-specific payload
}

// Build a predicate from its serialised spec.
func BuildPre(spec FilterSpec) (PrePullPredicate, error)
func BuildPost(spec FilterSpec) (PostPullPredicate, error)
```

Two interfaces (rather than one with an advisory `Cost()` method) compile-enforce the cost class, so a `PrePull` predicate cannot accidentally read `Subject.Manifest`. Inversion is expressed as a single `exclude bool` on each predicate, matching today's `Decoration: "matches" | "excludes"` semantics. **No `All`/`Any`/`Not` composition in v1** — consumers chain predicates as a flat AND list, which is exactly what today's replication filter chain already does.

Future predicates (`ByMediaType`, `BySignature`, `ByAnnotation`, etc.) can be added in additive PRs once a consumer concretely needs them.

### Consumer integration: replication

Today's `[]*model.Filter` chain in replication policies maps onto the new module: each existing filter type maps to one of the v1 predicates. A thin shim in `controller/replication/model/model.go` translates on read; existing stored JSON does not change. Issue #19864 introduces a fifth filter type, `platform`, which lands as `ByPlatform`.

### Manifest-list handling — no rewrite

When `ByPlatform` filters children of a manifest list / OCI image index, the parent manifest is **not rewritten**. The transfer engine:

1. Pulls the parent manifest from source.
2. For each child, evaluates `ByPlatform` against the child's `PostSubject`.
3. **Skips** the transfer of dropped children (their child manifest and blobs are never pulled).
4. **Pushes the original parent manifest unchanged** to the destination.

The destination's manifest list has the same digest as source and references children that exist (kept) and children that do not (dropped). Pulling the image at the destination on an unselected platform returns `manifest unknown` from the registry layer.

Why this design (vs rewriting):

- **Signature preservation**: list-level signatures (`sha256-<list-digest>.sig`) verify because the digest is unchanged. Per-arch signatures are unaffected either way.
- **Accessory model**: Harbor's accessory rows linking SBOMs / sigs / attestations to the parent are keyed by parent digest. Same digest both sides → linkages survive replication.
- **Idempotency**: source digest equals destination digest, so the existing `t.exist()` check in the transfer engine (`src/controller/replication/transfer/image/transfer.go:220`) works as-is.
- **OCI image-index gap closes itself**: rewriting requires building a new OCI index payload (a writer Harbor doesn't have today). Skip-children-but-keep-parent does not need a writer.
- **Implementation simplicity**: ~10 LOC delta in the transfer engine versus ~80 LOC for the rewrite path plus a deterministic-ordering helper plus an OCI-index writer.

### Per-arch signature replication

A separate concern that the don't-rewrite design does NOT solve for free: per-arch Cosign signatures are stored as separate tags `sha256-<child-digest>.sig` keyed to each child. Today's replication engine pulls accessories for the **tag the user selected**, via tag-pattern matching, NOT for transitively-touched child digests. With our filter, kept children are transferred as anonymous digests inside the manifest-list walk; their `.sig` tags would not get pulled, leading to silent loss of per-arch signatures at the destination.

The implementation MUST address this: for each kept child digest, the engine looks up `sha256-<child-digest>.sig` (and `.sbom`, `.att`) at the source registry and replicates them as accessories alongside the parent. This applies regardless of the don't-rewrite decision; it's a real implementation requirement called out here so it is not glossed over.

### Behaviour when local source is incomplete (event-based replication, proxy-cache origin)

If Harbor has acted as a proxy cache for `library/foo:v1` and only pulled `linux/amd64`, the local manifest list references `linux/arm64` etc. that aren't in this Harbor either. An event-based replication with a platform filter that requires children NOT locally present must NOT crash; the policy must be: **skip the requested-but-locally-missing platforms with a logged warning, transfer whichever requested platforms are locally present**. This matches the don't-rewrite spirit (best-effort, accept incomplete).

### Behaviour for GC and quota at the destination

A manifest list referencing missing child manifests is unusual. Behaviour to verify before merge:

- **GC**: does `controller/gc/` walking encounter a list with a missing child and (a) error, (b) skip, (c) treat as orphan? Phase 2 includes a verification test and adjustment if needed.
- **Quota**: artifact-size summing in `pkg/quota/` walks references. Missing children contribute zero. The destination's reported size for a partially-replicated multi-arch image will be lower than at the source. Phase 2 documents this.
- **`docker manifest inspect` on dst**: returns the full list including platforms not present. This is informative; `docker pull --platform` for a missing platform fails cleanly.

These items are captured in the Phase 2 verification checklist below, not assumed-OK.

## Non-Goals

- **Vulnerability-based filtering** (e.g. "do not replicate images with critical CVEs") — handled by scanner integration; out of scope.
- **Content trust enforcement** at filter time — full signature verification is a separate feature.
- **Cross-policy precedence rules** (denylist over allowlist, project policy over system policy). Same scoping decision as PR #280.
- **Retroactive policy migration** — existing replication policies keep working unchanged; new dimensions are opt-in.
- **Filter on dynamic state** (pull time, push time, pull count) — these belong with retention.
- **Manifest rewriting** (described and rejected in the proposal section).
- **Predicate composition** (`All` / `Any` / `Not`) — not in v1; flat AND-chain only.
- **Future predicates** (`ByMediaType`, `BySignature`, `ByAnnotation`, etc.) — not in v1; additive PRs once concrete consumers materialise.
- **Subsuming PR #280** — alignment is a future, co-designed step. v1 ships only the replication consumer.

## Rationale

### Why a small module now (instead of inlining the platform filter)

The platform filter could be inlined into replication code with no abstraction. The reason to introduce a module is forward-looking: PR #280's repository filter and tag-retention's filter language both clearly want a shared vocabulary. Spending ~200 LOC now on a narrow module avoids two parallel implementations later. The module is intentionally small enough that it cannot pre-determine a future consumer's design.

### Why don't-rewrite for platform filter

Signature-safe, simpler, idempotent, fewer registry-spec edge cases. The single accepted cost (dangling references for unselected platforms) is exactly what the user requested when they enabled the filter.

### Why not predicate composition (`All` / `Any` / `Not`) in v1

Today's replication filter chain is implicitly AND. PR #280 is a single regex. Tag retention has its own logic. None of the existing consumers ask for OR or NOT composition today. Building it speculatively means UI complexity, validation complexity, and forward-compat concerns for a feature with no concrete user. Add when a consumer asks.

### Alternatives considered

1. **Solve issue #19864 inline, no module** — add a `platform` filter type directly to replication's existing chain, no `pkg/contentfilter`. Pro: smallest possible change. Con: doesn't give PR #280 a clean alignment path, doesn't help future filter dimensions, leaves the manifest-list rewriting decision to be re-litigated.
2. **Rewrite the manifest list when filtering** — destination list contains only kept children, digest changes. Pro: clean destination, no dangling references. Con: breaks list-level signatures, requires OCI image-index writer (gap in Harbor today), requires deterministic ordering plus an exist-check fix or scheduled runs re-push every time. Rejected in favour of the don't-rewrite design.
3. **Full predicate framework now** (composition, ten predicates, advisory cost class) — rejected as premature; speculative scope without concrete second-consumer demand.

## Compatibility

- **Replication policies (existing)**: untouched. Existing filter types (`name`, `tag`, `label`, `resource`) keep working byte-for-byte; the shim translates them to the new predicate set on read. Stored JSON unchanged.
- **PR #280**: unaffected by this proposal in v1. Future alignment is a co-designed step, not a unilateral one.
- **API**: additive. `platform` joins the existing filter type enum. Old clients ignore unknown filter types (they already do for the four existing types when the field has unknown values).
- **Database**: no schema change for v1 — `platform` filters serialise into the existing `replication_policy.filters` JSON column alongside `name` / `tag` / `label`.
- **Job parameters** (replication): no new parameters in v1 — the platform filter is part of the policy's existing filter list, marshalled the same way.
- **Manifest list digests**: unchanged on both sides for filtered replications (don't-rewrite design). No GC churn, no consumer cache invalidation.
- **Forward-compatibility of predicate spec**: in the unlikely event v3.X adds a new predicate type, v2.X readers receive an unknown filter type. The shim falls closed (unknown filter = match nothing → policy effectively replicates nothing rather than silently widening). Documented in the spec.

## Implementation

### Phase 0 — Prerequisite: shared manifest-list walker (no new behaviour for proxy)

| # | Path | Change |
|---|---|---|
| 1 | `src/pkg/manifestlist/walker.go` (new) | Extract `controller/proxy/manifestcache.go:109` (`updateManifestList`) into a shared helper with predicate API. Walks Docker manifest lists. |
| 2 | `src/pkg/manifestlist/oci.go` (new) | Add OCI image-index walker (read-only). Currently `updateManifestList` falls through to the default path for OCI indexes. Phase 0 includes a behavioural test confirming the proxy-cache pre/post comparison for OCI indexes is acceptable (or, if it changes behaviour, the change is documented and approved as a fix). |
| 3 | `src/controller/proxy/manifestcache.go` | Refactor to call the new walker. Existing tests pass unchanged. |

Independently valuable; reviewable in isolation; lands first.

### Phase 1 — Content-filter module + replication consumer (issue #19864)

The module and its first consumer ship together so the module is shaped by a real user, not speculation.

| # | Path | Change |
|---|---|---|
| 1 | `src/pkg/contentfilter/types.go` | `PreSubject`, `PostSubject`, `PrePullPredicate`, `PostPullPredicate`, `Decision`, `CostClass`, `FilterSpec`. |
| 2 | `src/pkg/contentfilter/predicates.go` | `ByName`, `ByTag`, `ByLabel`, `ByType`, `ByPlatform`. |
| 3 | `src/pkg/contentfilter/spec.go` | `BuildPre`, `BuildPost`; round-trip tests; "unknown type fails closed" coverage. |
| 4 | `src/pkg/contentfilter/*_test.go` | Predicate-by-predicate unit tests. |
| 5 | `src/go.mod` | Promote `github.com/containerd/platforms` to a direct dependency. |
| 6 | `src/controller/replication/model/model.go` | Shim translating existing filter chain into the new module's predicates on read. No stored JSON change. Add `platform` as a fifth filter type. |
| 7 | `src/controller/replication/transfer/image/transfer.go` | When iterating manifest-list children: evaluate the post-pull predicate per child; **skip transfer for dropped children**; push the original parent manifest unchanged. ~10 LOC delta on the existing flow. |
| 8 | Same file, accessory lookup | For each kept child digest, replicate `sha256-<digest>.sig`, `.sbom`, `.att` accessory tags from source. This closes the per-arch signature gap. Existing accessory replication logic in `pkg/replication/` is the right place to reuse. |
| 9 | `api/v2.0/swagger.yaml` | Document `platform` filter type. |
| 10 | UI — `create-edit-rule.component.ts/html` | Extend the existing filter UI with a "platform" type. Multi-chip selection (`linux/amd64`, `linux/arm64`, ...). |
| 11 | `tests/testcases/Group7-Replication/` | DockerHub → Harbor, `library/php` (real OCI image index), platform = `linux/amd64,linux/arm64`. Verify destination index digest equals source, only kept children's blobs transferred, per-arch signature pulls on destination still verify, idempotency (second run no-ops). |

### Phase 1 verification checklist (must complete before merge)

- [ ] Per-arch Cosign signatures for kept children land at destination (no silent loss).
- [ ] List-level Cosign signature still verifies at destination (digest unchanged).
- [ ] Harbor GC walking a list with missing child references behaves correctly (no error, no orphan, no infinite loop). If the current GC behaviour is wrong here, fix or document.
- [ ] Harbor quota reports a sensible size for partially-replicated multi-arch images. If it errors or reports zero, fix or document.
- [ ] Harbor UI artifact-detail page renders the partial manifest list without errors.
- [ ] Idempotency: a second run of the same filtered replication is a complete no-op.
- [ ] Locally-incomplete source (proxy-cache origin) with a platform filter that requests a missing platform → skip with warning, no crash.

### Phase 2 — Proxy cache and additional dimensions (future, co-designed)

Out of scope for this proposal; tracked as a future follow-up. Co-design with PR #280's author when the time comes.

## Open issues

1. **Naming**: `contentfilter` vs `artifactfilter` vs `manifestfilter`. Settle in review.
2. **Where the shared manifest-list helper lives**: `pkg/manifestlist/`, `pkg/registry/manifestlist/`, or `pkg/contentfilter/internal/`. Cosmetic; pick once and stick.
3. **Feature flag**: should v1 ship behind a `content_filter_enabled` config flag for cautious rollout, or rely on the opt-in nature of adding a `platform` filter to a policy as sufficient gating? Recommended: no flag, rely on opt-in.
4. **Pre-pull / post-pull plumbing**: implement the cost-split now (cleaner, future-friendly) or only when a consumer benefits from skipping manifest pulls? Recommended: implement now via the two-interface design — it's compile-enforced, low cost.
5. **Backfill of existing policies**: do we eagerly translate existing `[]*model.Filter` chains to the new spec on next save, or lazily on read forever? Recommended: lazy. Legacy chain stays as-is, new dimensions go into the same chain via the new `platform` type.
