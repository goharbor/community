# Proposal: Integrate Harbor with Open Policy Agent

Author: Prahalad Deshpande

## Abstract
This proposal introduces an integration between Harbor and the [Open Policy Agent](https://www.openpolicyagent.org/). This integration will allow users to evaluate and enforce custom policies on images being stored and retrieved from Harbor. Additionally, the integration would also allow a variety of security and compliance enforcement checks to be performed as a part of the build and deploy pipelines by exposing a uniform set of APIs.

The motivation behind this proposal is the Common Vunerability Schema Specification for the Cloud Native Workload

## Background
Harbor currently has support for scanning images for OS vulnerabilities using the [pluggable scanner framework](https://github.com/goharbor/pluggable-scanner-spec). Using the framework, end users can use OS vulnerability scanners of their choice to understand the OS vulnerabilities present within the system. However, reporting capabilities of Harbor with respect to the security and compliance posture of the images persisted within it is very minimal and is restricted to providing a summarized aggregate for the High, Medium and Low vulnerabilities within the images. There are some other crucial limitations such as:
* The scanning for vulnerabilities is scoped to images within a project of which the end user is a member
* The scanning is restricted to OS vulnerabilties.
* There is no mechanism available for the end users to utilize the results of the scan to make further actionable decisions  for e.g. quarantining the image or prevent creation of Pod workloads from these images in Kubernetes clusters.
* There is also no mechanism right now to "slice and dice" the results of the vulnerability evaluation.

This per project scoped scanning fails to address critical security use cases of the enterprise security administrator who is more concerned with finding answers to the following questions:
* What are the **Critical** vulnerabilities present in my **Harbor registry**?
* Which images are impacted by **CVE-12345** which has been flagged as business critical?
* Which Helm charts use images with **Critical** vulnerabilities?
* Where can I get access to a summary report on a regular cadence?
* What **Services** out in the field use an image containing **CVE-12345**?
* I have a set of enterprise wide "Acceptance for Use" critieria that must be satisified. How can I identify images that satisfy these criteria and those that do not?
* How can I share the best practice checks that I have designed with my enterprise partner organizations so all maintain the same level of compliance

Additionally, from the dev-ops perspective; it is not possible to build a deployment criteria like below:
* Do not deploy a service S which uses images containing a **Critical** vulnerability **V**
* Fail the creation of Helm charts if they use an image with **Critical** vulnerabilities.
  
As can be seen from the use cases above; there is a requirement to persist the results of a scan or vulnerability evaluation in a format that supports ad-hoc querying as well as presentable within a report.

Additionally, there also exists a critical requirement for the end user to be able to author complex policies that can evaluate the results of an image scan and produce an output that flags the image as matching or failing the acceptance criteria and also share the policies across departments to implement and enforce set of best practices uniformly.

## Proposal
To address the above requirements and use cases, an integration between Harbor and [Open Policy Agent](https://www.openpolicyagent.org/) is proposed.
Open Policy Agent (OPA) is the policy authoring and evaluation framework that is being adopted widely by the Cloud Native Computing Foundation. Refer to [OPA Integrations](https://www.openpolicyagent.org/docs/latest/ecosystem/) to see a set of compelling and interesting integrations.
Given the increasing adoption of OPA framework and the flexibility it introduces to author and evaluate custom policies; integrating Harbor with OPA will introduce rich policy evaluation capabilities within Harbor in addition to opening up to other potential integrations with the tools for enforcement of IT GRC compliance in the cloud native ecosystem

The next sections describe the architectures and workflows for integrating Harbor with OPA

### Harbor Policy Agent 

The **Harbor Policy Agent** provides policy evaluation and reporting capabilities within the Harbor ecosystem. A component view of the policy agent is shown below


The core components of the policy evaluation and reporting layer are
* Policy Agent 
* PostgresSQL DB
* Elasticsearch

#### Policy Agent
The **Policy Agent** contains all the required components for processing OPA policies, evaluating them and then persisting the results of the evaluation to the Postgres DB and Elasticsearch store. Each layer within the **Policy Agent** performs a specific responsibility
* Vulnerability Data Fetch layer - responsible for loading vulnerability an scan data from a set of data stores. The data stores could be based out of a File system or a Database.
* Policy layer - responsible for Policy storage, retrieval and evaluation using th OPA framework. The layer has been further detailed in sections below.
* Storage Layer - responsible for providing the required storage abstractions to various data stores for the policy evaluation results and optionally any additional data.
* Reporting layer - responsible for exposing a set of REST APIs,  for querying policy and evaluation data and metrics.

#### PostgresSQL DB
The PostgresSQL DB will store the results of the policy evaluation process in a normalized form that allows for ad-hoc query of the data.

#### ElasticSearch
The Elasticsearch data store will store the results of the policy evaluation indexed by the text contents so that a Full Text Search capability is available on the policy data and the policy evaluation results.



