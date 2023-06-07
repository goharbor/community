# Proposal: `Blocking CVE allow push`

Author: `Arnaud Clerc`

Discussion: N/A

## Abstract
<img width="642" alt="image" src="https://github.com/goharbor/community/assets/23419677/1992718a-77db-4ee0-b8a0-5aaccb8e0cf6">
<img width="846" alt="image" src="https://github.com/goharbor/community/assets/23419677/89b9f723-c1fd-48c1-9f06-a3577cf8719d">

when setting a registry with imutable tags, with an exception pattern and blocking images with CVE to work:
- Regular images work as itended (all are imutable except those matching the exception)
- Images with CVE becomes imutable (exception pattern ignored), the pull method is expected to prevent them to be exposed, but CVE cannot be fixed by overwritting the image tag.

## Background

In order to allow an iterative approch of developping images, and fixing CVE, the registry should allow images tag to be overwritten while blocking the pull method

## Proposal

Add settings to specify which actions should be blocked when an image is reported as having CVE.
e.g: block pull: yes/no  and  block push: yes/no

## Non-Goals

Messing with other well-defined processes I suppose ?

## Rationale

the only current solution is to iterate over new tags or to whitelist the CVE.
first option messes with the Iterative workflow, second creates security breach

## Compatibility

Current setting is blocking all actions, transition should make the splitted sub-parameters match the actual behaviour.
if currently block images with CVE, new parameters should be all block (and vice-versa)

## Implementation

Project Contributor should add a sub-menu at the specified configuration to match proposal needs and graphical chart.
<img width="837" alt="image" src="https://github.com/goharbor/community/assets/23419677/5aa62cd5-4197-4694-9c86-435730e713d3">

## Closed issues

[`original issue`](https://github.com/goharbor/harbor/issues/18792)
