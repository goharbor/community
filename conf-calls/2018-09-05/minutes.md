# eeting minutes of Harbor community conf call on 2018/09/05

## Topics

* Harbor project latest updates by Harbor team [5 min]
* Harbor community updates [5 min]
* Harbor V1.6.0 early preview (Part 2):
  - Demo: Replicate with label filter by Wenkai Yin from Harbor team [10 min]
  - Demo: LDAP group supporting by Stone Zhang from Harbor team [15 min]
* Proposal discussions
  - If hide the top repositories list as default [5 min]
  - Any other opinions about the DB migration (to one unified PostgreSQL) [10 min]
  - Tag new image on the portal [10 min]

More details, please check the [slides](./community_call_2018-09-05.pptx).

## Minutes

* Steven Zou give a quick updates about the Harbor project from three parts
  - Progress of changes for the CNCF donation
  - Harbor V1.6.0 release is delayed because of the Clair updating issue which is already fixed. The GA date is postponed to early next week. During this time, the RC3 is ready for trying.
  - The ongoing plan of Harbor V1.7.0
    * Ryan from Tencent proposed their concerns of the process of making the V1.7.0 plan. They want that process more transparent and any big changes should be let the community know.
    * Daniel and Steven Z explain the root reason of causing the confusions. Mainly because Harbor is just join the CNCF big family and most of the processes, especially the governance model, are still under building. We're in the transition state and fortunately we have started the work to setup the model and workflow to let the community easily follow.
* Steven updates the community things
  - Community project Harbor.Tagd  lead by @nlowe from HylandSoftware is onboarded
  - Demo list is moved from README to a separate wiki page and will continuously updated if there are new ones created
  - We’ll show up at CEUC@HangZhou at 09/16/2018

* Discuss some technical proposals
  - Proposal of removing the top repositories list from the login page is discused, voted and approved.
  - No obvious upset on the action of migrating multiple different databases to the unified PostgreSQL in V1.6.0.
    * In future, maybe we can define a storage specification and interfaces to let the community to implement drivers to support other databases if they like to.
  - De Chen from CaiCloud leading the discussion of the API of tagging a new image.
    * Vote to select the 2nd API pattern as the formal one.

* Stone zhang from VMware Harbor team gave us a great demo about the LDAP group new feature whcih will be released in the V1.6.0.

More details, please check the [slides](./community_call_2018-09-05.pptx).

## Chat messages

```
00:29:45	ruanhe:	here is an exmaple of our proposal: https://github.com/goharbor/harbor-helm/issues/17
00:32:02	Jonas Rosland:	Thanks for adding that @ruanhe!
00:32:27	ruanhe:	there is another team from Tencent who is willing to contribute to Harbor
00:38:09	mushixun:	Remove it
00:38:18	ruanhe:	agree
00:56:58	ruanhe:	2nd
00:57:02	Daniel Jiang:	2nd
00:57:03	yan@vmware:	2
00:57:09	CNCF Harbor:	2nd
00:57:19	De Chen:	Thanks
00:57:54	mushixun:	how to control the project permission
00:58:08	Steven Ren:	Could other member comments on the google docs for the design>
00:58:34	Steven Ren:	should we define a process to review it in a more former way in future?
00:59:06	De Chen:	> how to control  the project permission Harbor already has permisison controll on project, I just follow it .
00:59:54	De Chen:	> Could other member comments on the google docs for the design>
> should we define a process to review it in a more former way in future? I think the proposal issue is a better place to comments and review
00:59:56	CNCF Harbor:	I think the proposal is in a github issue
01:00:00	ruanhe:	maybe we can use CNCF's procedure
01:00:03	CNCF Harbor:	everyone can comment on it
01:00:38	De Chen:	https://github.com/goharbor/harbor/issues/5778
01:00:48	mushixun:	OK
01:02:47	CNCF Harbor:	seems different CNCF projects have different procedure. But most are similar, propose, review and vote
01:03:38	Steven Ren:	Thanks, next we should go review the issue, but not from a new google docs for design, in my humble opinion.
01:04:43	De Chen:	Sure, google docs it just for ease of today’s presentation.
01:04:57	Steven Ren:	thank you!
01:04:58	CNCF Harbor:	we have ‘proposal’ template
01:05:27	CNCF Harbor:	comments can be applied to the proposal issue
01:07:54	Jonas Rosland:	I hope the new issue templates are useful for everyone when adding a new bug report, issue or proposal. If there’s something missing from them please let us know!

```
## Recording link

For meeting recording, please check [here](https://zoom.us/recording/share/CcX6hf25ylO9lKD9PRPu2xCgxDdVZOOE099qmYD-WvOwIumekTziMw?startTime=1536152587000).