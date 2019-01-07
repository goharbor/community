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
4. the hook request should be resend after failed.

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

```
 {
    "events": [
        {
            "project": "prj",
            "repoName": "repo1",
            "tag": "latest",
            "fullName": "prj/repo1",
            "triggerTime": 158322233213,
            "imageId": "9e2c9d5f44efbb6ee83aecd17a120c513047d289d142ec5738c9f02f9b24ad07",
            "projectType": "PRIVATE",
            "eventType": "PUSH"
        }
    ]
}
```

#### policy design

Webhook target is a callback URL which may contain an Authorization token as a parameter.

```go
// HookTarget is a web address which will receive a POST request when hook is triggered
// It should be acknowledged with a status code 200 
// or hook will be resent until reaching the max times
type HookTarget string

// HookType is the type of the webhook
type HookType string

// WebHookPolicy defines the structure of a webhook policy.
type WebHookPolicy struct {
	ID                int64 // UUID of the policy
	Name              string
	Description       string
	Filters           []Filter
	HookTypes         []HookType // The subscribed event types
	ProjectIDs        []int64  // Projects attached to this policy
	HookTarget        HookTarget // target that the webhook event will send to
	CreationTime      time.Time
	UpdateTime        time.Time
}
```



#### job priority
Comparing to other kinds of job  webhook job requires real-time. Jobs should be executed as soon as events triggered.  So job priority is required. An attribute named 'prior' will be added to JobMetadata  struct. 

```go
// JobMetadata stores the metadata of job.
type JobMetadata struct {
   JobKind       string `json:"kind"`
   Prior         int    `json:"prior"`
   ScheduleDelay uint64 `json:"schedule_delay,omitempty"`
   Cron          string `json:"cron_spec,omitempty"`
   IsUnique      bool   `json:"unique"`
}
```



#### authorization design

| Action | Project manager | Project master | Develop | Guest |
| :----: | :-------------: | :------------: | :-----: | :---: |
| Create |        Y        |       N        |    N    |   N   |
|  Edit  |        Y        |       N        |    N    |   N   |
| Delete |        Y        |       N        |    N    |   N   |
|  List  |        Y        |       Y        |    N    |   N   |
|  Test  |        Y        |       N        |    N    |   N   |

