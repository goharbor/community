# Proposal:  Support webhook in harbor

Author: **Webhook Workgroup** Group members:

- Yan Wang@VMware ([wy65701436](https://github.com/wy65701436))
- Alex Xu@VMware ([alexvmw](https://github.com/alexvmw))
- Mingming Pei@NetEase ([mmpei](https://github.com/mmpei))
- Xiatao Guan@NetEase ([tedgxt](https://github.com/tedgxt))
- Tian Wang@NetEase ([lightof410](https://github.com/lightof410))
- Bin Fang@NetEase ([BeHappyF](https://github.com/BeHappyF))
- Qingzhao Zheng@NetEase ([qingzhao](https://github.com/qingzhao))
- Yu Zhang@NetEase ([sanqianaa](https://github.com/sanqianaa))

Discussion: None

## Abstract

Webhook is an important feature for container repository especially for CICD flow. The following events could be considered in the first phase, image pushing/pulling, image scanning, image deleting and chart uploading. 

## Background

A Webhook, in web development, is a method of augmenting or altering the behavior of a web page, or web application, with custom callbacks. 

In harbor webhook used for notifying the third party web application is not supported. And this is an important feature for a repository system.

## Proposal

This feature should support:

1. User could define his own policy which includes multiple events and multiple event handlers such as http handler and email handler(P1).
2. And the event define should be extensible. pushing image event is in need for CICD. but other events should be implemented easily including finishing scanning image, finishing replicate, delete image and so on.
3. The logs of the jobs of event triggered should be recorded, these logs  should contain the http request and http response, and could be shown on UI.
4. The hook request should be retried after failed. Now the retry time is 3 only when error is a kind of network error.
5. Webhook will be implemented in JobService framework if needed.

## Rationale

This feature will depend on harbor Job flow. and use the existing framework of JobService if needed.

This feature will make harbor support CICD flow, and one could build a "closed loop" dev-ops system easily when using harbor as a image repository.

## Implementation


![image](https://gitlab.com/pmm123/pics/raw/master/learn/harbor-webhook-ng.png)

1. Events will be triggered when related actions are executed.
2. Core will receive these events and process them in Subscribe/Notification loop.
3. Events from external or internal are fair. They will be processed by related handler.
4. These handlers are fair too. They just take their own duty.
5. We will define some handlers which mapping to webhook actions to make architecture loose enough.
6. Some events are translated to related jobs and post to JobService, some are processed in Core. e.g. event of sending a http request will be executed in JS while printing a message to stdout will be in Core.
7. Jobs will be added to related queues.
8. Workers for the special queue will fetch these jobs and process them.
9. A result will be returned from remote and all of these will be recorded in log.
10. webhook finished.

Hook payload will be: 

```go
// Image event
{
    "type": "pushImage",
    "occur_at": 1560862556,
    "event_data": [{
        "digest": "sha256:457f4aa83fc9a6663ab9d1b0a6e2dce25a12a943ed5bf2c1747c58d48bbb4917",  
        "tag": "latest"
    }], 
    "repository": {
        "date_created": 1548645673, 
        "name": "repoTest", 
        "namespace": "namespace", 
        "repo_full_name": "namespace/repoTest", 
        "repo_type": "public"
    }
}

// Helm chart event
{
    "type": "uploadChart",
    "occur_at": 1560862556,
    "event_data": [{
        "version": "0.6.0-rc1"
    }, {
        "version": "0.7.23"
    }], 
    "chart": {
        "date_created": 1548645673, 
        "name": "chartRepo", 
        "namespace": "namespace", 
        "chart_full_name": "namespace/chartRepo", 
        "chart_type": "public"
    }
}
```

#### Policy Design

Webhook policy is created by user to specify which events to subscribe and where hook sends, webhook targets is a list which contains an email address or a callback URL.

```go
// WebhookPolicy defines the structure of a webhook policy. This struct is used internally.
// Could transfer from dao model or transfer to api model.
type WebhookPolicy struct {
	ID                int64 // UUID of the policy
	Name              string
	Description       string
	ProjectID         int64  // Project attached to this policy, 0 for a global webhook
	Targets           []HookTarget
	HookTypes         []string
	CreationTime      time.Time
	UpdateTime        time.Time
	Enabled           bool
}

// HookTarget represents the target where hook will be sent. 
// It could be a url with headers, an email address and so on.
type HookTarget struct {
	Type              string
	Address           string // Target address. Url,Email etc.
	Attachment        string // attributes attached to this target
}
```

#### Job Design

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

#### HttpHandler Design

Users can define a secret in http statement in webhook policy. So it will be sent in header in http request. The format will be,

```
Authorization: Secret eyJ0eXAiOiJKV1QiLCJhbGciOi
```

and also users can input a URL with https schema. and select insecure protocol if they want.

There should be a test function which will send a templated request to remote endpoint when adding webhook policy to Harbor, this could refer to adding replication target.

#### EmailHandler Design(P1)

Not support.

#### Covered Event

|       Type        | Priority |
| :---------------: | :------: |
|     ImagePush     |    P0    |
|     ImagePull     |    P0    |
|    ImageDelete    |    P0    |
|    ChartUpload    |    P0    |
|    ChartDelete    |    P0    |
| ScanningCompleted |    P1    |
|  ScanningFailed   |    P1    |



#### Authorization Design

| Action | Project manager | Project master | Develop | Guest |
| :----: | :-------------: | :------------: | :-----: | :---: |
| Create |        Y        |       N        |    N    |   N   |
|  Edit  |        Y        |       N        |    N    |   N   |
| Delete |        Y        |       N        |    N    |   N   |
|  List  |        Y        |       Y        |    N    |   N   |
|  Test  |        Y        |       N        |    N    |   N   |

