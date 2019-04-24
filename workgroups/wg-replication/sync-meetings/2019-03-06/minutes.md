# Replication WG meeting minutes

**Date**: 2019/03/06

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

Dev progress updates:

* _Frank Kung_:
  * Policy manager CURD(PR submitted）
  * **Issues**:
    * Support multiple source namespaces?
  * Target of next sync
    * Policy manager(done)
    * UT for policy manager
    * Investigate the Docker registry adapter
* _De Chen_:
  * Investigate the Docker Hub adapter
  * Target of next sync
    * Start the Docker Hub adapter work
* _Wenkai Yin_:
  * Refactor Adaptor interface
  * Replication operation API
  * Replication Policy management API
  * Replication Adapter management API
  * Target of next sync
    * Provide a default implement for Registry interface
    * Trigger management
    * Chart handler
* _Mingming Pei_:
  * Execution implementation revising (PR submitted)
  * Implement status hook approach (PR submitted)
  * Target of next sync
    * Execution Manager(done)
    * Status hooks implementations(done)
* _Lei Yuan_:
  * Investigate the HW registry adapter
  * **Issues**:
    * Need more namespace query parameters when listing namespaces? Will add page and size query parameters
  * Target of next sync
    * Start work of the HW adapter implementation
* _Zhewei Lin_:
  * Read the replication proposal 
  * Start some work of adapter to Helm [chart hub](hub.helm.sh) and ChartMeseum