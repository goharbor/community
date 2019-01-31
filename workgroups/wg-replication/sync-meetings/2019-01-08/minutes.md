# Replication WG meeting minutes

Date: 2019/01/08
Attendees: Wenkai yin@VMware, Fanjian kong@Qihoo360, Lei Yuan@Huawei, Steven Z@VMware, De Chen@Caicloud, Mingming Pei@Netease

## Updates

* Go through the replication design proposal PR to finalize the design
  * Refine the adapter interface definition and reach agreement on the adapter framework
  * Reach agreement on the data transfer handler way to cover the data transferring for image and helm chart
  * Refine the policy model definition
  * Discuss and refine the resource data transfer handler interface
* Discuss the authentication methods for different registries
  * Provide authentication helper for different authentication types (basic, bearer token) to authenticate the related requests
* Discuss and plan the draft work assignments
  * Design the specs and interfaces - Steven Z@VMware together with workgroup
  * Implement the registry adapter management (with transfer handlers management) - Steven Z@VMware
  * Implement replication flow controller - Steven Z@VMware
  * Implement replication controller - Wenkai Yin@VMware
  * Implement scheduler - YuanLei@Huawei
  * Implement replication manager - Mingming Pei@Netease
  * Implement hooks to listen the status of tasks - Mingming Pei@Netease
  * Implement registry management - De Chen@CaiCloud
  * Implement policy management - Fanjian Kong@Qihoo360
  * Implement the data transfer handlers for resource type image and chart - Wenkai Yin@VMware

## Next steps

* Create epic and high-level tasks for the work in GitHub repo - Steven Z@VMware
* Review and comment the replication design proposal PR - All
* Start to do some code work now -All