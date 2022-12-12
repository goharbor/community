# Harbor Feature Lifecycle Proposal

Authors: Roger Klorese
Reviewers: 
Date: Apr 11, 2022

## Introduction

New features and capabilities for Harbor are initially proposed and considered through the documented  feature process. The feature lifecycle applies once a feature is accepted for initial implementation.  Note that this parallels the Kubernetes lifecycle.

## Stages

The lifecycle includes the following stages:

- __Experimental__: Some of the basic functionality of the feature as it was proposed is implemented. The feature may be further implemented, or existing functionality may change based on feedback.  

If the feature receives significant negative feedback in the Alpha stage, it may be deprecated in any release and removed from the following release - in other words, its deprecation window is one release. The deprecation process is described below.
- Stable: the functionality delivered in the Beta, potentially modified and improved by Beta user feedback, is included, accepted by the community, and fully tested. Changes to the functionality once a feature is accepted as Stable must be requested via GitHub issues and are subject to review by maintainers if relatively minor, or if major, must go through the proposal process. 

Once a feature is Stable, it is not expected to change rapidly, and users should be able to count on its being in the project code for a reasonably long period, such that they can depend on it for usage for periods that can be well accommodated by their maintenance cycles. Once a feature is accepted as Stable, it may be deprecated in a release and removed after two releases.

## Deprecation Process

Any contributor may introduce a request to deprecate a feature or an option of a feature by opening a feature request issue in the goharbor/harbor GitHub project. The issue should describe why the feature is no longer needed or has become detrimental to Harbor, as well as whether and how it has been superseded. The submitter should give as much detail as possible.

Once the issue is filed, a discussion period begins which ends at the beginning of the second community meeting after the opening of the issue, and is held at the community meeting and on the issue itself; the person who opens the issue or a maintainer should add that date and time in a comment in the issue as soon after the issue is opened as possible.

The feature will be deprecated by a supermajority vote of 50% plus one of the project maintainers at the time of the vote tallying, which is 72 hours after the end of the community meeting that is the end of the comment period. (Maintainers are permitted to vote in advance of the deadline, but should hold their votes until as close as possible to hear all possible discussion.) Votes will be tallied in comments on the issue. 

Non-maintainers may add non-binding votes in comments to the issue as well; these are opinions to be taken into consideration by maintainers, but they do not  count as votes. They should follow the K8s/CNCF convention of +1/0/-1 to approve/abstain/disapprove, and it is courteous for non-maintainers to mark their votes as “nb” (for non-binding).

If the vote passes, the deprecation takes effect in the subsequent release, and the removal follows the schedule above.

## Deprecation Window

The deprecation window is the period from the release in which the deprecation takes effect through the release in which the feature is removed. During this period, only critical security vulnerabilities and catastrophic bugs should be fixed.
