# Harbor Community Proposal - Eating your own dog food Container Registry

Status: In Progress
Created by: Vadim Bauer
Created time: January 24, 2024 1:17 PM
Last Edited: January 24, 2024 1:52 PM

# **Proposal:Use Our Own Registry**

# **Abstract**

Use of our Harbor registry to distribute our own container images. We should be the first to adopt our own technology. If we are not willing to utilize our own application for day-to-date use, don't expect others to do so.

# **Background**

Today, Harbor is the most popular and widely recognized full-fledged container registry on the market. Yet, we are not using our own product ourselfs. Hence the [dogfooding](https://www.projectmanagement.com/articles/217092/eat-your-own-dog-food#_=_) title.

# **Proposal**

Deploy and operate Harbor on AWS to distribute containerized images of Harbor.

With support and sponsoring from [8gears](https://container-registry.com/), a 24/7 operation can be accomplished.

# **Non-Goals**

# Rationale

Here are some advantages of using our own Registry.

*Eating your own dog food* doesn't just mean we should use our own product. It also means you should attempt to install it and configure it ourselves.

- Better understanding of the end users' experience.
- Product's quality would significantly improve.
- Better documentation
- Users can see how Harbor can be used in real case scenario

## Costs

The used AWS account is sponsored by AWS. There is currently no cost limited or restriction.

- 80% of the costs will be traffic. Assuming 10 TiB monthly traffic per month would generate ~870-1000 USD (10240 GiB * 0.085USD/GiB)
- Fixed costs will be around 200-300 USD a month.
- As a Fallback, Cloudflare R2 can be used instead of AWS S3, where there are no egress fees. However there are no agreements between CNCF and Cloudflare in place..

# **Compatibility**

-
-

# **Implementation**

![Untitled](assets/aws-infa-harbor.png)

Better understanding of the end users' experience

## Phase 0

- Deploy Harbor on AWS registry.goharbor.io
- Mirror all images from Docker Hub to Harbor
- Use registry to push test artifacts
- Parallel operation next to Docker Hub.

## Phase I

- Dedicated IaC Repo containing the infrastructure
- Since all images from Docker Hub are already in Harbor.
  - Replace image references in Documentation
  - Replace Image references in Compose
  - Replace image references in Helm
- Keep Docker Hub account as a fallback
  - Replicate images from Harbor to Docker Hub

## Phase II - Future

- Potentially we can disable DockerHub Account
