# Proposal: A Go CLI Client for Harbor

Author: moooofly

Discussion: [goharbor/harbor#5703](https://github.com/goharbor/harbor/issues/5703)

## Abstract

Provide a command line interface (CLI) tool based on project harbor's REST APIs to
try to facilitate CI/CD process.

## Background

There are some common use cases:

- As an analysis tool to watch tags status and make deletion as your wish.
- As a debug tool to debug online issues, especially by checking logs, such as when replication error happens between endpoints.
- As a common tool to facilitate CI/CD process.

There are some related issues in the community:

* [goharbor/harbor#5285](https://github.com/goharbor/harbor/issues/5285) - how i can get project id by project name
* [goharbor/harbor#5165](https://github.com/goharbor/harbor/issues/5165) - Imcomplete results return by "/api/search" API
* [goharbor/harbor#5085](https://github.com/goharbor/harbor/issues/5085) - Harbor registry tag cleaner tool


## Proposal

### Overview

Currently, the implementation of `harbor-go-client` is based on harbor v1.5.0-d59c257e and swagger api version 1.4.0.

Please see [moooofly/harbor-golang-client](https://github.com/moooofly/harbor-go-client) for more details.

## Command List

The command list to be supported:

- login
- logout
- search
- project
    - check
    - create
    - delete
    - get
    - list
    - update
    - member
        - create
        - delete
        - get
        - list
        - update
    - metadata
        - create
        - delete
        - get
        - list
        - update
    - log
- statistics
- user
    - list
    - create
    - current
    - get
    - update
    - delete
    - password
    - sysadmin
- repository
    - list
    - delete
    - update
    - label
        - get
        - create
        - delete
    - tag
        - get
        - delete
        - list
        - retag
        - label
            - get
            - create
            - delete
        - manifest
            - get
        - scan
            - create
        - vulnerability
    - signature
    - top
    - scanall
- log
- job
    - replication
        - list
        - update
        - delete
        - log
    - scan
        - log
- policy
    - replication
        - list
        - create
        - get
        - update
- label
    - list
    - create
    - get
    - update
    - delete
    - resource
- replication
- target
    - list
    - create
    - ping
    - update
    - get
    - delete
    - policy
- syncregistry
- systeminfo
    - get
    - volume
    - getcert
- ldap
    - ping
    - group
        - search
    - user
        - search
        - import
- usergroup
    - list
    - create
    - get
    - update
    - delete
- system
    - gc
        - list
        - get
        - log
        - schedule
            - get
            - update
            - create
- configuration
    - get
    - update
    - reset
- email
    - ping
- chartrepo
    - health
    - chart
        - list
        - upload
        - get
        - delete
        - version
            - get
            - delete
            - label
                - get
                - create
                - delete
    - prov
    - library

### Demo

## Setup Harbor Service

<p align="center">
  <img src="https://github.com/moooofly/harbor-go-client/blob/develop/docs/00_harbor_setup_35_120.svg">
</p>

## Login-whoami-logout

<p align="center">
  <img src="https://github.com/moooofly/harbor-go-client/blob/develop/docs/01_login_whoami_logout_35_120.svg">
</p>

## Version

<p align="center">
  <img src="https://github.com/moooofly/harbor-go-client/blob/develop/docs/02_version_35_120.svg">
</p>

## Statistics

<p align="center">
  <img src="https://github.com/moooofly/harbor-go-client/blob/develop/docs/03_statistics_35_120.svg">
</p>

