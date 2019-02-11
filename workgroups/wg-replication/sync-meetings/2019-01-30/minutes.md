# Replication WG meeting minutes

Date: 2019/01/30

Attendees: Wenkai yin@VMware, Fanjian kong@Qihoo360, Lei Yuan@Huawei, Steven Z@VMware, De Chen@Caicloud, Mingming Pei@Netease

## Updates

First, Steven Z updates some workgroup operation stuff:

* Create replication workgroup document folder in the `goharbor/community` repository to keep related docuemnts or meeting minutes of sync meetings
* Introduce the replication NG DEV epic created in the `harbor` repository

Second, component owners update the DEV progresses:

_Fanjian Kong_:

* Owner of `policy management` feature
* Programing some code, working on the polciy management API. - Overall progress: 5%
* need to accelerate DEV progress

_Wenkai Yin_:

* Owner of `replication operation`, `adapter registry` and `controller` components
* PR of replication wrapper job has been merged
* PR of flow controller has been submitted

_De Chen_:

* Owner of `registry management` component
* Programing code of this part - Overall progress: 50%
* Do reseearch for the DockerHub adapter

_Mingming Pei_:

* Owner of `hooks` and `replication manager` (rename it to `Execution Manager`) components
* `Execution Manager` is ongoing - Overall : 5%
* Programing code of `hooks` - Overall: 40%

_Lei Yuan_:

* Owner of `scheduler` component
* Need to extend the interface of `scheduler` to support stop job
* Almost done, will submit PR within this week

## Issues

Issue 1: What's the meaning of pull/push mode in the replication policy UI wizard? It is not defined in the policy model.

> It's only a feature in the UI front end as a quick way for user to define the policy.
> Pull mode means the dest registry is the current Harbor, the system will automatically fill in the dest registry info with current Harbor
> Push mode means the src registry is the current Harbor, similar with pull mode, the system will automatically fill in the src registry info with current Harbor

Issue 2: Missing `Overwritten` settings in the replication policy wizard UI?

> It should be there

Issue 3: Support enable/disable the replication policy?

> Yes, we support

Issue 4: What we should handle the data schema and API endpoints? Migration and comparability should be considered?

> API endpoints changes will break the API comparability
> Migration script should be updated to cover the database schema changes

Isuse5: Ignore the OAuth access token authentication mode in registry management as no use cases existing so far?

> OK

Issue 6: Should make sure legacy harbor can replicate with new harbor?

> YES

Issue 7: There might be issues when listing namespaces from the DockerHub? No API to list other public namespaces outside of the account?

> Let user input the other namespaces.

Issue 8: Some metadata like the `publicity` of namespace may need to replicate to the destination registry

> Namespace can bring some metadata. Whether or not identify or use depends on the concrete implementations of the adapters.

## Next Steps

* Chinese Spring Festival is coming, will cancel the sync meetings of next and next next
* Enhance collaboration, especially between the owners whose components have overlaps with each other