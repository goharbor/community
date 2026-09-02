# Proposal: Image Patching with Copacetic

Author: `vad1mo`

Discussion: `N/A`

## Abstract

This proposal outlines a plan to extend Harbor's capabilities by integrating [Project Copacetic](https://project-copacetic.github.io/copacetic/website/) to provide both policy-based and ad-hoc vulnerability patching for container images.
This will allow users to not only identify vulnerabilities but also to remediate them directly within Harbor.

## Background

Harbor currently provides robust vulnerability scanning features, allowing users to identify security risks in their container images.
However, the remediation process is manual, requiring users to rebuild images with updated packages. 
This can be a time-consuming and inefficient process, especially in large-scale environments.

Project Copacetic is a CNCF project designed to patch container images by identifying vulnerable packages and replacing them with patched versions, 
without requiring a full rebuild of the original image. 
Integrating Copacetic into Harbor would provide a streamlined, in-registry solution for vulnerability remediation.

## Proposal

We propose the addition of a new "Image Patching" feature in Harbor, powered by Copacetic. This feature will have two primary modes of operation:

1. **Policy-Based Patching:**
   Users will be able to define patching policies that automatically scan and patch images based on specified criteria. These policies will be similar in structure to Harbor's replication rules, allowing users to target images based on:
    * Repository name (with regex support)
    * Image tag (with regex support)
    * Harbor labels

   Policies will run on a configurable schedule (e.g., daily, weekly). When an image matching the policy criteria is found to have vulnerabilities, Harbor will automatically trigger a patching job.

2. **Ad-Hoc Patching:**
   Users will have the option to trigger a patching process on-demand for a specific image. This can be done through a new UI action (e.g., a "Patch" button on the image details page) or via a new API endpoint.

In both cases, when an image is successfully patched, the new image will be pushed back to the same repository with a
`-patched` suffix appended to the original tag (e.g., `my-app:1.0.0` becomes
`my-app:1.0.0-patched`).

## Non-Goals

* This proposal does not cover the patching of Harbor's own components.
* It does not include real-time or on-pull patching. Patching will be performed by scheduled jobs or ad-hoc user requests.
* The initial implementation will not deal with the signing of patched images, but this could be a future enhancement.

## Rationale

The proposed approach provides a flexible and powerful solution for vulnerability remediation within Harbor.

* **Policy-based patching
  ** automates the process of securing images, reducing the manual effort required from developers and security teams.
* **Ad-hoc patching
  ** provides a quick and easy way to remediate vulnerabilities as they are discovered.
* **Copacetic
  ** is a natural choice for this integration as it is a CNCF project specifically designed for this purpose, and it operates directly on images, which aligns well with Harbor's role as a container registry.
* The proposed policy model leverages the existing replication rule paradigm, which will be familiar to existing Harbor users.

Alternative approaches, such as building a custom patching solution, would be significantly more complex and time-consuming.

## Compatibility

The proposed changes are additive and should not introduce any breaking changes to existing Harbor functionality. The new patched images will co-exist with the original images in the registry. Existing features like vulnerability scanning and replication will continue to function as expected. Scans will be able to run on the newly patched images, providing users with confirmation that vulnerabilities have been remediated.

## Implementation

The implementation can be broken down into the following high-level steps:

1. **Integration of Copacetic:
   ** The Copacetic binary will be integrated into the Harbor
   `jobservice` component.
2. **Database Schema:
   ** New tables will be added to the Harbor database to store patching policies.
3. **API Endpoints:
   ** New API endpoints will be created to manage patching policies and to trigger ad-hoc patching jobs.
4. **Jobservice Logic:** The
   `jobservice` will be extended with a new job type for image patching. This job will invoke the Copacetic binary to perform the patching and push the new image to the registry.
5. **UI/UX:
   ** The Harbor portal will be updated with a new section for managing patching policies. A "Patch" button will be added to the image details page to trigger ad-hoc patching.

This work can be carried out by the Harbor community contributors. A detailed implementation plan with timelines will be created once the proposal is accepted.

## Open issues (if applicable)

* How should we handle cases where Copacetic is unable to patch an image? Clear feedback should be provided to the user.
* Should there be a mechanism to automatically delete the original, vulnerable image after a successful patch? This could be a configurable option in the policy.
