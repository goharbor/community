# Replication WG meeting minutes

Date: 2019/01/16
Attendees: Wenkai yin@VMware, Lei Yuan@Huawei, Steven Z@VMware, De Chen@Caicloud, Mingming Pei@Netease

## Updates

* Clarify any issues of replication NG proposal if we have
  * The `DestinationNamespaces` should be adjusted from list to single one because we only support two cases: many src namespace to 1 dest namespace and keep same namespace with src for the dest
  * The job service API doc location
* Steven Z will create a independent protected code branch in harbor project for replication NG code.
  * Code checkin by PR
  * Two code reviewers are required
  * The current CI pipeline should not be broken
* Any urgent issues, throw messages in the wechat channel

## Next steps

* Check the DEV progress