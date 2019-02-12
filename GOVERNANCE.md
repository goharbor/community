# Harbor Governance

This document defines the project governance for Harbor.

## Overview

**Harbor**, a Cloud Native Computing Foundation (CNCF) project, is committed
to building an open, inclusive, productive and self-governing open source
community focused on building a high-quality cloud native registry. The
community is governed by this document with the goal of defining how community
should work together to achieve this goal.

## Code Repositories

The following code repositories are governed by Harbor community and
maintained under the `goharbor` namespace.

* **[harbor](https://github.com/goharbor/harbor):** Main Harbor codebase.
* **[harbor-helm](https://github.com/goharbor/harbor-helm):** Helm chart for easy deployment of Harbor
* **[community](https://github.com/goharbor/community):** Used to store community-related material–e.g., proposals, release plans, workgroup documents, presentation slides, governance documents, community meeting minutes, etc.

## Community Roles

* **Users:** Members that engage with the Harbor community via any medium (Slack, WeChat, GitHub, mailing lists, etc.).
* **Contributors:** Regular contributions to projects (documentation, code reviews, responding to issues, participation in proposal discussions, contributing code, etc.). Two levels of maintainership are defined below.
* **Maintainers**: Two levels of maintainership are defined in the Project Leadership section [below](#total-maintainership).

## Project Leadership

There are two roles that convey project leadership: maintainers and core maintainers.

* **Core Maintainers**: Responsible for the overall health and direction of the project; final reviewers of PRs and responsible for releases.
* **Maintainers**: Responsible for one or more components within a project, and are expected to contribute code and documentation, review PRs including ensuring quality of code, triage issues, proactively fix bugs, and perform maintenance tasks for these components.

### Total Maintainership

Total maintainership is defined as the union of maintainers and core
maintainers.

### Maintainers

New maintainers must be nominated by an existing maintainer or core maintainer
and must be elected by a [supermajority](#supermajority) of total maintainership. Likewise,
maintainers can be removed by a [supermajority](#supermajority) of the total maintainership or can resign by notifying the core maintainers.

### Core Maintainers

Nomination for core maintainership requires (a) a nomination by an existing
core maintainer, and (b) election by a [supermajority](#supermajority) of the core maintainer group. Likewise, maintainers can be removed by a [supermajority](#supermajority) core maintainer vote or can resign by notifying the core maintainers.

### Taking Effect

Upon adding a new maintainer or core maintainer, the following actions must be performed:

* Update the [MAINTAINERS.md](https://github.com/goharbor/community/blob/master/MAINTAINERS.md) file
* Add the new maintainer to related mailing groups and social channels if needed
* Add the new maintainer to the [GitHub](https://github.com/orgs/goharbor/teams) organizations and teams if needed
* Publish the announcement to the community

### Decision Making

Ideally, all project decisions are resolved by consensus. If impossible, any
maintainer may call a vote. Unless otherwise specified in this document, any
vote will be decided by a [simple majority](#simple-majority) of the total maintainership, with a requirement of at least one core maintainer voting.

Votes by maintainers (either core or non-core) belonging to the same organization cannot
exceed the [Simple majority](#simple-majority) threshold. If the number of maintainers
(either core or non-core) from the same organization exceeds the simple majority bar, the
organization should figure out who will be their representatives to give binding votes in
the voting process. The votes from the non-organization-representative maintainers (either
core or non-core) will be counted as no-binding votes which will be taken into account when
the voting is stalemated (50% VS 50%). The binding and non-binding voting rights will be
marked in the [MAINTAINERS.md](https://github.com/goharbor/community/blob/master/MAINTAINERS.md) file.

Any changes to the [MAINTAINERS.md](https://github.com/goharbor/community/blob/master/MAINTAINERS.md) file will be considered as governance model changes.

### Supermajority

A supermajority is defined as two-thirds of members in the group.
A supermajority of [Maintainers](#maintainers), [Core Maintainers](#core-maintainers), or 
the union of both is required for certain decisions as outlined above.

### Simple majority

A simple majority is defined as more than half of members in the group.
A simple majority of the [Total Maintainership](#total-maintainership) is required for 
certain decisions as outlined in the document.

## Proposal Process

One of the most important aspects in any open source community is the concept
of proposals. Large changes to the codebase and / or new features should be
preceded by a proposal in our community repo. This process allows for all
members of the community to weigh in on the concept (including the technical
details), share their comments and ideas, and offer to help. It also ensures
that members are not duplicating work or inadvertently stepping on toes by
making large conflicting changes.

The project roadmap is defined by accepted proposals.

Proposals should cover the high-level objectives, use cases, and technical
recommendations on how to implement. In general, the community member(s)
interested in implementing the proposal should be either deeply engaged in the
proposal process or be an author of the proposal.

The proposal should be documented as a separated markdown file pushed to the root of the
`proposals` folder in the [community](https://github.com/goHarbor/community)
repository via PR. The name of the file should follow the name pattern `<short
meaningful words joined by '-'>_proposal.md`, e.g:
`clear-old-tags-with-policies_proposal.md`.

Use the [Proposal Template](proposals/TEMPLATE.md) as a starting point.

### Proposal Lifecycle

The proposal PR can be marked with different status labels to represent the
status of the proposal:

* **New**: Proposal is just created.
* **Reviewing**: Proposal is under review and discussion.
* **Accepted**: Proposal is reviewed and accepted (either by consensus or vote).
* **Rejected**: Proposal is reviewed and rejected (either by consensus or vote).

## Other Projects

The Harbor organization is open to receive new sub-projects under its umbrella. To accept a
project into the Harbor organization, it must meet the following criteria:

* Must be related to Harbor and its ecosystem, as decided by the core maintainers.
* Must be licensed under the terms of the Apache License v2.0
* Must have more than two contributors

The submission process starts as a Pull Request on the [goharbor/community](https://github.com/goharbor/community) 
repository with the required information mentioned above. Once a project is determined to 
be accepted by supermajority voting, it's considered a CNCF sub-project under the umbrella of Harbor.

## Lazy Consensus

To maintain velocity in a project as busy as Harbor, the concept of [Lazy
Consensus](http://en.osswiki.info/concepts/lazy_consensus) is practiced. Ideas
and / or proposals should be shared by maintainers (core or non-core) via
GitHub with the appropriate maintainer groups (e.g.,
`@goharbor/all-maintainers`) tagged. Out of respect for other contributors,
major changes should also be accompanied by a ping on Slack or a note on the
Harbor dev mailing list as appropriate. Author(s) of proposal, Pull Requests,
issues, etc.  will give a time period of no less than five (5) working days for
comment and remain cognizant of popular observed world holidays.

Other maintainers may chime in and request additional time for review, but
should remain cognizant of blocking progress and abstain from delaying
progress unless absolutely needed. The expectation is that blocking progress
is accompanied by a guarantee to review and respond to the relevant action(s)
(proposals, PRs, issues, etc.) in short order.

Lazy Consensus is practiced for all projects in the `goharbor` org, including
the main project repository, community-driven sub-projects, and the community
repo that includes proposals and governing documents.

Lazy consensus does _not_ apply to the process of:

* Removing core or non-core maintainers
* Changing governance model

## Updating Governance

All substantive changes in Governance require a supermajority [Total
Maintainership](#total-maintainership) vote.

## Code of Conduct

Harbor follows the [CNCF Code of Conduct](https://github.com/cncf/foundation/blob/master/code-of-conduct.md).