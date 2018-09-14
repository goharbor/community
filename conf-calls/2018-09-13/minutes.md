# Meeting minutes of Harbor community conf call on 2018/09/13

## Topics

Go through and discuss what we can do in Harbor next release version (V1.7.0)

More details, please check the [slides](./community_call_2018-09-13.pptx).

## Minutes

* Before starting the main topic, Steven Zou shared the message of `Harbor V1.6.0 is released and available now!`
  * A release note with more detailed information is published to GitHub [wiki](https://github.com/goharbor/harbor/wiki/Release-1.6.0)
  * The [demos](https://github.com/goharbor/harbor/wiki/Video-demos-for-Harbor) are also updated to reflect the new changes delivered in V1.6.0
* Daniel Jiang help to go through the `p0` items which will be delivered in V1.7
  * Helm chart HA deployment
  * Chart repo UE enhancement
  * Garbage collection
  * CI work post CNCF donation
  * Support Markdown in repo description
  * Bump up clarity in UI code
  * Host UI code in "harbor-portal" container
  * Rework Admin sever and config management
  * Display build history
    * Discussion: As Angular and Clarity are upgraded to the new versions, the PR is outdated and need to rebase.
  * Support image retag
    * Discussion 1: The signature of the tag will be lost after retagging, that would be a limitation
    * Discussion 2: It will be better to expose retag function in the UI side. Draft UI mock should be provided.

* Other discussions:
  * Some proposals about how to run the community better

## Chat messages

```
00:25:12	mu shixun:	yes
00:34:28	Jonas Rosland:	If you have problem building the Docker image, please submit an issue.
00:35:27	Ruan iPhoneX:	ok, we will re-try it.
00:35:29	yan@vmware:	I can help if any issue on building images, just ask questions in the slack channel.
00:35:40	Jonas Rosland:	Thanks for reporting Ruan!
00:50:29	Jonas Rosland:	Thank you so much everyone!
```

## Recording link

For meeting recording link, please check [here](https://zoom.us/recording/share/TliR9KB5pD4wtoX9BTazSLcpIqM6HQCH_COMDNHKKD-wIumekTziMw?startTime=1536844010000).