# Proposal:`<Daniel Zhang>`

Author: `<Daniel Zhang/ danielzhanghl>`

Discussion: `https://github.com/goharbor/harbor/issues/6271`

## Abstract

add docker repo quota to project.

## Background

[harbor has no restrictions on repository and tag quotas.For example: how many repositories can be created per project and how many tags can be created per repository. And This quota should be set by the user. The problem it caused.When a repository has many tags, the query is slow.]

## Proposal

1.project quota could be set/modified when create/modify project, it is used to limit the images that user could push, for example, 1024M(it's default value).

2. image size is queried from image manifest file: size of all layers and manifest file size.
when user upload a layer or manifest, project usage will be checked with quota, if it's going to exceed, the load will be blocked, otherwise, the project usage will be counted.

3. when image is pushed, the usage will be re-calculated by reading all the images manifest in the project, therefore, there maybe "usage" great than "quota", but it's not the real storage situation, as docker client did not upload the layer but only refer it in the images manifest file. and the next upload attempt will be blocked as the usage is great than quota.

4. if user push two images, with part of or all the layers are same, the total size used is counted twice though the layers are shared.


## Non-Goals

1. the storage of docker repo are shared with the entire repositroy, there is no exact way to control to the usage for a specific project, this propsal is to limit the total size declared in one project, not the real storage.
2. chart repo is not the goal in the propsal

## Rationale

control the declared size of all repositroes in a project is enough to limit the useage.

## Compatibility


## Implementation

that is avaiable in https://github.com/goharbor/harbor/pull/6425.

## Open issues (if applicable)
how to migrate from existing db is a open item.
