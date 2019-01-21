# Proposal:  Support webhook in harbor

Author: peimingming@corp.netease.com

Discussion: [webhook](https://github.com/goharbor/harbor/issues/6676)

## Abstract

Webhook is an important feature for image repository especially for CICD flow. Harbor should support the webhook mechanism to cover the related main  events: image pushing/pulling, image scanning and image deleting and so on. 

## Background

A Webhook, in web development, is a method of augmenting or altering the behavior of a web page, or web application, with custom callbacks. 

In harbor webhook used for notifying the third party web application is not supported. And this is an important feature for a repository system.

## Proposal

This feature should support:

1. user could define his own trigger policy, and this policy should  support regular expression of repo name or tag, or the list of tag.
2. and the event define should be extensible. pushing image event is in  need for CICD. but other event should be implemented easily including  finishing scanning image, finishing replicate, delete image and so on.
3. the logs of event triggered should be searched easily, these logs  should incluing the http request and http response from remote endpoint.
4. the hook request should be resend after failed. Now the retry time is 3 only when error is a kind of network error.

## Rationale

This feature will depend on harbor Job flow. and use the existing framework of JobService.

This feature will make harbor support CICD flow， and one could build a "closed loop" dev-ops system easily when using harbor as a image repository.

## Implementation

I will work on this feature and raise a PR.


The schedule is about coding finished in this month and PR will be raised before the middle of February.

the work flow should:
 [![default](https://user-images.githubusercontent.com/30788120/50583337-8aa46b00-0ea3-11e9-85dc-48660d3573b2.png)](https://user-images.githubusercontent.com/30788120/50583337-8aa46b00-0ea3-11e9-85dc-48660d3573b2.png)

1. registry triggers a notification event to harbor(actually Core) when finish pushing a manifest.
2. Core revices this event and process it in eventHandler.
3. eventHandler will invoke notificationHandler, some default  notificationHandler including webhook handler will be registered when  initialization.
4. in notificationHandler, harbor will find the related policy, do  filter and generate cresponding correlative jobs, there could be several  jobs if user defined multiple policies.
5. send Jobs to Harbor JobService, and JobService put these jobs into work queue.
6. Job will be run in JS, and will be retry if failed. log will be generated.
7. webhook finished.

Hook message will be: 

```go
// Image event 
{
    "event_type": "pushImage"
    "events": [
        {
            "project": "prj",
            "repo_name": "repo1",
            "tag": "latest",
            "full_name": "prj/repo1",
            "trigger_time": 158322233213,
            "image_id": "9e2c9d5f44efbb6ee83aecd17a120c513047d289d142ec5738c9f02f9b24ad07",
            "project_type": "Private"
        }
    ]
}

// Helm chart event
{
    "event_type": "uploadChart"
    "events": [
        {
            "project": "prj",
            "chart_name": "chart1",
            "version": "v14.0.0",
            "trigger_time": 158322233213,
            "project_type": "Private"
        }
    ]
}
```

#### policy design

Webhook target is a callback URL which may contain an Authorization token as a parameter.

```go
// WebhookPolicy defines the structure of a webhook policy. This struct is used internally.
// Could transfer from dao model or transfer to api model.
type WebhookPolicy struct {
	ID                int64 // UUID of the policy
	Name              string
	Description       string
	Filters           []models.Filter
	ProjectID         int64  // Project attached to this policy
	Target            string
	HookTypes         []string
	CreationTime      time.Time
	UpdateTime        time.Time
	Enabled           bool
}
```

#### job design

Jobs will be triggered when an related event happens. And job will be stored in DB and sent to JobService to  execute.

```go
// WebhookJob is the model for a webhook job, which is the execution unit on job service,
// currently it is used to trigger a hook to a remote endpoint by a http request
type WebhookJob struct {
   ID           int64     `orm:"pk;auto;column(id)" json:"id"`
   Status       string    `orm:"column(status)" json:"status"`
   PolicyID     int64     `orm:"column(policy_id)" json:"policy_id"`
   HookType     string    `orm:"column(hook_type)" json:"hook_type"`
   JobDetail    string    `orm:"column(job_detail)" json:"job_detail"`
   UUID         string    `orm:"column(job_uuid)" json:"-"`
   CreationTime time.Time `orm:"column(creation_time);auto_now_add" json:"creation_time"`
   UpdateTime   time.Time `orm:"column(update_time);auto_now" json:"update_time"`
}
```

#### job priority
Comparing to other kinds of job  webhook job requires real-time. Jobs should be executed as soon as events triggered.  So job priority is required. An function named 'Priority' will be added to Job.Interface.  Job queue's priority will be set when registering the job handler. Now webhook jobs's priority will be set to JobPriorityHigh while others are JobPriorityNormal.

```go
// Interface defines the related injection and run entry methods.
type Interface interface {
    ...
    // Declare the priority of job queue.(1-100000)
	// See https://github.com/gocraft/work#scheduling-algorithm
	//
	// Return:
	// uint: the priority
	Priority() uint
    ...
}

// Job Priority define (1-100000).see https://github.com/gocraft/work#scheduling-algorithm
	JobPriorityHigh = 50000
	JobPriorityNormal = 500
	JobPriorityLow = 5
```



#### authorization design

| Action | Project manager | Project master | Develop | Guest |
| :----: | :-------------: | :------------: | :-----: | :---: |
| Create |        Y        |       N        |    N    |   N   |
|  Edit  |        Y        |       N        |    N    |   N   |
| Delete |        Y        |       N        |    N    |   N   |
|  List  |        Y        |       Y        |    N    |   N   |
|  Test  |        Y        |       N        |    N    |   N   |

