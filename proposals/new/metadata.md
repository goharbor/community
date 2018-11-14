Proposal: Harbor support images replication to public cloud registry 
=======

Author: Lei Yuan

 ## Abstract
In hybrid cloud scenario, we may need to replicate harbor images to public cloud. However it is impossible to replicate harbor images to a different kind of registy. It will be great, if harbor can replicate images to public cloud directly. 
 ## Solution
Harbor should provide more flexsible structure and configuration for user to customize the replication process. At the same time, harbor should support both "push base replication" and "pull base replication" to adpat more complex network environment in hybrid cloud scenario.

 ## Proposal 
1,When harbor user submit a replicate rule, it should be able to input a project as target, for public cloud registry need to keep project structure unique.

  * UI modify: add new endpoint param "Endpoint Project" while user create replication rules.

  * Update dstRegistry's repository name with the project name that user input.

2,Harbor should expose image replication handler, for public cloud user to register their replication related interface at the replication prepare stage.

  * There are two differences between handler and webhook

	* webhook will be triggered after event happened,but the webhook results won't impact the event. handler, at the other hand, will be part of the event's logic,the event will be impacted by handler's result. 

	* handler will be as a replication configuration,and using the user's authetication at the same time. while webhook should be managed at the service level.

  * The API to create replication handler:

  	> POST /api/policies/replication/{policy_id}/handlers

```
{
	"events": "prepare_replication", (there is only one event by now, may be increased in future)
	"handler_url": "/v2/manage/namespaces",
	"abort_code" : [404,403,500], (the replicate job will abort if the job got these response code from handler) 
} 
```
  * Invoke prepare_replication handler

    this will be invoked before the replication job start running, a request will be posted to the target registry. For the target registry can do some preparing work before replication started, such as validate user authrozation, or create the target project, etc. 

    with header "Authorization" , which is the same token as docker registry v2 authentication  

    with following as body:
```
{
	"events": "prepare_replication",
	"replicate_policy_name": "yl-test"
	"source_project": "test_project",
	"target_project": "test_project",
	"target_project_public": "false",
	"replicate_deletion": false,
	"trigger": 
	{
		"kind": "Manual",
		"schedule_param": null
	}
}
```

3,Harbor better provide options for user to bypass project management when replicate.

4,At the connetction testing point,using GET instead of HEAD as the /v2 api portocal. 

5,Harbor should provide "pull base replication" from public cloud to harbor. Harbor should also be able to receive image replicate requests by two different way -- polling and webhook.
