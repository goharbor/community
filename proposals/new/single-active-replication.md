# Proposal: Single Active Replication

Author: Prasanth Baskar/[bupd](https://github.com/bupd)

Discussion & PR: [https://github.com/goharbor/harbor/pull/21347](https://github.com/goharbor/harbor/pull/21347)

## Abstract

This proposal introduces a new feature that adds and option to prevent the parallel execution of replications in a given replication policy. By adding a "Single Active Replication" checkbox in the replication policy, users can ensure that only one replication task for the same replication policy is executed at a time, preventing unnecessary resource consumption, reducing bandwidth throttling, and improving overall replication performance.

## Problem

Currently, Harbor allows multiple replication executions of the same policy to run in parallel. When policies are scheduled frequently and involve large artifacts (e.g., 1 GB+), overlapping executions may:
- Copy the same big artifact layers
- Consume unnecessary bandwidth and IOPS
- Cause throttling or failures in low-bandwidth environments
- Result in exponential performance degradation
This issue is exacerbated when artifact sizes increase and scheduling intervals are frequent.

## User Stories
### Story 1
As a user with Harbor deployed across multiple regions, I rely on scheduled replication policies to keep them synchronized. The constant problem I face is that these scheduled replications often overlap, leading to the same policy being run simultaneously. I desperately need replications for a given policy to run sequentially, not concurrently.

### Story 2
As a user with a 1 Mbit connection, I need to maintain two Harbor registries as identical as possible. I need to ensure my scheduled replication policies don't overwhelm my network. When large artifacts are involved, current concurrent replication attempts for the same policy lead to severe latency and excessive resource consumption due to replication jobs for the same policy piling up.


## Goals
- Add an option to avoid overlapping replications in the same replication policy.
- Use the option to limit to a single active replication execution per policy.
- Prevent unnecessary network and bandwidth throttling by not repeating replication jobs for the same replication policy.

## Non Goals
This proposal does not address
- The same artifact being replicated simultaneously by different replication policies.
- There is no per-artifact locking or de-duplication mechanism.
- Tasks already running before this will not be interrupted.

## Proposal

A new option, **"Single Active Replication"**, will be added in the replication policy UI to ensure that replication jobs for the same replication policy do not run simultaneously. The default state will be **unchecked**, meaning replication tasks can still run in parallel unless the user opts for single execution.

When the "Single Active Replication" option is enabled, any replication task for the same replication policy will not start until the current replication for that policy finishes. This ensures that bandwidth is not overloaded.


## Benefits:
- Prevents Overlapping Replication.
- Frees up bandwidth for other operations.
- Ensures efficient transfers for large artifacts.
- Ensures no bandwidth is wasted.


## Changes Made

- Added a **"Single active replication"** checkbox in the replication policy UI.
- Implemented a best-effort check to avoid concurrent executions of the same replication policy by inspecting ongoing replication tasks.
> Note: No locking is enforced, there is no lock or unlock logic in the database, Core, or Jobservice.
- if any previous replications for the same policy are still running. the new execution is skipped. thereby enforcing single active replication.
- Updated the `replication policy` model to include the **single_active_replication** flag.
- Added a new `single_active_replication` column in the database schema for the policy.


## Implementation

### UI

A **"Single Active Replication"** checkbox will be added in the replication policy UI. By default, it will be unchecked.

![image](https://github.com/user-attachments/assets/a6d10236-577b-4249-9763-7b8584c2a426)

![Screenshot_2025-01-08_18-44-27](https://github.com/user-attachments/assets/3dcc0d84-68dc-49a1-a51d-b578189cb244)

### Harbor Core
A new condition is added in the replication flow checking if single_active_replication is enabled for the replication policy. if a replication policy has single_active_replication enabled, the system first checks the database for any currently running executions of that policy.
- If a execution with running status is found, a new replication execution record is created  but **marked as "skipped"** instead of replication being executed normally.
- If no active executions are found, the system proceeds with the normal replication flow, initiating the new replication job as usual.


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
    {
      "single_active_replication": true
    ...other fields omitted for brevity
    }
    ```

- Update Policy:

    ```rest
    PUT /replication/policies/1
    {
      "name": "shceduled-replication",
      "single_active_replication": true
    ...other fields omitted for brevity
    }
    ```

