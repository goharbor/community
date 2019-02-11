# Meeting minutes of Harbor community conf call on 2018/10/10

## Topics

Introduce, discuss and collect feedback from the Harbor governance model.

More details, please check the [slides](./community_call_2018-10-10.pptx).

## Minutes

* First, **_Steven Zou_** gave a quick updates about Harbor.
  * CNCF related
    * CI/CD pipeline refactoring work is almost done. The related design is documented in the [PR 8](https://github.com/goharbor/community/pull/8)
    * Governance model is building. The doc is proposed in [PR 1](https://github.com/goharbor/community/pull/1). The details of governance model would introduced in this meeting.
  * DEV Progress
    * `Online GC` feature is almost there, will arrange a demo in next meeting.
    * `HA by Harbor Helm Chart` is also almost ready, will be published after verification testing done.
    * `Helm Chart repository enhancements` left UI work development
    * Rel **V1.6.1** is on the way, which includes a critical fix to the Clair issue (Bump Clair to V2.0.6).
* Then, **_Henry Zhang_** introduced the Harbor sessions and activities during the KubeCon Shanghai conference.
* Last, **_James Zabala_** gave the community an introduction of the Harbor governance model. Talked about the key points of the governance model. To learn more details, please refer to [james's slides](harbor-community-call-10oct2018.pptx).

## Chat messages

```
00:18:31	Neng Kong:	can you listen voice from me？
00:18:50	Neng Kong:	sorry
00:18:56	jie wang:	yes
00:19:29	Neng Kong:	mobile phone default open voice. sorry
00:38:46	Frank Kung:	reviewing
00:38:59	James Zabala:	Great, thanks Frank!
00:39:31	Frank Kung:	OK
00:39:37	mu shixun:	OK
00:39:57	James Zabala:	Thanks everyone!
00:40:08	Frank Kung:	thx
00:41:01	Shane Utt:	Is this meetup a good place to ask more general harbor questions for a newcomer
00:41:05	Shane Utt:	?
00:41:06	James Zabala:	Yes of course :)
00:41:48	CNCF Harbor:	Governance model is documented in PR: https://github.com/goharbor/community/pull/1
00:42:01	Shane Utt:	yes one sec
00:42:26	Shane Utt:	I can't seem to use audio.
00:42:42	Shane Utt:	Will do thanks James :)
00:42:46	Shane Utt:	Sure
00:42:58	Shane Utt:	my question is about HA, I see 

https://github.com/goharbor/harbor/issues/3582 
00:43:04	Shane Utt:	
and https://github.com/goharbor/harbor/issues/327
00:43:16	Shane Utt:	and I understand generally that https://github.com/goharbor/harbor-helm has some upcoming HA stuff
00:43:28	Shane Utt:	Right ok, that's what I understood.
00:43:31	James Zabala:	:)
00:43:41	Shane Utt:	I just felt figuring out where HA was is a bit confusing for a newcomer
00:43:47	Shane Utt:	I wanted to ask if there's something I'm missing.
00:43:59	Shane Utt:	I appreciate all the work, Harbor is awesome.
00:44:03	Shane Utt:	Yes, k8s
00:44:28	Shane Utt:	Sounds good. Put in my first docs PR recently, thanks for merging it, hoping to become more involved love the project!!
```

## Recording link

For meeting recording link, please check [here](https://zoom.us/recording/share/GbVH9evjq4GDXGN9mGC0ZFYxPeINEzQkLw26E0of6R6wIumekTziMw?startTime=1539176657000).
