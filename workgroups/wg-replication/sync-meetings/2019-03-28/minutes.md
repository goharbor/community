# Replication WG meeting minutes

**Date**: 2019/03/28

**Attendees**:

* Steven Z@VMware (coordinator),
* Wenkai yin@VMware,
* Fanjian kong@Qihoo360,
* Lei Yuan@Huawei,
* De Chen@Caicloud,
* Mingming Pei@Netease,

**Minutes by**: Wenkai Yin

## Updates

Dev progress updates:

* _Frank Kung_:
  * Target of next sync
    * Bug fix and clean up the TODO list
    * Implement the adapter for docker registry
* _De Chen_:
  * Target of next sync
    * Bug fix and clean up the TODO list
    * Implement the adapter for docker hub
* _Wenkai Yin_:
  * Test the replication basic framework and fix bug
  * Target of next sync
    * Bug fix and clean up the TODO list
    * Implement the adapter for Harbor
* _Mingming Pei_:
  * Target of next sync
    * Bug fix and clean up the TODO list
* _Lei Yuan_:
  * Target of next sync
    * Bug fix and clean up the TODO list
    * Implement the adapter for huawei registry

## Step2 task assignment 

### Code Review

| Module | Code | Owner |
|--------------|-----------------|--------------------------------------------------|
| Registry Management| src/replication/ng/registry, src/replication/ng/dao |Wenkai Yin|
| Policy Management| src/replication/ng/policy, src/replication/ng/dao |Steven Zou|
| Operation| src/replication/ng/operation, src/replication/ng/dao |Fanjian Kong|
| Adapter| src/replication/ng/adapter | Mingming Pei |
| Transfer| src/replication/ng/transfer | Lei Yuan |
| Others| src/replication/ng/event, src/replication/ng/util | Lei Yuan |

### Clean up `TODO` list
All group members need to check the `TODO` items of yourself and complete them at the end of this sprint.

### Complete the unit tests
All group members need to go through the code and complete the unit tests.
