# Proposal: `Backup Hosting Harbor Images in TCR`

Author: `Tencent Container Registry Members <marcriverli@tencent.com;blakezyli@tencent.com;fanjiankong@tencent.com;ivanscai@tencent.com;zichentian@tencent.com;dehonghao@tencent.com>`

## Abstract

Backup hosting Harbor images in Tencent Cloud Registry(aka TCR).

## Background

> On November 20, 2020, rate limits anonymous and free authenticated use of Docker Hub went into effect. Anonymous and Free Docker Hub users are limited to 100 and 200 container image pull requests per six hours.

Because DockerHub has strict frequency restrictions enabled and quotas for anonymous and free users are minimal, some users can not properly pull images from DockerHub for Harbor deployment. At the same time, because Harbor's container image is stored on the DockerHub, many users in mainland China often face the problem of slow or even unable to pull the Harbor's images. This can cause a lot of trouble for Harbor users, and even prevent new users from trying to use Harbor.

## Proposal

In order to help new and old users to conveniently and quickly obtain the images of Harbor, and start the journey of the enterprise-class Registry of Harbor, as the maintainers of Harbor and a member of the TCR product team, I hereby propose that Harbor uses the TCR service of Tencent Cloud to backup hosting the images of Harbor.

## Non-Goals

- As a primary mirror source for the online/offline deployment of Harbor.
- Provides download acceleration for Harbor users outside mainland China.

## Story
Frank is a Harbor user who lives in mainland China.
- **Deployment with dockerhub**: When Frank deployed Harbor by pulling the images through the DockerHub, he found that the image pull was so slow that some blobs even tried again.
- **Deployment with TCR**: When Frank deployed Harbor via TCR pull images, the pulling of images was done in a very short time, and the Harbor instance was successfully deployed quickly.

## Implementation

[A description of the steps in the implementation, who will do them, and when.]

- Tencent Cloud sponsors relevant hosting resources and fees.
- The TCR product team provides a sub-account of the Tencent cloud, and create the TCR service and the dependent service.
- Hosts the 3 most recently released versions of Harbor images from the date of PR implementation.
- Mirror synchronization was done manually by the TCR team early on.
- Gradually automate mirror synchronization, such as automatically pushing images to Dockerhub and TCR when a new version is released.

## Open issues (if applicable)
