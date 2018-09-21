# Harbor Governance

This document defines the project governance for Harbor.

## Overview

**Harbor**, a Cloud Native Computing Foundation (CNCF) project, is committed to building an open, inclusive, productive and self-governing open source community focused on building a high-quality cloud native registry. The community is governed by this document with the goal of defining how community should work together to achieve this goal.

## Code Repositories

The following code repositories are governed by Harbor community and maintained under the `goharbor` namespace.

* **Harbor:** Main Harbor codebase.
* **Harbor-helm:** Helm chart for easy deployment of Harbor
* **community:** Used to store community-related material–e.g., proposals, presentation slides, governance documents, community meeting minutes, etc.

## Community Roles

* **Users:** members that engage with the Harbor community via any medium (Slack, WeChat, GitHub, mailing lists, etc.)
* **Contributors:** regular contributions to projects (documentation, code reviews, responding to issues, participation in proposal discussions, contributing code, etc.). Two levels of maintainership are defined below.
* **Maintainers**: see definitions and distinction below

## Project Leadership

There are two roles that convey project leadership: maintainers and core maintainers.

* **Core Maintainers**: Responsible for the overall health and direction of the project; final reviewers of PRs and responsible for releases.
* **Maintainers**: Responsible for one or more components within a project, and are expected to contribute code and documentation, review PRs including ensuring quality of code, triage issues, proactively fix bugs, and perform maintenance tasks for these components.

### Supermajority

A supermajority is defined as two-thirds of members in the group (e.g., non-core maintainers or core maintainers) that require the majority.

### Total Maintainership

Total maintainership is defined as the union of maintainers and core maintainers.

### Maintainers

New maintainers must be nominated by an existing maintainer or core maintainer and must be elected by a supermajority of total maintainership. Likewise, maintainers can be removed by a supermajority of the total maintainership or can resign by notifying the core maintainers.

### Core Maintainers

Nomination for core maintainership requires (a) a nomination by an existing core maintainer, and (b) election by a supermajority of the core maintainer group. Likewise, maintainers can be removed by a supermajority core maintainer vote or can resign by notifying the core maintainers.

### Decision Making

Ideally, all project decisions are resolved by consensus. If impossible, any maintainer may call a vote. Unless otherwise specified in this document, any vote will be decided by a supermajority of the total maintainership, with a requirement of at least one core maintainer voting.

Votes by maintainers (either core or non-core) belonging to the same company will count as one vote; e.g., 4 maintainers employed by company `${x}` will only have **one** combined vote.

## Proposal Process

One of the most important aspects in any open source community is the concept of proposals. Large changes to the codebase and / or new features should be preceded by a proposal in our community repo. This process allows for all members of the community to weigh in on the concept (including the technical details), share their comments and ideas, and even offer to help. It also ensures that members are not duplicating work or inadvertently stepping on toes by making large conflicting changes.

The project roadmap is defined by accepted proposals.

Proposals should cover the high-level objectives, use cases, and technical recommendations on how to implement. In general, the community member interested in implementing the proposal should be either deeply engaged in the proposal process or be the author of the proposal {him,her}self.

The proposal should be documented as a separated markdown file pushed to the `proposals` folder in the [community](https://github.com/goHarbor/community) repository via PR. The name of the file should follow the name pattern `<short meaningful words joined by '-'>_proposal.md`, e.g: `clear-old-tags-with-policies_proposal.md`.

See this [PR](https://github.com/goharbor/community/pull/4) as a good example of a proposal.

### Proposal Lifecycle

The proposal PR can be marked with different status labels to represent the status of the proposal:

* **New**: Proposal is just created
* **Reviewing**: Proposal is under reviewing and discussion
* **Accepted**: Proposal is reviewed and voted to accept
* **Rejected**: Proposal is reviewed but not enough votes got

## Updating Governance

All changes in Governance require a supermajority total organizational (non-core + core maintainers) vote.