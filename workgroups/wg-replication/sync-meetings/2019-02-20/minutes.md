# Replication WG meeting minutes

**Date**: 2019/02/20

**Attendees**:

* Steven Z@VMware (coordinator),
* Wenkai yin@VMware,
* Fanjian kong@Qihoo360,
* Lei Yuan@Huawei,
* De Chen@Caicloud,
* Mingming Pei@Netease,
* Zhewei Lin@Tencent,
* Yan Wang@VMware

**Minutes by**: Steven Z

## Updates

1.8 timeline:
  FC: April 20th
  GA: May 20th

Dev progress updates:

* _Frank Kung_:
  * Implement policy manager (most of work is done, left some issues to discuss)
  * Start the Rest API implementation for policy manager which depends on the PR of policy manager
  * **Issues**:
    * What queries should be supported in the policy API : query policy by registry ID/name, by policy name, by the namespace
    * 1st one should be selected in the multi pagination of query parameter of the list method in policy manager interface
    * Replace `soft` deletion with `hard` deletion
    * dao created in `replication/ng/dao`
    * db table need to consider data migration
  * Target of next sync
    * Policy manager controller (done)
* _De Chen_:
  * PR for registry management (for review)
  * Target of next sync
    * Finish registry management implementation
    * Start the Docker Hub adapter work
* _Wenkai Yin_:
  * Merged flow controller implementation code
  * Raised PR for repository handler
  * Target of next sync
    * Implement replication controller
* _Mingming Pei_:
  * Execution implementation revising (70%)
  * Implement status hook approach (40%)
  * **Issues**:
    * Confusions about the status of task: appending `Initialize`
    * Add extra interface method `UpdateTaskStatus(Status)`
    * Some status of tasks are updated only when the status match the expired status
  * Target of next sync
    * Raise PRs for Execution Manager and status hooks implementations
* _Lei Yuan_:
  * PR raised for scheduler
  * Start work of HW cloud registry adapter
  * Target of next sync
    * Check the HW adapter implementation
* _Zhewei Lin_:
  * Learn the background of replication ng (next generation)
  * Start some work of adapter to Helm [chart hub](hub.helm.sh) and ChartMeseum