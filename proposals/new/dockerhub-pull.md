# Proposal: Pull images from public registry like docker hub

Author: `De Chen`

## Abstract

Harbor supports pulling images from public registries, such as docker hub.

## Background

For the moment, we have two ways to push images to Harbor:

- docker push
- image replication

If users don't have an existing Harbor to replicate images, they have to push images by docker manually.

When users use Harbor, they always have need for different common images from public registries, for example, `alpine`, `busybox`, `nginx`.

If Harbor can support pulling images from public registries, it will save users from `docker pull` -> `docker tag` -> `docker push` operations. It's meaningful especially for newly created Harbor.

## Proposal

Harbor by default supports some popular public registries, for example `Docker Hub`. For the first step, supporting `Docker Hub` is sufficient, and the following will use it as target.

Users can then navigate repositories in Docker Hub, and select images they want and pull them to Harbor.

Features included:

- Search images in Docker Hub
- Select and pull images to Harbor
- Pull images from Docker Hub by user provided image list

## Rationale

An alternate approach may be supporting this in image replications. For replication, it's a good choice for repos/images that share some same properties, such as in the same project, have same labels, repo/tag names following same patterns. And we can trigger the replication more than one time. For the case in this proposal, images are much dispersed and dynamically changed, so replication is not suitable for it, in my opinion.