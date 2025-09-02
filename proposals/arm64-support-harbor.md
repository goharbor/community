# Proposal: Arm64 Support and Multi-Architecture Image Publishing for Harbor

Author: Rani Chowdary Mandepudi, Arm (@ranimandepudi)

Discussion: https://github.com/goharbor/harbor/pull/22229/files

## Abstract

This proposal introduces native Arm64 support and multi-architecture image publishing for all Harbor components. The goal is to enable Harbor to run natively on Arm64 hardware, align with CNCF best practices, and enhance Harbor's portability across modern infrastructure environments.

## Background

Harbor is a popular cloud-native container registry. While it provides full-featured registry services, its official builds and Docker images target only the Amd64 architecture. The growing adoption of Arm64 in cloud-native and edge computing environments has created demand for native Arm64 support.

Currently, deploying Harbor on Arm64 requires emulation or custom builds, reducing performance and maintainability.

## Proposal

Note: This proposal introduces no changes to Harbor’s core functionality. It adds support for additional architectures while keeping existing behavior unchanged.

All Harbor component images have been built and tagged for the Arm64 architecture. These images have been pushed to my DockerHub repository under the namespace ranichowdary/ (replacing the original goharbor/ namespace) for testing and validation purposes. Once the review is complete, the image names can be reverted to the original naming convention.

Additionally, the Dockerfile paths and image naming conventions have been modified to support multi-architecture builds. This ensures compatibility and seamless operation on both x86 and Arm64 platforms using the same codebase and Docker images.

These changes allow Harbor to be built, packaged, and installed cleanly on Arm64 hosts such as AWS Graviton and also on x86 as images are multi arch. 

This proposal introduces native Arm64 builds for Harbor components using `Docker Build` and multi-architecture manifests. Each image is tested and published in a way that maintains compatibility with existing Amd64-based deployments.

This proposal does not alter Harbor’s functionality. It extends the build and release process so every Harbor component is published as a multi-architecture image (amd64 + arm64) under the official goharbor/* namespace.

During development and testing, prototype images were published under ranichowdary/* for validation. For upstream adoption, all images will use the official goharbor/* repositories.

## Design Goals

Build Harbor component images (core, jobservice, registryctl, etc.) for both Arm64 and Amd64 using native compilation per architecture and multi-arch manifest merging.

Published multi-arch images to Docker Hub using unified manifest lists, enabling transparent arch-specific pulls without impacting existing deployments.

Supported native and cross-platform builds via docker buildx and architecture-specific runners.

Ensure deterministic and repeatable builds across architectures using consistent Makefile targets and validated build.

Provide documentation for Arm64 validation, and plan to publish a learning path on learn.arm.com post-upstreaming.

Integrate Arm64 builds into Harbor’s CI and release workflows using GitHub Actions. This will require coordination with Harbor maintainers—I’m happy to assist or contribute directly as needed.

## Development Phases

To reduce risk and ensure stability, we propose a phased approach:

Phase 1 – Code Implementation & CI Enablement
	•	Add ARCH support to Makefiles, builder scripts, and Dockerfiles.
	•	Enable GitHub Actions matrix to build/test on both amd64 and arm64 runners.
	•	Validate that unit tests, API tests, and UI tests pass consistently on both platforms.
	•	Deliverable: CI green for both architectures; no user-facing image changes yet.

Phase 2 – Image Publishing & Installers
	•	Publish official Harbor component images to Docker Hub under goharbor/* with multi-arch manifests.
    - Offline installers may be published either per-arch bundles or a single combined bundle depending on community size and storage considerations
	•	Ensure the unified tag (e.g. goharbor/harbor-core:vX.Y.Z) automatically resolves to the correct variant.
	•	Update online installer (docker-compose) and offline installer packages to use these multi-arch tags.
	•	Deliverable: Users can docker pull goharbor/harbor-core:vX.Y.Z on amd64 or arm64 and get a native image.

Phase 3 – Helm Chart Validation
	•	Validate Harbor Helm chart installs and upgrades correctly on both amd64 and arm64 Kubernetes clusters.
	•	Confirm that all hooks, jobs, and init containers reference multi-arch images.
	•	Publish chart updates if needed.
	•	Deliverable: helm install harbor works seamlessly across architectures.

## Architecture Parameter:

![Harbor Multi-Arch Design](images/arm64/harbor-multiarch-arm64-amd64.png)

For Go components (core,jobservice, registryctl): ARCH - GOARCH - compile - image build.
For binary-only components(Trivy, Trivy Adapter): ARCH - Dockerfile.binary - fetch correct binary

ARCH(amd64| arm64) >> make build -e ARCH = arm64/amd64 >> _build_trivy >> builder.sh(receives ARCH >> docker build (ARG TARGETARCH=arm64 >> Dockerfile.binary (downloads the correct binary)))

This ensures a unified codebase, with arch-specific logic only where strictly required.

## Binary Dependencies:
As part of this work, we identified Harbor’s external binary dependencies and confirmed Arm64 support:
	•	Trivy: arm64 releases available upstream.
	•	Trivy Adapter: requires both Trivy (downloaded upstream) and the adapter binary (built from source with GOARCH).
	•	Helm (migrate-chart tool): must dynamically fetch the correct arch binary (current Dockerfile hardcodes linux-amd64).
	•	Spectral: already provides amd64/arm64 binaries.
	•	Node.js, Python deps: validated during e2e runs; no arch-specific blockers found.

This inventory ensures all required binaries are reproducible on both architectures.

## CI changes: 

	•	CI matrix: Every PR runs unit, API, and UI tests on both amd64 and arm64 runners.
	•	Build pipeline:
	•	Per-arch images pushed as goharbor/<component>:<tag>-amd64 / -arm64.
	•	Final multi-arch tag created only after both builds succeed (docker buildx or docker manifest create).
	•	Installers: Online/offline installers reference unified tags (:<tag>), so users don’t need to specify an arch suffix.
	•	Release sequencing: CI ensures manifests are published only once both builds complete (job dependencies).

Multi Arch CI integration on Harbor:

Objective: 
To ensure Harbor's CI system validates code changes across both amd64 and arm64 architectures for pull requests. This enhancement guarantees feature compatibility and stability on both platforms.

Changes: 
* CI.yml (example)

This file defines main test matrix for harbor on pull requests and pushes. Ensure that Harbor's CI pipeline executed on both arm64 and amd64 architectures for every PR or push
  * Enabled Matrix strategy for Architecture: Before jobs like UTTEST, APITEST_DB ran only on `ubuntu-latest` (default amd64). With this each job uses:
  
  strategy:
    matrix:
        include:
        - arch:amd64
          runner: ubuntu-22.04
        - arch:arm64
          runner: ubuntu-24.04-arm

Job names updated for architecture clarity.
Unit, API, and UI test logic unchanged, but now dynamically detects platform via `uname -m`.


## Testing 

Validation performed across amd64 and arm64 hosts:
	•	UI: Harbor portal accessible, login and navigation functional.
	•	API: /api/v2.0/ping, /projects, /repositories verified.
	•	Registry: Image push/pull works; multi-arch manifests resolve correctly per host.
	•	Services: All containers (core, jobservice, registry, portal, etc.) start healthy with the right linux/amd64 or linux/arm64 images.

To validate that our custom-built Harbor instance with Arm64 support works correctly across components and architectures, I performed the following levels of testing:

- tools/spectral/Dockerfile - Uses arch-specific spectral binary; dynamically selects amd64/arm64

- tools/migrate_chart/migrate_chart.sh- this script is architecture-neutral and works on both amd64 and arm64 as long as a compatible `helm` binary is available.

- tools/migrate_chart/Dockerfile - It currently hardcodes the Helm binary for `linux-amd64` so it is not architecture-neutral and must be updated to support Arm64 by dynamically resolving the appropriate Helm binary for the target architecture.
Made this docker image multi-architecture (`docker pull ranichowdary/migrate-chart:latest`)

tools/notary-migration-fix.sh - No changes
tools/swagger/Dockerfile - No changes

- tools/release/release_utils.sh: In getAssets() function adding `arch` parameter because builds are now organized under subfolder like `amd64/` and `arm64/`. Updated GCS `gsutil cp` paths to ensure it looks under the correct architecture folder. Used `mkdir -p` to prevent errors if assetsPath already exists. Also updated `publish_release.yml` where it calls `getAssets`.
I can work on this but this need maintainers to work as we need to deal with few enhancements.

Container Health Validation:

- Ensuring auxiliary tools handled for both `amd64` and `arm64` architectures when building Harbor via the Makefile:

- Verified all Harbor services (core, registry, jobservice, portal, proxy, etc.) were up and marked as healthy via docker ps.
- Ensured correct images were used with linux/arm64 platform and linux/amd64.

Web UI Access:

- Loaded the Harbor UI successfully at http://<host>/harbor.
- Confirmed login, project navigation, and artifact listing worked from the browser.

API-Level Testing:
- Used Harbor’s REST API to validate backend services:
    - GET /api/v2.0/ping → responded with pong confirming core service health.
    - GET /api/v2.0/projects → confirmed API access and project metadata retrieval.
    - POST /api/v2.0/projects → tested project creation via API.
    - GET /api/v2.0/repositories and /artifacts → verified image metadata retrieval.


- Image Push and Pull Tests (Registry Validation)
- Multi-Architecture Image Validation

These tests confirm that Harbor can function fully on Arm64 & amd64, including UI, API, registry, and multi-architecture artifact handling. The environment is now ready for use in cloud-native, edge, or hybrid deployments.

## RoadMap:

	•	Short term (v1): Enable CI, publish multi-arch images, support both installer types. Validate Helm charts, refine Dockerfiles, improve cross-arch consistency.
	•	Long term: Maintain Harbor parity across architectures as a first-class CNCF project.


Thanks for reviewing this work! Since I'm the author of this contribution from Arm, I believe this is a high-priority topic within the Harbor community and it could be introduced as a new feature soon. A formal proposal like this document will help align on the design and technical implementation.

I welcome feedback, collaboration, or questions from the Harbor community.

## References:

- www.arm.com/migrate
- https://learn.arm.com/
- https://hub.docker.com/u/ranichowdary
