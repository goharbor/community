# Proposal: Arm64 Support and Multi-Architecture Image Publishing for Harbor

Author: Rani Chowdary Mandepudi, Arm (@ranimandepudi)

Discussion: https://github.com/goharbor/harbor/pull/21825

## Abstract

This proposal introduces native Arm64 support and multi-architecture image publishing for all Harbor components. The goal is to enable Harbor to run natively on Arm64 hardware, align with CNCF best practices, and enhance Harbor's portability across modern infrastructure environments.

## Background

Harbor is a popular cloud-native container registry. While it provides full-featured registry services, its official builds and Docker images target only the Amd64 architecture. The growing adoption of Arm64 in cloud-native and edge computing environments has created demand for native Arm64 support.

Currently, deploying Harbor on Arm64 requires emulation or custom builds, reducing performance and maintainability.

## Proposal

Note: No changes have been made to functionality—this update ensures that the current architecture remains unaffected.

All Harbor component images have been built and tagged for the Arm64 architecture. These images have been pushed to my DockerHub repository under the namespace ranichowdary/ (replacing the original goharbor/ namespace) for testing and validation purposes. Once the review is complete, the image names can be reverted to the original naming convention.

Additionally, the Dockerfile paths and image naming conventions have been modified to support multi-architecture builds. This ensures compatibility and seamless operation on both x86 and Arm64 platforms using the same codebase and Docker images.

These changes allow Harbor to be built, packaged, and installed cleanly on Arm64 hosts such as AWS Graviton and also on x86 as images are multi arch. 

This proposal introduces native Arm64 builds for Harbor components using `Docker Build` and multi-architecture manifests. Each image is tested and published in a way that maintains compatibility with existing Amd64-based deployments.

## Design Goals

Build Harbor component images (core, jobservice, registryctl, etc.) for both Arm64 and Amd64 using native compilation per architecture and multi-arch manifest merging.

Published multi-arch images to Docker Hub using unified manifest lists, enabling transparent arch-specific pulls without impacting existing deployments.

Supported native and cross-platform builds via docker buildx and architecture-specific runners.

Ensure deterministic and repeatable builds across architectures using consistent Makefile targets and validated build.

Provide documentation for Arm64 validation, and plan to publish a learning path on learn.arm.com post-upstreaming.

Integrate Arm64 builds into Harbor’s CI and release workflows using GitHub Actions. This will require coordination with Harbor maintainers—I’m happy to assist or contribute directly as needed.

## Architecture Overview:

## Image Structure:

Image tags follow the pattern: goharbor/<component>:<version>
During development and testing, images are published under the ranichowdary/* namespace on Docker Hub (e.g., ranichowdary/core-harbor, ranichowdary/jobservice-harbor).
Finalized multi-arch images will match upstream Harbor naming conventions.

Images:
MultiArch Images links:

Nginx:
ranichowdary/nginx-harbor
ranichowdary/nginx-base-harbor
Db:
ranichowdary/db-harbor
ranichowdary/db-base-harbor
Redis:
ranichowdary/redis-harbor
ranichowdary/redis-base-harbor 
Log:
ranichowdary/log-harbor
ranichowdary/log-base-harbor
Core:
ranichowdary/core-harbor
ranichowdary/core-base-harbor
Exporter:
ranichowdary/exporter-base-harbor 
Jobservice
ranichowdary/jobservice-harbor
ranichowdary/jobservice-base-harbor
Registry:
ranichowdary/registry-harbor
ranichowdary/registry-base-harbor
Registryctl:
ranichowdary/registryctl-harbor
ranichowdary/registryctl-base-harbor 
Portal:
ranichowdary/portal-harbor
ranichowdary/portal-base-harbor
Trivy:
ranichowdary/trivy-adapter-harbor
ranichowdary/trivy-base-harbor


## Build and Push Workflow (Per Architecture)

Each image is built and pushed in the following steps:
On Amd64 Host:
- Generated amd64 binary.
- Build image: docker build -t ranichowdary/core-harbor:amd64 .
- Push the docker push ranichowdary/core-harbor:amd64
On Arm64 Host:
- Run make build-core on Arm64 instance to generate native binary.
-  Build image: docker build -t ranichowdary/core-harbor:arm64 .
- Push the docker push ranichowdary/core-harbor:arm64

Created manifest to ensure final image : `latest` tag resolves to the correct architecture during image pull based on the target environment.

## Testing 

To validate that our custom-built Harbor instance with ARM64 support works correctly across components and architectures, I performed the following levels of testing:

Container Health Validation:

- Verified all Harbor services (core, registry, jobservice, portal, proxy, etc.) were up and marked as healthy via docker ps.
- Ensured correct images (ranichowdary/*-harbor) were used with linux/arm64 platform and linux/amd64.

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

These tests confirm that Harbor can function fully on Arm64 & Amd64, including UI, API, registry, and multi-architecture artifact handling. The environment is now ready for use in cloud-native, edge, or hybrid deployments.

Thanks for reviewing this work! Since I'm the author of this contribution from Arm, I believe this is a high-priority topic within the Harbor community and it could be introduced as a new feature soon. A formal proposal like this document will help align on the design and technical implementation.

I welcome feedback, collaboration, or questions from the Harbor community

## References:

www.arm.com/migrate
https://learn.arm.com/
https://hub.docker.com/u/ranichowdary
