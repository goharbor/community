# Proposal: `Harbor Build Supports Multiple Architectures`

Author: `Zhipeng Yu / yuzp1996` and `bo zhu / Jeremy-boo`

Discussion: `none`

## Background

At present, more and more companies need harbor to support multi-architecture construction. Some of the more mainstream ones are x86 and arm64 architectures. This proposal is to provide a solution for generating multi-architecture mirroring.

## Plan

When Habor releases version 2.3, support for arm64 Harbor image construction can be released at the same time

Harbor version 2.3 is tentatively scheduled to be released in mid-June 2021, so we must complete the development and testing of Harbor's multi-architecture construction before the end of May.

## Architecture Maturity Model

In order to provider a **short-term** and **long-term** process to introduce and iterate a new architecture into Harbor ecosystem a maturity model is proposed below

### Overview

| **Level** | **Description** | **Goals** | **Challenges** |
| :----: | :----: | :----: | :-----: |
| Dev | Introduce a new architecture into the ecosystem as independent repo and images	 | - Build the upstream's master branch code <br> - Introduce development practices	| - Build platform and code  <br> - Upstream changes trigger downstream build |
| Test | Uses Harbor's standard testing procedures to test the new architectures version	 | - Validate the new architecture's artifacts making sure it conforms to Harbor's standard test suite <br> - Ensure upstream master code have at least a daily build and test	|  - Infrastructure to deploy and run tests |
| Release | - Infrastructure to deploy and run tests | - Make sure release candidates and other release builds on upstream can execute successfully on downstream <br> - Run release tests in the new architecture	|- Sync with Harbor release timing|


#### Glossary

Upstream: github repository go-harbor/harbor

Downstream: github repository like harbor-arm harbor-loongson and so on.

Short-term: We can provide support for different architectures in different Harbor sub-projects.
For example, in harbor-arm, we can maintain the construction logic of arm64 mirroring and other related information

Long-term: Harbor-arm keeps the synchronization update with goharbor/harbor. When goharbor/harbor updates a version, harbor-arm follows the update and then pushes the mirror image to the mirror warehouse to provide users with multi-architecture support.



#### Risk

Upstream modifications may affect downstream construction

1. Upstream changed the Dockerfile.

2. Upstream changed the build dependency package.

3. Changes in architecture: Removing or adding new components?

4. Any compatibility braking changes

5. other situations

### Dev

#### Requisites
The new architecture uses a dedicated repository to maintain all the necessary files and scripts to build Harbor in its target architecture.

It should be able to build Harbor's master branch and push the resulting docker images to Harbor's org in `DockerHub` using the target architecture as suffix: `goharbor/harbor-core-arm64`

#### Suggested Implementation

#### Jobs For Upstream

1. Increase the environment variable GOARCH, the default is amd64, which can be overridden by specifying a specific value during execution, like arm64 and so on.

2. When executing make compile to generate binary files, it can generate binary files of different architectures according to the environment variable GOARCH

3. Upstream version update and downstream synchronization issues.

   Scheme selection:

    1. Change the upstream github action workflow and add an action: After the upstream master branch merges with pr, a message is sent to notify the downstream that a build update needs to be performed.

    2. The downstream actively pulls the version through timed tasks, and judges whether it needs to be built and updated by comparing with its own version (currently the downstream adopts this kind of plan to update and build).

#### Jobs For Downstream

1. Add a github action, responsible for building and testing related matters (in theory, it is consistent with the upstream github action process, just modify specific environment variables and dependent parameters, such as building an arm64 image through docker buildx).

2. Add a file named adapter.sh, which is mainly responsible for covering the basic parameters and dependency related matters that need to build a multi-arch mirroring.

3. Add a Makefile (which can be called when performing github actions) to achieve, such as overwriting adapter.sh or other functions.

4. Add Dockerfile if necessary

**Repository structure:**

- `Makefile`: Maintain its own list of commands to be used during the build process

- `.github`: Maintain project workflow

- `make`: Maintain scripts required for the project construction phase

- `src`: Pull goharbor/harbor's master branch code logic, if necessary

- `VERSION`: harbor-arm version number

- `README.md`: harbor-arm readme

- `CHANGELOG.md`: harbor-arm changelog

**Harbor-SubProject Image Tag:**

The harbor sub-project will use the same Harbor's org address as goharbor/harbor, and distinguish them by different tags

like harbor-arm: `goharbor/harbor-core:v2.1.3-arm`

tips: Wang Yan will provide credentials inside Goharbor's DockerHub org


**Dev possible blocking Item:**

- 1. Harbor components compatibility issues. Postgres database compatbiility when changing version making an upgrade rollout impossible.

- 2. Build process for new architecture.

- 3. Possible necessary upstream Makefile changes.


### Test

#### Requisites

1. Harbor standard conformance testing in the new architecture.

2. Different harbor images need to provide machine support of different architectures.

#### Suggested Implementation

We hope to be able to use the goharbor/harbor official test plan for test verification, provided that the official can provide a multi-architecture unified test plan.

However, there are currently the following issues that need to be resolved

1. During testing, docker-compose will be used to deploy Harbor and test, but it seems that docker-compose [only provides x86 binary files](https://github.com/docker/compose/releases), and we need to compile other versions by ourselves. We can try to install docker-compose with pip

2. Images of different architectures may not be able to run using the runner provided by github action. [Self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners) should be used to ensure that images of different architectures can run tests.

**Test possible blocking items:**
- 1. Images of different architectures may not be able to run using the runner provided by github action. [Self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners) should be used to ensure that images of different architectures can run tests.

- 2. Test machine problem.

- 3. Executing deployment and testing automatically either daily or with each upstream master commit


### Release

#### Requisites

Requires upstream goharbor/harbor to support GOARCH parameters to build harbor binary files and downstream harbor-multi sub-project to replace GOARCH parameters to build harbor-multi-Architecture images and push them to Harbor's org in `DockerHub`.

#### Suggested Implementation

- 1. harbor-multi sub-project repo executes local build tasks regularly, pulls goharbor/harbor's master branch code, if there is an update, executes local build logic to update the image version.


- 2. After the successful build, the harbor sub-project repo will update the documents such as `changelog.md` and `readme.md`.

- 3.  Sync with Harbor release timing.


### Ultimate goal

The harbor-multi sub-project is accompanied by the iteration of the goharbor/harbor, and finally hopes to be able to support the support of harbor multi-architecture image in the goharbor/harbor project, thus discarding the harbor-multi sub-project.

### Related Implementation

There are already some PRs and repository that have implemented this function, we can make full use of these contents

Changes provided by this [PR](https://github.com/goharbor/harbor/pull/13788) can build amd64 and arm64 image simultaneously

This repository  https://github.com/querycap/harbor have created arm64 and amd64 image successfully


## Development Iteration

After several iterations, we need to ensure that the content in adapter.sh and github actions files in downstream repository is as small as possible，After each iteration, more code can be extracted and merge to upstream。

After the adapter.sh and github actions files of the downstream code disappear, we can no longer maintain the downstream repository.


## Notify Users

We provide repository addresses that support other architectures in goharbor/harbor release notes. Users can directly find repository addresses of different architectures according to the link.

