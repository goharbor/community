# Proposal: `Add Metrics for Jobservice`

Author: `<Qian Deng/ ninjadq>`

Discussion: `Link do discussion issue, if applicable`

## Abstract

 Job service is a key component for Harbor. In this PR we propose to add Prometheus formarted metrcis to Jobservice.

## Background

The Jobservice is a key compont in Harbor, which is used to managing and running async jobs link replication, gabage collection, etc. Currently there is no better way than checking the logs to understand the running status of Jobservice. But only analisys the log files is tedious and easy to neglect the serious issue. Besides, there are also some important infomations are not exposed.

## Proposal

Use Prometehus library to expose metrcis of Jobservice, the Metrics are described in following table

| Name                                            | Value   | Describtion                           |
| ----------------------------------------------- | ------- | ------------------------------------- |
| CPU, Memory, etc.                               |         | exposed by Prometheus golang library  |
| harbor_jobservice_http_inflight_requests        | gauge   | Inflght request number                |
| harbor_jobservice_http_request_total            | counter | total request number                  |
| harbor_jobservice_http_request_duration_seconds | summary | distribution of request duration      |
| harbor_jobservice_task_success_rate             | gauge   | the sucess rate of task in jobservice |
| harbor_jobservice_queue_size                    | gauge   | the size of task queue in jobservice  |
| harbor_jobservice_task_process_time             | summary | distribution of task duration         |
| harbor_jobservice_running_task                  | gauge   | running task number                   |
| harbor_jobservice_pending_task                  | gauge   | pendding task number                  |



## Non-Goals

1. Tracing for jobservice
2. Other component's metrics

## Rationale

[A discussion of alternate approaches and the trade offs, advantages, and disadvantages of the specified approach.]

## Compatibility

The format of metrics shuold follow the Prometheus standard. 

The implementation should consistent with other components.

## Implementation

We can seperate the implementation into three stages.

1. Setup configurations and enabled baisc metrics

   * Add metric related item in jobservice configuration files
   * Setup prepare script for jobservice metrics
   * expose basic metrics in jobservice

2. Add jobservice specific metrics

   * Add http request metrics

   * Add task queue related metrics inside jobservice

3. Add global jobservice realted metrics

   * These kind of metrics are stored in persistent storage(Redis, DB). So expose them in exporter
   * These jobs may impacted by jobservice refactoring.