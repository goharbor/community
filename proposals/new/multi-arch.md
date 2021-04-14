# Proposal: `Multi Arch Support`

Author: `Zhipeng Yu / yuzp1996`

Discussion: `none`

## Background

More and more companies need to support multi-architecture solutions, some of the more mainstream x86 and arm64 architectures, this proposal is to provide a solution to produce multi-architecture images

## Plan

When the release 2.3 of Harbor is released, the arm64 Harbor can be issued at the same time

Release 2.3 of Harbor is tentatively scheduled to be released in mid-June 2021

## Target

### Short Term Target

We can provide support for different architectures in a different Harbor sub-projects. 

For example, in the harbor-arm repo, we can maintain the build logic and other related information for arm64 images

### Long Term Target

When the harbor is released, images of different architectures can be directly generated and push to registry. When deploying harbor, users do not need to distinguish the difference in architecture

## Implementation

### Glossary

Upstream: github repository goharbor/harbor

Downstream: github repository like harbor-arm harbor-loongson and so on

### Upstream changes

#### Goal

Provides the ability to compile binary and image of a specific architecture based on environment variable parameters. (In the initial stage, the upstream only guarantees that the image of the amd64 architecture can be successfully built, and other versions are guaranteed by the corresponding downstream repository)

#### Changes

1. Increase the environment variable ARCH, the default is amd64, which can be overwritten during execution

2. When executing make compile to generate binary, it can generate binary of different architectures according to the environment variable ARCH

3. Add a file named adapter.sh, the content of the file is empty. Before executing  compile and build commands, please call adapter.sh scripts. This shell script file can be overwritten by downstream users, and downstream users can write their own modifications in this file, such as overriding the addresses of third-party dependencies or replacing Dockerfile.

### Downstream changes 

#### Goal

Maintain the build and test of an architecture images

#### Change

1. Introduce the harbor repository into the downstream repository through git Submodules

2. Add a file named adapter.sh, responsible for making changes to areas that cannot be covered by upstream changes

3. Add a Makefile (which can be called when performing github actions) to achieve such as overwriting adapter.sh or other functions

4. Add Dockerfile if necessary

5. Add github action files to maintain the build and test in them. The content of the github action should be modified based on the upstream github action, but it should be kept in sync at all times

### Test

We want to use the upstream test method to test, use docker-compose to deploy Harbor and then use the shell script to execute the test

However, there are currently the following issues that need to be resolved

1. During testing, docker-compose will be used to deploy Harbor and test, but it seems that docker-compose [only provides x86 binary files](https://github.com/docker/compose/releases), and we need to compile other versions by ourselves. We can try to install docker-compose with pip

2. Images of different architectures may not be able to run using the runner provided by github action. [Self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners) should be used to ensure that images of different architectures can run tests.


### Image strategy

#### Repository

The image will be hosted under the goharbor project of Docker Hub

#### Tag

Add the architecture name after the generated image version. For example： goharbor/harbor-core:v2.2.1-arm64


### Related Implementation

There are already some PRs and repository that have implemented this function, we can make full use of these contents

Changes provided by this [PR](https://github.com/goharbor/harbor/pull/13788) can build amd64 and arm64 image simultaneously

This repository  https://github.com/querycap/harbor have created arm64 and amd64 image successfully 



## Development Iteration

After several iterations, we need to ensure that the content in adapter.sh and github actions files in downstream repository is as small as possible，After each iteration, more code can be extracted and merge to upstream。

After the adapter.sh and github actions files of the downstream code disappear, we can no longer maintain the downstream repository.



## Release

When the goharbor/harbor is released, check out the same release branch under the downstream repository, and check the corresponding commit in git Submodules, execute the pipeline to generate the corresponding image and push it to the docker hub

Readme.md or release notes needs to be updated in different branches to inform the images related information, such as location and corresponding tags


## Notify Users

We provide repository addresses that support other architectures in goharbor/harbor release notes. Users can directly find repository addresses of different architectures according to the link.


## Block Item

1. Images of different architectures may not be able to run using the runner provided by github action. [Self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners) should be used to ensure that images of different architectures can run tests.