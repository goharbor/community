# Proposal: Image Optimization & Recommendation Engine

Author: [`Hanna Czifrus`](https://github.com/czifrushanna)
Discussion: None

## Abstract

This proposal introduces a pluggable recommendation engine for Harbor that helps users turn scan results and image metadata into concrete next steps. The engine would surface actionable guidance for container images, such as safer base image options, vulnerability remediation suggestions, version upgrade recommendations, and general hardening advice.

The recommendation engine is intended to be an external, pluggable tool, similar to Harbor's scanner integration model. Harbor would define the contract for requesting recommendations and displaying results, while recommendation providers would be deployed and managed independently.

## Background

Container images change over time, and the quality of an image can degrade as base layers age, vulnerabilities accumulate, and build practices drift. Harbor already stores the data needed to understand an image, but the raw scan findings and metadata are not always easy to translate into a practical remediation plan.

Today, a user often needs to manually interpret scan output, compare alternative base images, and decide how to improve the artifact. That makes image hardening inconsistent and slow, especially for teams that manage many repositories or lack deep container security expertise.

## Proposal

The proposal is to add a recommendation workflow that analyzes an image and returns an optimized version together with a human-readable explanation of the changes.

At a high level, the workflow would be:

1. Harbor collects the inputs needed for a recommendation, including the original image, scan findings, and relevant metadata.
2. Harbor sends those inputs to a recommendation provider through a stable API.
3. The provider reconstructs a near-equivalent Dockerfile, identifies recommended actions, and generates an improved Dockerfile.
4. Harbor presents the original and recommended artifacts side by side, together with an explanation of the changes.
5. The user can review, edit, and choose the recommended result before generating the final image.

The recommendation provider would combine two steps internally:

1. A lightweight ranking model determines which optimization tasks are relevant for the image.
2. An LLM-based generation step, optionally augmented with retrieval, produces the recommended Dockerfile.

The initial optimization targets are:

- Vulnerability remediation
- Safer base image selection
- Image version and dependency update guidance
- General hardening and best-practice improvements

The engine should support future inputs such as runtime usage signals to make recommendations more precise over time.

## Non-Goals

- Automatically replacing user-owned images without review
- Enforcing recommendations as a policy gate
- Defining the internal implementation of any external recommendation provider
- Replacing Harbor's existing vulnerability scanning workflow
- Building a Harbor-specific model training pipeline in this proposal

## Rationale

A pluggable model is a better fit than a built-in recommendation service because it keeps the Harbor core focused on orchestration and user experience, while allowing recommendation logic to evolve independently.

This approach has a few advantages:

- Harbor can support multiple recommendation providers over time.
- Operators can choose the provider that best fits their environment, compliance requirements, or cost constraints.
- The recommendation logic can be improved, swapped, or retrained without requiring a Harbor release.
- The design stays aligned with Harbor's existing pluggable scanner architecture.

The main alternative would be to embed recommendation logic directly into Harbor. That would simplify the first implementation, but it would also couple Harbor to a specific model, make upgrades harder, and increase the maintenance burden for the core project.

## Compatibility

This proposal should be additive. Existing Harbor scanning, artifact browsing, and policy workflows should continue to work unchanged.

The recommendation engine should be exposed as an optional feature and should not affect image push, pull, scan, or replication behavior when it is disabled.

If Harbor stores recommendation results, the storage format should be versioned so that future provider changes do not break older records.

## Implementation

The implementation can be split into three parts:

1. Define the provider contract for recommendation requests and responses, including inputs, explanation text, and the recommended output artifact.
2. Add Harbor UI and API integration to request recommendations and display the original and generated results in a comparison view.
3. Implement one reference recommendation provider that can reconstruct an image, identify optimization tasks, and generate a recommended Dockerfile or equivalent build instructions.

The first provider can use publicly available model components, but the Harbor-side contract should remain model-agnostic so alternative providers can be added later.
