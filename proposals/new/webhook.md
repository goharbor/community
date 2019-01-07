# Proposal:  Support webhook in harbor

Author: peimingming@corp.netease.com

Discussion: [webhook](https://github.com/goharbor/harbor/issues/6676)

## Abstract

A Webhook, in web development, is a method of augmenting or altering the behavior of a web page, or web application, with custom callbacks. These callbacks may be maintained, modified, and managed by third-party users and developers who may not necessarily be affiliated with the originating website or application. 

## Background

Webhook is an important feature for image repository especially for CICD flow. and harbor should support webhook not only the push image event  but also scan image , replicate image or deleting image event. 

## Proposal

This feature should support:

1. user could define his own trigger policy, and this policy should  support regular expression of repo name or tag, or the list of tag.
2. and the event define should be extensible. pushing image event is in  need for CICD. but other event should be implemented easily including  finishing scanning image, finishing replicate, delete image and so on.
3. the logs of event triggered should be searched easily, these logs  should incluing the http request and http response from remote endpoint.
4. the hook request should be resend after failed.

## Non-Goals

NA

## Rationale

This feature will depend on harbor Job flow. and use the existing framework of JobService.

This feature will make harbor support CICD flow， and one could build a "closed loop" dev-ops system easily when using harbor as a image repository.

## Compatibility

NA

## Implementation

I will work on this feature and raise a PR.

scheduler is about coding finished in this month and PR will be raised before the middle of February.

the work flow should:
 [![default](https://user-images.githubusercontent.com/30788120/50583337-8aa46b00-0ea3-11e9-85dc-48660d3573b2.png)](https://user-images.githubusercontent.com/30788120/50583337-8aa46b00-0ea3-11e9-85dc-48660d3573b2.png)

1. registry triggers a notification event to harbor(actually Core) when finish pushing a manifest.
2. Core revices this event and process it in eventHandler.
3. eventHandler will invoke notificationHandler, some default  notificationHandler including webhook handler will be registered when  initialization.
4. in notificationHandler, harbor will find the related policy, do  filter and generate cresponding correlative jobs, there could be several  jobs if user defined muilty policies.
5. send Jobs to Harbor JobService, and JobService put these jobs into work queue.
6. Job will be run in JS, and will be retry if failed. log will be generated.
7. webhook finished.

Hook message will be: 

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
            "eventType",
            "PUSH"
        }
    ]
}

## Open issues (if applicable)

NA
