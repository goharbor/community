# Proposal: Single Active Replication

Author: Prasanth Baskar/[bupd](https://github.com/bupd)

PR: [https://github.com/goharbor/harbor/pull/21347](https://github.com/goharbor/harbor/pull/21347)

## Abstract

This proposal introduces a new feature that adds and option to prevent the parallel execution of replications. By adding a "Single Active Replication" checkbox in the replication policy, users can ensure that only one replication task for the same artifact is executed at a time, preventing unnecessary resource consumption, reducing bandwidth throttling, and improving replication performance.

## Background

In many Harbor deployments, scheduled replications of large artifacts often overlap, leading to unnecessary consumption of resources and reduced system performance. When multiple replications of the same artifact occur in parallel, especially for large images (e.g., 80 GB and beyond), it can strain network bandwidth and system queues, causing significant delays and timeouts. which each layer consisting bigger than 4 to 5GBs.

The common use case involves scheduled replications, which may overlap during the execution of large image replications. This causes redundant transfer of the same image across multiple replication jobs, further impacting the performance and bandwidth utilization. Hence, it is important to limit replication for the same artifact to a single execution at a time to ensure more efficient resource usage.

## Goals

- Avoid overlapping replications of the same artifact.
- Improve resource allocation by adding an option to limit to a single replication execution per policy.
- Prevent unnecessary network and bandwidth throttling by not repeating replication jobs for the same artifact.
- Enhance performance and stability, especially for large artifacts.

## Proposal

A new option, **"Single Active Replication"**, will be added in the replication policy UI to ensure that replication jobs for the same artifact do not run simultaneously. The default state will be **unchecked**, meaning replication tasks can still run in parallel unless the user opts for single execution.

When the "Single Active Replication" option is enabled, any replication task for the same artifact will not start until the current replication for that artifact finishes. This ensures that bandwidth is not overloaded and the queues are better managed.

Additionally, the implementation will involve adding a **single_active_replication** column in the replication policy in db and updating the worker execution logic to skip replication if a task is already running.

## Changes Made

- Added a **"Single Active Replication"** checkbox in the replication policy UI.
- Implemented `execution skipping` logic to prevent the start of overlapping replication tasks.
- Updated the `replication policy` model to include the **single_active_replication** flag.
- Updated replication worker logic to account for the **single active replication** constraint.
- Added a new `single_active_replication` column in the database schema for the policy.



## Benefits:

- Prevents Overlapping Replication.
- Frees up bandwidth for other operations.
- Ensures efficient transfers for large artifacts.

## Implementation

### UI

A **"Single Active Replication"** checkbox will be added in the replication policy UI. By default, it will be unchecked.

### DB Schema

Add a new column `single_active_replication` to the replication policy model:

```go
type Policy struct {
    // ...
    SingleActiveReplication bool `orm:"column(single_active_replication)"`
}
```

SQL migration:

```sql
ALTER TABLE replication_policy ADD COLUMN IF NOT EXISTS single_active_replication boolean;
```

### API

- Create Policy:

    ```rest
    POST /replication/policies
    { "single_active_replication": true }
    ```

- Update Policy:

    ```rest
    PUT /replication/policies
    { "single_active_replication": true }
    ```

