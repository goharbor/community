Proposal: Support automatic SBOM generation in Harbor

Authors: Furkan Türkal (@Dentrax), Batuhan Apaydın (@developer-guy)

Discussion: https://github.com/goharbor/harbor/issues/16397

## Abstract

Inevitably, it all starts with knowing what software is being used. You need an accurate list of “ingredients” (such as libraries, packages, or files) that are included in a piece of software. This list of “ingredients” is known as a software bill of materials. [^8] A “[Software Bill of Materials](https://www.ntia.gov/SBOM)” (SBOM) is a nested inventory for software, a list of ingredients that make up software components.

The proposal is to integrate any SBOM generation tool with Harbor. One of the well-known SBOM generators are Syft and Trivy would be great fit for the use-case.

## Motivation

Many organizations and projects such as Docker [^5][^6], Buildx [^7], Trivy and many more are working on supply chain security closely. They all are trying to adapt tools that can help them with securing supply chains such as signing and verifying container images, automatic SBOM generation, and so on.

## Proposal

Create a generic SBOM generation plugin system in Harbor for Software Bill of Materials (SBOM) from container images and filesystems. Since Cosign already supported by Harbor, we can store signatures in an OCI registry next to the container image, and can be located via a simple name scheme. The Cosign spec allows SBOM information to be embedded into the cosign artifact. [^2]

## Goal

* Create a generic SBOM generation plugin system
* Support any SBOM generation tool
* Support SPDX and CycloneDX formats
* Create and [attach](https://github.com/sigstore/cosign/issues/1742) signed SBOM attestations
* Each time we push a new container image we need to generate an SBOM
* Display SBOM content on the Harbor

## Not Goal

* Do not verify SBOM attestations in Harbor side. (Harbor cannot verify the signatures)

## Personas and User Stories

This section lists the user stories for the different personas interacting with SBOM generation.

* Personas

Syft and Trivy are the operation of authorized users in Harbor with image push scope.

* User Stories

* As a project admin & user, I can use Syft or Trivy to generate an SBOM (single or multiple times).
* As a project admin & user, I can use Syft or Trivy to generate an SBOM (single or multiple times).
* As a project admin & user, I can delete an SBOM attestation via Harbor UI/API.
* As a project admin & user, I cannot GC an artifact's SBOM attestation individually.
* As a system admin, I can copy an SBOM to another repository.
* As a system & project admin, I can set the content trust policy to block the un-signed SBOM pulling.
* As a system & project admin, I can reserve an SBOM via retention policy.
* As a system admin & project admin, I can setup an immutable rule to make the SBOM attestation permanent.

## Installation

Both of Syft and Trivy can generate SBOM, which means users may need to decide which one to use, like `--with-syft` or `--with-trivy` during installation.

## Artifact reference

SBOM attestations are stored as separate artifacts in the OCI registry using cosign’s SBOM specification. [^3]

Since Harbor already supports accessory[^4] we ensure that the image and its SBOM are operated as a whole.

### Request All Artifact Signatures

```
GET /api/v2.0/projects/library/repositories/hello-world/artifacts/accessories?n=10&artifactType=SBOM
```

### Delete All SBOMs

```
DELETE /api/v2.0/projects/library/repositories/hello-world/artifacts/sha256:1b26826f602946860c279fce658f31050cff2c596583af237d971f4629b57792/accessory?type=SBOM
```

### Delete Specific SBOM

```
DELETE /api/v2.0/projects/library/repositories/hello-world/artifacts/sha256:1b26826f602946860c279fce658f31050cff2c596583af237d971f4629b57792/accessory?type=SBOM&digtest=sha256:94788818ad901025c81f8696f3ee61619526b963b7dc36435ac284f4497aa7cb
```

[^1]: https://aquasecurity.github.io/trivy/v0.24.2/advanced/sbom/cyclonedx/
[^2]: https://docs.sigstore.dev/cosign/other_types/
[^3]: https://github.com/sigstore/cosign/blob/main/specs/SBOM_SPEC.md
[^4]: https://github.com/goharbor/community/blob/main/proposals/new/accessory.md#accessory-interface=
[^5]: https://www.docker.com/blog/announcing-docker-sbom-a-step-towards-more-visibility-into-docker-images/
[^6]: https://github.com/moby/buildkit/issues/2773
[^7]: https://github.com/docker/cli/issues/3283
[^8]: https://anchore.com/sbom/drop-an-sbom-how-to-secure-your-software-supply-chain-using-open-source-tools/
