# Proposal: Replace Harbor Internal Redis with Valkey

Author: [Chenyu Zhang](https://github.com/chlins)

## Abstract

Harbor currently depends on Redis in both its implementation and its packaged deployment artifacts. The project ships an internal `redis-photon` image for docker-compose and uses the same image as the default internal cache backend in `harbor-helm`. This proposal replaces Harbor's bundled Redis runtime with Valkey in a phased manner. Phase 1 is intentionally minimal: the base package installed inside the image is switched from `redis` to `valkey` (via tdnf), the produced image is renamed to `goharbor/valkey-photon`, and the corresponding image build directory and Makefile targets in the Harbor source tree are renamed accordingly so that the build layout matches the new image name. All user-facing configuration keys, service names, environment variables, secret names, URL schemes, and on-disk layouts remain unchanged so that upgrades stay compatible and low-risk. Phase 2 is scoped as future work covering deeper terminology cleanup in templates and Go code, generalization of `redis` naming in compose/helm, and a refactor of Harbor's Redis client dependencies toward Valkey's official SDK.

## Background

Harbor still has an explicit Redis footprint across code, packaging, and documentation:

- Harbor's architecture documentation describes Redis as the key-value store used for cache and temporary job metadata.
- The Harbor source tree builds and publishes a bundled `goharbor/redis-photon` image for internal deployments.
- The offline installer and docker-compose templates still start an internal `redis` service backed by `goharbor/redis-photon`.
- `harbor-helm` defaults `redis.internal.image.repository` to `docker.io/goharbor/redis-photon`.
- Harbor code connects through standard Redis-compatible clients and URLs such as `redis://`, `rediss://`, `redis+sentinel://`, and `rediss+sentinel://`.
- Jobservice uses [`gocraft/work`](https://github.com/gocraft/work), which is built on top of the `redigo` Redis client.
- The Trivy adapter and the upstream `distribution` registry both pull in their own Redis client dependencies.

### Why move from Redis to Valkey

In March 2024, Redis Inc. relicensed Redis from the permissive BSD-3-Clause license to a dual-license model under the Redis Source Available License v2 (RSALv2) and the Server Side Public License v1 (SSPLv1), starting with Redis 7.4 ([Redis license announcement](https://redis.io/blog/redis-adopts-dual-source-available-licensing/)). Neither RSALv2 nor SSPLv1 is recognized as an OSI-approved open source license, which introduces redistribution and downstream-packaging concerns for projects like Harbor that ship a bundled Redis image as part of their installer and helm chart. Continuing to depend on the upstream Redis runtime would tie Harbor's release artifacts to a license whose long-term implications for vendoring, redistribution by partners, and inclusion in downstream commercial distributions are unclear.

In response to that license change, the Linux Foundation launched Valkey on March 28, 2024 as a community-driven, BSD-3-Clause fork of Redis 7.2.4 ([Linux Foundation announcement](https://www.linuxfoundation.org/press/linux-foundation-launches-open-source-valkey-community)). Valkey is actively maintained under open governance with engineering investment from multiple independent vendors, including AWS, Google Cloud, Oracle, Ericsson, and Snap, which reduces single-vendor risk and aligns with the same community model that Harbor itself follows as a CNCF project. The project is also iterating quickly on a public roadmap covering more reliable cluster slot migration, multi-threaded performance improvements, vector search, new commands, and other features that are expected to deliver better performance and capabilities than the Redis 7.2 line over time.

This makes Harbor a good candidate for a phased Redis-to-Valkey migration: replace the bundled runtime first with the smallest possible diff, keep the client-facing configuration and code structure stable, and only then consider terminology cleanup and SDK-level refactors.

## Proposal

### Summary

Harbor should adopt Valkey as the internal in-memory datastore for bundled deployments. The first phase changes only what is strictly necessary to swap the runtime binary and rename the resulting image. All deeper renames, template restructurings, and SDK migrations are deferred to a clearly separated second phase.

### Scope

The proposal covers:

- Harbor source build and release artifacts for the internal cache image
- Offline installer and docker-compose deployment templates
- `harbor-helm` default internal cache image
- Documentation and compatibility statements for external Valkey
- A future-work plan for terminology cleanup and Redis SDK replacement

The proposal does not require any user-visible configuration rename in phase 1.

---

## Phase 1: Minimal runtime swap (this release)

Phase 1 is deliberately scoped as the smallest change set that produces a Valkey-backed internal image while preserving 100% of the existing surface area.

### 1.1 Image build change

In the existing Redis image build (the directory and Dockerfile that today produces `goharbor/redis-photon`), the functional changes are:

- Replace the `tdnf install redis` invocation with `tdnf install valkey` (and the corresponding binary/entrypoint references that are required for the image to start, e.g. `valkey-server` instead of `redis-server`).
- Rename the produced image tag from `goharbor/redis-photon` to `goharbor/valkey-photon`.

### 1.2 Build directory and Makefile rename

To keep the source tree consistent with the new image name, Phase 1 also renames the build layout for this image:

- Rename the image build directory from `make/photon/redis/` to `make/photon/valkey/`.
- Rename the Makefile targets, variables, and internal build labels that produce this image from `redis`-based names (e.g. `_build_redis`) to their `valkey` equivalents (e.g. `_build_valkey`).
- Update any CI workflow references, image-list manifests, and prepare/installer scripts that enumerate the `redis-photon` image or its build target so they point at the new directory and target names.

This rename is scoped strictly to the image build and packaging plumbing. It does **not** touch Go package names, runtime configuration keys, or deployment templates beyond switching the image reference (covered in section 1.3 and 1.4).

Explicitly **not changed in phase 1**:

- The container's configuration file paths, data directory paths, default port, user, and entrypoint layout stay as-is (Valkey is configured to behave like the previous Redis container so existing volumes and configs continue to work).
- Any `redis.conf`-style config file inside the image keeps its current name and location.
- Go package names, comments, log messages, and metric labels in Harbor source code that reference `redis`.

The intent is that operators upgrading to this release see only two observable runtime differences: the image name has changed to `valkey-photon`, and the process inside the container is `valkey-server`. Contributors building Harbor from source will additionally see that the image build now lives under `make/photon/valkey/` and is produced by `valkey`-named Makefile targets.

### 1.3 docker-compose / installer template change

- Update the docker-compose templates and the offline installer manifests so that every reference to `goharbor/redis-photon:<tag>` becomes `goharbor/valkey-photon:<tag>`.
- The compose service name (`redis`), the container name, the mounted volume names, the mounted config paths, the exposed port, the env var names (including `REDIS_PASSWORD`), and the dependency wiring of other services (`core`, `jobservice`, `registry`, `trivy-adapter`, etc.) all remain unchanged.
- Offline installer packaging is updated to save and publish the new `valkey-photon` image instead of `redis-photon`.

### 1.4 harbor-helm change

- Change only the default value of `redis.internal.image.repository` from `docker.io/goharbor/redis-photon` to `docker.io/goharbor/valkey-photon`.
- All helm values paths (`redis.*`, `redis.internal.*`, `redis.external.*`), secret keys, template file names, and rendered Kubernetes object names (Service, StatefulSet, Secret, ConfigMap) remain unchanged.
- Existing user overrides of `redis.*` values keep working without modification.

### 1.5 What stays compatible in phase 1

Phase 1 explicitly preserves:

- `redis` and `external_redis` blocks in `harbor.yml`
- `redis.*` values in `harbor-helm`
- `redis://`, `rediss://`, `redis+sentinel://`, and `rediss+sentinel://` URL schemes
- existing env var names and secret keys such as `REDIS_PASSWORD`
- Harbor's current Redis client libraries and code paths (no SDK swap)
- on-disk data directory layout for the bundled internal cache

### 1.6 Phase 1 test plan

- Fresh install with internal Valkey via docker-compose.
- Fresh install with internal Valkey via helm.
- In-place upgrade from a prior Harbor release that used internal `redis-photon`, reusing the existing data volume.
- Harbor connected to an external standalone Valkey through the existing `redis://` configuration.
- Harbor connected to an external Valkey Sentinel through the existing `redis+sentinel://` configuration.
- Harbor connected to an external TLS-enabled Valkey through the existing `rediss://` configuration.

---

## Phase 2: Future work (not part of this release)

Phase 2 is intentionally not required for the first delivery. It is listed here so that the long-term direction is explicit and so that future proposals can refine each item independently.

### 2.1 Deeper source-tree terminology cleanup

- Update internal Go package names, comments, log messages, and metric labels where the term `redis` is used purely as a branding term rather than as a protocol identifier.
- Consider further generalizing the image build directory name (e.g. `make/photon/valkey/` → `make/photon/cache/`) if the chart/compose generalization in §2.2 lands.
- Coordinate these renames with documentation updates so that contributor docs and architecture diagrams reflect the new naming.

### 2.2 Restructure docker-compose templates and helm chart to use a generic name

- Replace the `redis` service name in docker-compose with a backend-neutral name such as `cache` (or `valkey`), and update every dependent service's wiring accordingly.
- In `harbor-helm`, introduce a backend-neutral values path (for example `cache.*`) for the internal datastore, while keeping the legacy `redis.*` path working as a deprecated alias for at least one release to give users a migration window.
- Rename rendered Kubernetes objects (Service, StatefulSet, Secret, ConfigMap) and environment variables (e.g. `REDIS_PASSWORD` → `CACHE_PASSWORD`) behind the same deprecation policy.
- Provide a documented upgrade guide and, where feasible, automated migration helpers (for example, a chart hook that copies legacy secrets to the new names).

### 2.3 Refactor Harbor's Redis client dependencies toward Valkey SDKs

Because Valkey and Redis have now forked and will diverge over time, relying on Redis-branded client libraries indefinitely is a long-term integration risk. Phase 2 should refactor Harbor's in-tree dependencies, in priority order:

1. **Core / common cache layer**: migrate Harbor's primary Redis client usage to Valkey's official Go SDK ([`valkey-io/valkey-go`](https://github.com/valkey-io/valkey-go)), behind Harbor's existing cache abstraction so call sites do not have to change.
2. **Jobservice queue (`gocraft/work`)**: `gocraft/work` is unmaintained and tightly coupled to `redigo`. Phase 2 should evaluate either (a) forking and porting `gocraft/work` to a Valkey-compatible client, or (b) replacing the queue layer with an alternative that natively supports Valkey while preserving Harbor's existing job semantics (periodic jobs, retries, dead jobs, statistics).
3. **Trivy adapter**: replace the Redis client dependency used by the Trivy adapter for its job queue and cache with a Valkey-compatible client, coordinating with the upstream project where appropriate.
4. **Distribution (registry) Redis dependency**: the upstream `distribution` registry pulls in its own Redis client. Phase 2 should track upstream Valkey support and, if necessary, contribute a Valkey backend upstream rather than carrying a long-lived Harbor-side fork.

This refactor is high-risk and must be split into its own proposal(s) with a dedicated test plan, performance comparison, and rollback strategy. It is explicitly out of scope for the phase 1 release.

---

## Non-Goals

- Renaming any `redis` user-facing config key, env var, or secret key in phase 1.
- Renaming Go package paths or in-code identifiers that reference `redis` in phase 1.
- Adding support for Valkey Cluster if Harbor does not already support Redis Cluster semantics.
- Reworking Harbor's cache or jobservice architecture in phase 1.
- Changing Harbor's Redis client libraries in phase 1 (deferred to phase 2).

## Rationale

### Why keep phase 1 to a runtime swap plus build-layout rename

The current user pain is operational: Harbor ships a `redis-photon` runtime that is no longer the maintained upstream. Swapping the installed package to `valkey`, renaming the produced image to `valkey-photon`, and aligning the source-tree build directory and Makefile targets to match the new image name directly addresses that pain with a near-zero user-facing blast radius. Every other piece of Harbor's deployment (compose service names, helm values, env vars, secrets, on-disk paths, runtime code) keeps working unchanged, so existing installations, automation, GitOps repositories, and chart overrides do not need to be touched in this release. The build-layout rename is included in Phase 1 because leaving a directory called `make/photon/redis/` that produces an image called `valkey-photon` would be actively confusing for contributors and CI maintainers.

### Why split terminology cleanup and SDK migration into phase 2

Bundling a runtime swap, a global terminology rename, and a client-library refactor into one release would:

- break helm values for every existing installation,
- force coordinated changes in offline installer automation,
- require migration logic for secret names and URL schemes,
- expand the review surface across Harbor, chart, docs, and automation simultaneously,
- and introduce client-library risk (latency, semantics, edge cases) at the same time as a runtime change, making regressions hard to attribute.

Splitting these concerns lets each phase be reviewed, tested, and rolled back independently.

## Compatibility

### Runtime compatibility

Harbor's current Redis usage relies on standard Redis-compatible clients and features, and Valkey documents compatibility with Redis OSS 7.2 and earlier, including Sentinel. Phase 1 therefore expects Valkey to be a drop-in backend for Harbor's existing client code paths.

### Configuration compatibility

Phase 1 preserves:

- existing `harbor.yml` keys
- existing helm values paths
- existing Redis URL schemes
- existing secret key names
- existing env var names
- existing on-disk data directory layout

Users should not need to rewrite any configuration to adopt the phase 1 release.

### Upgrade compatibility

There are two upgrade dimensions:

- Harbor package upgrade with internal datastore replacement (handled by phase 1; the image is swapped but the data directory and config layout are preserved).
- Customer migration from external Redis to external Valkey (handled by Valkey's documented compatibility with Redis OSS 7.2 and earlier).

Harbor must validate whether the currently shipped `redis-photon` version falls inside Valkey's supported migration window before promising in-place reuse of the existing data directory. If it does not, Harbor must document a release-note caveat or provide a logical migration path.
