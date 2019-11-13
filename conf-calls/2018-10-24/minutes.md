# Meeting minutes of Harbor community conf call on 2018/10/24

## Topics

Early preview for 1.7 new features online GC and Helm chart repository enhancements.

More details, please check the [slides](./community_call_2018-10-24.pptx).

## Minutes

* First, **_Steven Zou_** gave a quick updates about Harbor.
  * DEV Progress
    * `Online GC` feature is ready.
    * `HA by Harbor Helm Chart` is under verification testing.
    * `Helm Chart repository enhancements` is ready.
    * Rel **V1.6.1** is released (Bump Clair to V2.0.6).
    * Feature `retag` contributed by cd1989@CaiCloud is merged into master.
    * Feature `image build history` contributed by kofj@360 is merged into master.
  * CNCF related
    * CI/CD pipeline refactoring work is almost done. The related design is documented in the [PR 8](https://github.com/goharbor/community/pull/8)
    * Governance model is merged.
  * Update proposal status
  * Propose to use issues with `help wanted` as a good start
  * Encourage community to contribute FAQs
  * Meeting topic appending flow
  
* Then, **_Mia Zhou_** demo online GC and Helm chart repository enhancements.

## Chat messages

```
00:31:39	rogan:	When would V1.7.0 be released?
00:32:59	CNCF Harbor:	Dec
00:38:53	Herman Zhu:	Gc过程中，还可以push 镜像到harbor嘛？
00:38:59	Yan Wang:	no
00:39:17	Yan Wang:	harbor is in Read-Only
00:39:28	Herman Zhu:	好的
00:41:57	William Zhang:	So it's mean that when somebody is pushing an image to harbor, the GC job would be fail?
00:41:59	mu shixun:	the push is processing,gc will wait the push is complete?
00:43:04	William Zhang:	ok, I got it, thx!
00:48:48	Neng Kong:	哈哈
00:52:09	SpringWar:	this is a httpserver?
00:52:41	Yan Wang:	which part do you mean?
00:53:09	SpringWar:	helm chart repos
00:53:27	rogan:	Could the Helm Chart be uploaded by API?
00:53:33	Yan Wang:	yes
00:54:30	CNCF Harbor:	helm push
00:54:39	wei:	cncn 上海  有关于 harbor的么？
00:54:47	Yan Wang:	yes
00:54:49	Herman Zhu:	kubecon
00:54:57	wei:	kubecon 
00:55:01	wei:	i mean 
00:56:25	rogan:	How to used the Helm Charts uploaded to harbor?
00:56:38	rogan:	use
00:56:49	Yan Wang:	please read the doc
00:57:41	Herman Zhu:	ok thx 88
00:57:42	William Zhang:	bye
```

## Recording link

For meeting recording link, please check [here](https://zoom.us/recording/share/T4uMWlhuQp4Hzlp-gX6ILpBlD7XexDkOZ40UWD6urd2wIumekTziMw?startTime=1540386198000).
