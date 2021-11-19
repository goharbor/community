# Proposal: `Add Metrics for Jobservice`

Author: `<Qian Deng/ ninjadq>`

Discussion: `Link do discussion issue, if applicable`

## Abstract

 Job service is a key component for Harbor. In this PR we propose to add Prometheus formarted metrcis to Jobservice.

## Background

The Jobservice component in Harbor is used to managing and running async jobs like replication, gabage collection, etc. Currently there is no better way than checking the logs to understand the running status of Jobservice. But only analisys the log files is tedious and easy to neglect the serious issue. Besides, there are also some important infomations are not exposed.

## Proposal

Use Prometehus library to expose metrcis of Jobservice, the Metrics are described in following table

| Name                                | Value   | Label                                                        | Describtion                                            | Component  |
| ----------------------------------- | ------- | ------------------------------------------------------------ | ------------------------------------------------------ | ---------- |
| CPU, Memory, etc.                   |         |                                                              | exposed by Prometheus golang library                   | Jobservice |
| harbor_jobservice_info              | gauge   | node, pool, workers                                          | the information of jobservice                          | Jobservice |
| harbor_jobservice_task_total        | counter | type(`gc`,`replication`, etc.), status(`success`, `stop`,`fail`) | The number of processed tasks                          | Jobservice |
| harbor_jobservice_task_process_time | summary | type(`gc`,`replication`, etc.), status(`success`, `stop`,`fail`) | The time duration of the task processing time          | Jobservice |
| harbor_task_queue_size              | gauge   | type(`gc`,`replication`, etc.)                               | Total number of tasks                                  | Exporter   |
| harbor_task_queue_latency           | gauge   | type(`gc`,`replication`, etc.)                               | how long ago the next job to be processed was enqueued | Exporter   |
| harbor_task_concurrency             | gauge   | type(`gc`,`replication`, etc.), pool(pool ID)                | Total number of concurrency on a pool                  | Exporter   |
| harbor_task_scheduled_total         | gauge   | N/A                                                          | total number of scheduled job                          | Exporter   |

## Non-Goals

1. Add tracing on jobservice
2. Add fined grained metrics like specific job's status

## Rationale

The most important metric for Job service is the status of task queue. But collect these kind of data can not done only by jobservice component isn't enough.  Because some data are stored in Redis. So we decide to collect such kind of data from exporter. The architechture and configuration may be more complicated, but it can collect more valueble data for jobservice.

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
   * Add task queue related metrics inside jobservice
3. Add global jobservice realted metrics
   * These kind of metrics are stored in persistent storage(Redis, DB). So expose them in exporter
   * These jobs may impacted by jobservice refactoring.