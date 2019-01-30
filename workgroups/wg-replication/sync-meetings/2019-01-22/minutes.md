# Replication WG meeting minutes

Date: 2019/01/22
Attendees: Wenkai yin@VMware, Fanjian kong@Qihoo360, Lei Yuan@Huawei, Steven Z@VMware

## Updates

### _De Chen_

Will submit a code PR of registry management part within this week.

### _Fanjian Kong_

Review current policy management code, will program some code to implement the new policy management before next sync meeting.

### _Lei Yuan_

Review current code of Harbor. will submit code PR of scheduler in next week.
    
_Question: Do we have document for job service?_

>Answer: Yes, it's under `src/jobservice`

**_Issue: How to authenticate the requests? What's the design of auth handler?_**
>Solution: cache tokens in central component or exchange token on demand.
Let's exchange token on demand.
Wenkai: reuse old code to implement the V2 token flow (see https://github.com/goharbor/harbor/tree/master/src/common/utils/registry/auth)


**Follow-up: we need to create a service account for the Harbor jobservice to let it follow the V2 flow - Followed by Wenkai**

### _Wenkai Yin_

Raise code PR to build up replication job framework (not include handlers themselves); data models are also included in this PR.

Create a `ng` sub folder under the replication, please put code under this new folder

### _Ming_

Review harbor code. next step: setup framework code of replication manager and maybe the main code of hooks.

_Question: Some concerns about use array to store multiple src registries in the policy model?_

>Wenkai: If the system admin create a policy and set multiple src namespaces, what will that policy look like in the perspective of the project admin who is admin of only one of the src namespace ?
>Steven: All the policies created by the system admin will be read-only mode in the project admin perspective

### All

Policies in system and project scope/ update the proposal PR to reflect the restrictions.
  