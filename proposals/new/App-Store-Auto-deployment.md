# Proposal: `App Store by Auto-deployment`

Author: `Ruan HE/ Wukong`

Discussion: `Link do discussion issue, if applicable`

## Abstract

Harbor hosts both image registry and Helm chart. 
This proposal describe an app store feature which combines both these 2 functions. 
Through this feature, end-users will be able to directly deployment their Helm release.  

## Background

Based on the current Harbor, in order to launch a Helm release, end-users need to:
1. copy the corresponding Helm chart to the target k8s cluster
2. configure the values.yaml of the chart
3. launch a Helm release
This proposal provides a feature to automatize all these steps. 

## Proposal

This proposal describes the feature of app store by auto-deployment for Harbor. 
Through this feature, end-users will be able to choose a Helm chart app, a target k8s cluster and namespace, and deploy directly a Helm release. 

## Non-Goals

[Anything explicitly not covered by the proposed change.]

## Rationale

[A discussion of alternate approaches and the trade offs, advantages, and disadvantages of the specified approach.]

## Compatibility

[A discussion of any compatibility issues that need to be considered]

## Implementation

We will provide a frontend to enable dynamic configuration of Helm values.yaml, and a backend to send the configured Helm chart to the target k8s cluster and launch a release. 
We will also provide the module to manage ongoing Helm releases.  

## Open issues (if applicable)

[A discussion of issues relating to this proposal for which the author does not know the solution. This section may be omitted if there are none.]
