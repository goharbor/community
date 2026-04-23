# Proposal: `Refactoring log-driver & docker-version-check for Podman support`

Author: Leo / [leonidas-o](https://github.com/leonidas-o)

Discussion: 
- https://github.com/goharbor/harbor/pull/15986
- https://github.com/goharbor/harbor/issues/15105


## Abstract

Refactoring the currenctly hard coded `--log-driver=syslog` as well as cleaning up/ removing or extending all hard coded checks for docker/ docker compose, would open up the door to support running harbor using podman and podman-compose.


## Background

Red Hat Enterprise Linux and RHEL based distributions like CentOS, Rocky Linux, etc. have dropped Docker engine runtime support. Installing the docker for example requires you to add its own repository or download the binary. Podman however is officially supported and can be installed via the systems default repository.
Refactoring Harbors installation/ deployment process and gaining official podman support would also help to make harbor usable among Enterprise Linux users who are strictly required to stay with supported container runtime engines.


## Proposal

As of now Podmans logging driver for the container is not supporting the currently hard coded `syslog` option from within Harbors docker-compose file. 
- For Podman the available options are k8s-file, journald, none and passthrough, with json-file aliased to k8s-file for scripting compatibility. (Default journald). 
- For Docker the available options are json-file, logagent, syslog, journald, fluentd, elf, awslogs, splunk, cplogs, logentries and etwlogs. (Default json-file).
Either setting Harbors default log-driver to something Docker and Podman can work with or making it configurable by the user.
This leads to the following two proposals:

1. The `--log-driver=syslog` must be configurable or a default value chosen which is supported by Docker and Podman.
2. All version checks for explicitly docker or docker-compose has to be removed or extended to work with Podman.


## Non-Goals

- tbd


## Rationale

There are no alternatives but simply staying with docker support only. Advantages as mentioned, easier installation for RHEL and RHEL based distributions and users depended on official RHEL based support, ergo open up new markets.


## Compatibility

Obviously the next release of podman-compose (current stable v1.0.3) will have a changed behavior in terms of pod creation/ infra container. It must be known how the containers communicate with each other in the current implementation, localhost or dns. Therefore slight changes to a default podman configuration could be necessary. For example, as of today, it is even recommended to replace the old/default network backend `cni` with the newly introduced `netavark`.
> Asked for the next podman-compose release in here: https://github.com/containers/podman-compose/issues/379#issuecomment-1312450168


## Implementation

A commit was submitted for the docker version checks (see the github commit 15986 mentioned at the top). It wasn't created by me, so I can't speak about its quality. Also the next steps depend on if the checks should be simply removed or extended to support Podman. Maybe the core team has to take that decision. Depending on the outcome, maybe the commit 15986 can be re-used.

But before defining precise implementation steps, both points (1. log-driver, 2. docker version checks) needs to discussed to choose which way to go.
After the above mentioned changes are introduced, I can test it in my environment and create a detailed guide, how to spin it up with all Podman configurations (if any needed). I don't expect it to be that much, to be honest.

tbd
- Who?
- When?
