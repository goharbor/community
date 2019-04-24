# Replication WG meeting minutes

**Date**: 2019/02/26

**Attendees**:

* Steven Z@VMware (coordinator),
* Wenkai yin@VMware,
* Fanjian kong@Qihoo360,
* Lei Yuan@Huawei,
* De Chen@Caicloud,
* Mingming Pei@Netease,
* Zhewei Lin@Tencent,
* Yan Wang@VMware

**Minutes by**: Wenkai Yin

## Updates

PR https://github.com/goharbor/harbor/pull/7021 needs review from all members

Dev progress updates:

* _Frank Kung_:
  * Policy manager CURD(PR submitted）
  * **Issues**:
    * Is the trigger manager the same with flow controller?
  * Target of next sync
    * Policy manager(done)
    * Policy management API (done)
* _De Chen_:
  * Update PR for registry management according to the comments
  * Target of next sync
    * Finish registry management implementation
    * Start the Docker Hub adapter work
* _Wenkai Yin_:
  * Implement replication controller
  * Repository handler
  * Chart handler(WIP)
  * Target of next sync
    * Refactor Adaptor interface
    * Chart handler
    * Replication operation API
    * Trigger management
* _Mingming Pei_:
  * Execution implementation revising (PR submitted)
  * Implement status hook approach (PR submitted)
  * **Issues**:
    * Where the `dao` should be put? Create a new directory under `replication/ng`
    * Should we put the code of hook under the directory `replication/ng`? Yes
  * Target of next sync
    * Execution Manager(done)
    * Status hooks implementations(done)
* _Lei Yuan_:
  * PR raised for scheduler
  * Target of next sync
    * Start work of the HW adapter implementation
* _Zhewei Lin_:
  * Read the replication proposal 
  * Start some work of adapter to Helm [chart hub](hub.helm.sh) and ChartMeseum