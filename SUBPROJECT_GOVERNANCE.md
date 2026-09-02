# Harbor Subproject Governance

This document defines governance for Harbor subprojects, reviewers,
and subproject maintainers.

## Roles

### Contributor

A contributor helps Harbor through code, documentation, testing, issue triage,
release work, packaging, community support, design review, or mentoring.

### Subproject Reviewer

A subproject reviewer is trusted to review and triage changes in a defined
subproject. Reviewers help contributors get work ready, but do not own the
subproject direction. Reviewers are listed in `MAINTAINERS.md`.

### Subproject Maintainer

A subproject maintainer owns the health of a defined Harbor subproject.

Responsibilities:

* Review, approve, and help merge changes in the subproject.
* Triage issues and pull requests.
* Keep documentation, tests, release notes, and ownership metadata current.
* Mentor contributors and reviewers.
* Coordinate releases or packaging when the subproject publishes artifacts.
* Escalate cross-project, security, or disputed decisions to Harbor Maintainers.

Subproject maintainership is scoped. It does not automatically grant Harbor
Maintainer status or project-wide decision authority.

## Subprojects

A Harbor subproject is a long-lived area of responsibility under the Harbor
community. It may own a repository, multiple repositories, or a clear area
inside a repository.

Active subprojects may maintain their own `MAINTAINERS.md`. That file is the
source of truth for the subproject's scoped maintainers and reviewers, and the
Harbor community `MAINTAINERS.md` should mirror it.

Each subproject entry in `MAINTAINERS.md` should include:

* Name and scope.
* Owned repositories or paths.
* Subproject maintainers.
* Subproject reviewers, if any.
* Status: `active`, `maintenance`, or `archived`.

Subproject maintainers and reviewers should be listed alphabetically by name.

## Role Changes

Reviewer:

* May be nominated by any contributor, including self-nomination.
* Requires approval from at least one subproject maintainer.
* If the subproject has no maintainer, approval comes from a Harbor Maintainer.

Subproject maintainer:

* May be nominated by a subproject maintainer or Harbor Maintainer.
* If the subproject has no active maintainer, a Harbor Maintainer may nominate.
* Active subprojects choose their own maintainers within their documented
  subproject process.
* The nominee must confirm willingness to take the role.
* Approval requires consensus from active subproject maintainers, or Harbor
  Maintainer approval when bootstrapping or resolving a deadlock.

## Inactivity

Anyone may step down from a reviewer or subproject maintainer role.

Inactive reviewers and subproject maintainers may be moved to emeritus status
by PR after reasonable contact attempts. The purpose is to keep ownership
accurate and make room for active contributors.

## Records

`MAINTAINERS.md` is Harbor's source of truth for Harbor Maintainers,
subproject maintainers, reviewers, and emeritus roles.

The CNCF `project-maintainers.csv` record should include Harbor Maintainers and
recognized Harbor subproject maintainer groups, using names such as
`Harbor: <Subproject>`.

Repository permissions, CODEOWNERS, and release access should match the roles
documented in `MAINTAINERS.md`.

## References

This model takes inspiration from:

* Kubernetes governance: https://github.com/kubernetes/community/blob/main/governance.md
* Kubernetes community membership: https://github.com/kubernetes/community/blob/main/community-membership.md
* CNCF subproject governance template: https://github.com/cncf/project-template/blob/main/GOVERNANCE-subprojects.md
* OpenTelemetry membership roles: https://github.com/open-telemetry/community/blob/main/guides/contributor/membership.md
* Prometheus governance: https://prometheus.io/governance/
