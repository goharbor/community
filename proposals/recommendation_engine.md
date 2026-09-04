# Proposal: Image Optimization & Recommendation Engine

Author: [`Hanna Czifrus`](https://github.com/czifrushanna)
Discussion: None

## Abstract

This proposal introduces a pluggable optimization engine for Harbor that turns an
artifact's reconstructed Dockerfile and vulnerability scan results into a concrete,
LLM-generated improvement: an optimized Dockerfile the user can review, edit, and
build. The engine follows Harbor's existing scanner adapter model: Harbor
defines a stable REST contract for requesting an optimization and retrieving the
result, while the optimization logic itself runs in an independently deployed
adapter service.

The proposal accordingly has two clearly separated deliverables:

1. **Changes to Harbor itself** — the adapter contract, orchestration,
   persistence, and UI. All of it is adapter-agnostic; Harbor never contains
   optimization logic, LLM calls, or model/prompt configuration.
2. **A reference optimizer adapter, "Sleeko"** — an independent service in its
   own repository that implements the contract. It is not part of Harbor: it has
   no Go dependency on Harbor, is deployed separately, and could be replaced by
   any other adapter implementing the same contract.

## Background

Container images change over time, and the quality of an image can degrade as base
layers age, vulnerabilities accumulate, and build practices drift. Harbor already
stores the data needed to understand an image — including, since BuildKit adoption
became widespread, a provenance attestation that can embed the original Dockerfile
used to build it — but the raw scan findings and metadata are not always easy to
translate into a practical remediation plan.

Today, a user often needs to manually interpret scan output, compare alternative
base images, and decide how to improve the artifact. That makes image hardening
inconsistent and slow, especially for teams that manage many repositories or lack
deep container security expertise.

## Proposal

The proposal is to add an optimization workflow that reconstructs an image's
Dockerfile and returns an LLM-optimized version informed by the image's
vulnerability scan results.

At a high level, the workflow is (each step labeled with the side that performs
it):

1. **Harbor:** from an artifact's detail page, the user requests an optimization.
   Harbor creates a single-use, project-scoped robot account (pull + scanner-pull
   permissions, so the vulnerability-blocking pull policy does not get in the way)
   and looks up the artifact's most recent completed vulnerability scan report.
2. **Harbor:** the optimizer controller submits the request to the registered
   optimizer adapter over a stable REST contract (`POST /api/v1/optimize`,
   mirroring the `metadata` / capability-negotiation / report-polling shape Harbor
   already uses for scanner adapters), passing the registry connection details,
   the artifact reference, and the raw scan report JSON.
3. **Adapter:** it pulls the artifact and reconstructs its Dockerfile. It first
   looks for a BuildKit provenance attestation embedded in the OCI index and
   decodes the original Dockerfile from it; if no attestation is present (the
   image was not built with BuildKit, or was re-pushed without one), it falls
   back to reconstructing a best-effort Dockerfile from the image's own
   config/layer history.
4. **Adapter:** it requires a completed vulnerability scan report before
   proceeding — without one it returns a terminal `NO_SCAN_REPORT` error asking
   the user to scan first, rather than optimizing blind. With a report in hand,
   it sends the recovered Dockerfile together with a condensed form of the scan
   report to an operator-configured LLM gateway and returns the optimized
   Dockerfile.
5. **Harbor:** it persists the original and optimized Dockerfile, and the
   artifact's "Optimize" tab polls for and displays them side by side. The user
   can edit the optimized Dockerfile in place, download it, or copy a ready-made
   `docker buildx build --push --provenance=mode=max ...` command. Harbor does
   not build or push the resulting image itself — it has no access to the
   original build context — so producing the final image is left to the user.

Steps 3 and 4 describe the reference adapter; the contract only requires an
adapter to accept the request and eventually produce an optimization report.
Everything Harbor-side is blind to how the optimization is computed.

The vulnerability scan report is the only structured signal wired into the
optimization today. Other Harbor metadata, such as runtime usage signals, is not
yet part of the request, but the adapter contract has room to add such fields as
inputs mature; see Future Work.

## Non-Goals

- Automatically replacing user-owned images without review
- Building or pushing the optimized image on Harbor's behalf — Harbor offers a
  download and a copy-ready build command, but the user runs the build
- Enforcing recommendations as a policy gate
- Defining the internal implementation of any external optimizer adapter
- Replacing Harbor's existing vulnerability scanning workflow
- Building a Harbor-specific model training pipeline in this proposal
- Modeling optimization targets (vulnerability remediation, base image selection,
  etc.) as separately trackable recommendation types — today they are whatever the
  deployed prompt asks the LLM to address in one pass

## Rationale

A pluggable model is a better fit than a built-in optimization service because it
keeps the Harbor core focused on orchestration and user experience, while allowing
optimization logic to evolve independently. This is the same reasoning Harbor
already applied to vulnerability scanning, and the optimizer adapter contract
deliberately reuses that architecture — registration storage, capability
negotiation via consumed/produced MIME types, single-use robot accounts for
registry pulls, and async job polling all mirror the scanner adapter framework.

This approach has a few advantages:

- Harbor can support multiple optimizer adapters over time, the same way it
  supports multiple scanners, without changing the core integration.
- Operators can choose the adapter, LLM gateway, model, and prompt that best fit
  their environment, compliance requirements, or cost constraints — none of these
  are baked into the Harbor binary or wired in as defaults; they are supplied at
  deploy time (see Implementation).
- The optimization logic can be improved, swapped, or retrained without requiring
  a Harbor release.
- The design stays aligned with Harbor's existing pluggable scanner architecture,
  reducing the amount of genuinely new machinery Harbor core has to carry.

## Compatibility

The Harbor-side changes are additive. Existing Harbor scanning, artifact
browsing, and policy workflows continue to work unchanged when the feature is
disabled (no `WITH_SLEEKO` core env var, no optimizer registration).

The optimization engine is exposed as an optional feature: the "Optimize" tab and
its API surface only become active once an optimizer adapter is registered, and
requesting an optimization does not affect image push, pull, scan, or replication
behavior.

Optimization results are stored in a dedicated `dockerfile_optimization` table
(repository, digest, original/optimized Dockerfile, attestation digests, status,
error, a `generated` flag distinguishing best-effort config-history
reconstructions from Dockerfiles extracted verbatim from provenance, and the
owning registration and execution IDs), separate from scan and artifact tables,
so schema evolution here does not affect other Harbor data.

## Implementation

### Changes to Harbor itself

Everything in this subsection lands in the Harbor codebase and is
adapter-agnostic — no optimization logic, LLM call, or model/prompt
configuration exists anywhere in Harbor.

1. **Provider contract** (`src/pkg/optimizer/rest/v1`): a versioned REST API —
   `GET /api/v1/metadata` for capability negotiation, `POST /api/v1/optimize` to
   submit a request, `GET /api/v1/optimize/{id}/report` to poll for the result —
   with dedicated `application/vnd.harbor.optimizer.*` MIME types. Harbor core owns
   registration storage and management (`src/pkg/optimizer`,
   `src/controller/optimizer`), analogous to `src/pkg/scan`: registrations are
   CRUD-able through the v2.0 API, one can be marked default, and adapters are
   pinged and capability-checked before a request is dispatched.
2. **Orchestration and persistence**: the optimizer controller creates a
   single-use project robot account, fetches the artifact's completed
   vulnerability scan report, and launches a jobservice job that calls the
   adapter and persists the returned report via
   `src/pkg/dockerfileoptimization` (the `dockerfile_optimization` table — see
   Compatibility).
3. **Portal**: an "Optimize" tab on the artifact detail page
   (`artifact-additions/dockerfile-optimization`) that triggers the request,
   polls every few seconds, and renders the original/optimized comparison with
   edit, download, and copy-build-command actions. When no optimizer adapter is
   available the Optimize button is hidden and the tab explains why instead of
   offering an action that would fail; adapter registration itself is managed
   from the existing Interrogation Services section of the portal, alongside
   scanners.
4. **Optional auto-registration**: the only place the reference adapter's name
   appears in Harbor is a deploy-time convenience — with `WITH_SLEEKO=true`,
   core auto-registers an immutable default registration pointing at
   `SLEEKO_ADAPTER_URL`, exactly the way `WITH_TRIVY` auto-registers the
   default scanner. Without it, adapters are registered manually through the
   API/portal like any scanner.

### The reference adapter ("Sleeko"), separate from Harbor

Sleeko is a standalone Go service in its own repository and module
(`github.com/czifrushanna/sleeko`), with its own build/deploy loop, decoupled
from the harbor-core/jobservice release cycle, and with no Go dependency on
Harbor. It started out inside this Harbor fork and was split out — see
Rationale. Nothing in this subsection changes Harbor; any other adapter
implementing the contract could take its place.

- **Wire contract mirror**: `sleeko/pkg/api/v1/` mirrors the Harbor-side
  contract (`src/pkg/optimizer/rest/v1/`) in shape, kept in sync by hand across
  the two repositories rather than shared code — see Open issues.
- **Optimization approach**: a single LLM call against an OpenAI-compatible
  gateway. The recovered Dockerfile and the scan report are sent together in
  one prompt, and the operator-supplied prompt text determines which concerns
  (vulnerability remediation, base image choice, version/dependency updates,
  general hardening) the model is asked to address. A full scan report for a
  real base image is larger than an LLM context window, so the adapter first
  condenses it to a per-package summary — fixable vulnerabilities grouped by
  the package an edit would touch, unfixable ones collapsed into a single
  counted line — and fits the whole prompt into a configured
  context-window/completion-token budget, dropping the lowest-severity
  packages last and stating how many were dropped. A ranking stage and
  retrieval augmentation are planned but not implemented — see Future Work.
- **Configuration**: the LLM gateway URL, API key, and model come from a
  Secret; none of these ship with a baked-in default, so the adapter refuses
  to start without them, and which gateway and model are used is decided
  entirely at deploy time. The instruction prompt does ship with a built-in
  default embedded in the adapter binary, tuned to the exact format the
  condensed scan summary is rendered in and to the pipeline's known failure
  modes (hallucinated fix versions, invented `COPY` paths, dropped `RUN`
  lines in a history-reconstructed Dockerfile); operators can override it
  entirely via a ConfigMap (`sleeko.optimizerPrompt` in the Helm chart), but
  are no longer required to supply one.
- **Deployment**: rather than standalone manifests, the adapter is folded into
  a fork of the official Harbor Helm chart — currently vendored in the adapter
  repository as `sleeko/chart/`, a temporary arrangement (see Open issues) —
  as a first-class component, the same way Trivy is, with its own
  Deployment/Service template and a `sleeko:` values block; enabling it on an
  existing Harbor install is a single `helm upgrade` against that fork with
  `sleeko.enabled=true` and the LLM gateway values set, deploying core,
  jobservice, registry, and the adapter together.

## Future Work

- **Ranking/classification stage** *(adapter-side)*. Add a lightweight model
  step ahead of generation that determines which optimization tasks
  (vulnerability remediation, base image swap, dependency updates, hardening,
  …) actually apply to a given image, rather than leaving that entirely to the
  prompt sent to the LLM in a single call. Needs no Harbor change.
- **Retrieval-augmented generation** *(adapter-side)*. Let the generation step
  draw on external knowledge (e.g. known-good base images, CVE remediation
  databases) instead of relying solely on the LLM's parametric knowledge.
  Needs no Harbor change.
- **Runtime usage signals as input** *(Harbor + contract)*. Extend the
  optimization request with signals such as observed runtime behavior, so
  recommendations can account for how an image is actually used, not just its
  build history and scan results. Harbor would supply the signal and the
  contract has room to carry such fields as they mature.
- **Multi-adapter selection in the UI** *(Harbor-side)*. The registration
  model already supports multiple optimizer adapters, but today only one
  ("Sleeko") is auto-registered and exercised end-to-end; letting users choose
  among several registered adapters from the portal has not been built or
  tested.

## Open issues

- **Contract kept in sync by hand across two repositories** *(the
  Harbor/adapter boundary)*. Now that the reference adapter lives in its own
  repository, the wire contract (`src/pkg/optimizer/rest/v1/` in this repo,
  mirrored as `sleeko/pkg/api/v1/` in the adapter's) is duplicated by hand
  rather than shared or generated from a single spec. This is workable for one
  adapter but does not scale well as more adapters are written against the
  contract; a shared schema (e.g. OpenAPI, the way the scanner adapter contract
  could eventually adopt one) is worth revisiting.
- **Single adapter replica** *(adapter-side)*. The reference adapter keeps
  in-flight optimization jobs in memory and is deployed with `replicas: 1` by
  design; running more than one replica would drop or duplicate in-flight jobs.
  Scaling out requires moving the job store to something shared (e.g. Redis)
  first.
- **Helm chart fork is temporarily vendored in the adapter repository**
  *(adapter-side)*. The fork of harbor-helm that carries the `sleeko` component
  lives inside the adapter repository (`sleeko/chart/`) purely for convenience
  while sleeko is under testing; once it stabilizes, the chart will move to a
  properly maintained standalone fork of harbor-helm.
- **Reference adapter has no CI pipeline of its own yet** *(adapter-side)*.
  This repository has a tag-triggered pipeline that builds and pushes its core,
  jobservice, and portal images, but building and pushing the adapter image is
  still a manual step; the adapter repository needs an equivalent pipeline of
  its own.
