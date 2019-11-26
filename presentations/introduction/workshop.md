# Harbor Workshop

This workshop guide can be used for accomplishing various tasks with Harbor. After completing all the tasks, you will have a better understanding of Project Harbor's features and functionality.

## Environment Setup & Harbor Installation

The first step is to get Harbor installed into an environment where the following scenarios can be performed. There are a few options available.

Environment Options:

1. Local Installation on Mac/Linux
2. An Ubuntu Virtual Machine on VMware Fusion or VirtualBox
3. Create an account on https://demo.goharbor.io/ (this will not allow you to perform all tasks as the user accounts are restricted)


Steps for Installation on Ubuntu VM (taken from [Official Documentation](https://github.com/goharbor/harbor/blob/master/docs/installation_guide.md)):

1. On a Ubuntu VM, Install Docker - [Ubuntu](https://docs.docker.com/v17.09/engine/installation/linux/docker-ce/ubuntu/), [Mac](https://docs.docker.com/v17.09/docker-for-mac/install/)
2. [Install Docker Compose](https://docs.docker.com/compose/install/) if you are on Ubuntu. It's already included in Docker for Mac.
3. Select either the [online or offline installer and download](https://github.com/goharbor/harbor/releases) the latest Harbor stable release
4. Download the latest [v1.10](https://storage.googleapis.com/harbor-builds/harbor-offline-installer-v1.10.0-build.2534.tgz) Harbor offline installer and use tar to extract the installer package `tar xvf harbor-<type>-installer-<version>.tgz`
5. Configure harbor.yml to use http by commenting out https, enter the correct IP address 
6. When using http, configure the ‘insecure registry’ in daemon.json as described [here](https://github.com/goharbor/harbor/blob/master/docs/user_guide.md#pulling-and-pushing-images-using-docker-client) 
Or checkout [this guide](https://docs.docker.com/registry/insecure/)
7. I.e. enter `0.0.0.0/0` into list of `insecure registries` in daemon.json located in dir `/etc/docker` by default
{
  "insecure-registries" : ["myregistrydomain.com:5000","0.0.0.0/0"]
}
8. Restart Docker engine after configuring daemon.json (with `systemctl restart docker`)
9. Install Harbor with `sudo ./install.sh --with-clair` 
(If you forget to configure daemon.json to allow insecure registry before installing Harbor, you need to restart Harbor after restarting docker engine with `docker-compose down -v` + `./prepare` + `docker-compose up -d`
10. Run `docker-compose ps` to verify all Harbor services are up and healthy
11. From your preferred browser, log into your Harbor registry with username/pw : `admin`/`Harbor12345` and create a project called `yourname-workshop`
12.  From Docker CLI, you can now `docker login` with username/pw : `admin`/`Harbor12345` and push an image to project `yourname-workshop` to verify




**If Installing Locally on Mac/Linux**

1. Create the folder `<YOUR-LOCAL-HOME-DIR>/harbor-lab/`
2. Download and extract the latest Harbor release in that directory.
3. Change the following settings in `harbor.yml`
  - `data_volume: <YOUR-LOCAL-HOME-DIR>/harbor-lab/data`
    - Then under `log:`, change:
      - `location: <YOUR-LOCAL-HOME-DIR>/harbor-lab/var/log/harbor`

In the `harbor.yml`, Change the `hostname` to a DNS or IP following the [Official Documentation](https://github.com/goharbor/harbor/blob/master/docs/installation_guide.md).  **Recommendation:** For Docker installation on local Mac/Linux, use `hostname: local.goharbor.io` in `harbor.yml` and, it will resolve to 127.0.0.1.


5. After configuring `harbor.yml`, run the setup script with `./install.sh --with-clair --with-chartmuseum` (use `sudo` on Ubuntu if needed).


### Troubleshooting

If any changes need to be made, use docker-compose to manage harbor lifecycle.

In the `harbor` folder where all files are extracted:
 - Use `docker-compose stop` to stop harbor
 - Use `docker-compose start` to start harbor

To reconfigure Harbor configuration bring down services with `docker-compose down -v` and make your changes to `harbor.yml`. Restart services with `docker-compose up -d`.


## Demo Scenarios

### Goal: Push An Image to Harbor

1. Download redis with `docker pull redis:latest`
2. In Harbor web console, create a new Project called `yourname-workshop`.
3. Retag the image with `docker tag redis:latest yourregistry/yourname-workshop/redis:latest`
4. Login to the docker CLI with `docker login yourregistry` using the default `admin` user and password `Harbor12345`.
5. Push image with `docker push yourregistry/yourname-workshop/redis:latest`
6. Go to the Images tab in harbor web console and verify image was pushed.



### Goal: As a project admin, I would like to ensure that no developer can deploy(pull) a vulnerable container

1. In Harbor web console, create a project called `yourname-cve`
2. Push two image tags into the aforementioned project by first retrieving them from Dockerhub
pull 2 images from Dockerhub
`docker pull alpine:3.8.4` (verified has CVE)
`docker pull alpine:3.10.3` (verified has no CVEs)
Now retag them
`docker tag alpine:3.10.3 yourregistry/yourname-cve/alpine:3.10.3`
`docker tag alpine:3.8.4 yourregistry/yourname-cve/alpine:3.8.4`
Push to Harbor
`docker push yourregistry/yourname-cve/alpine:3.10.3`
`docker push yourregistry/yourname-cve/alpine:3.8.4`
3. Go into the `configuration` tab of your project and check the box `Prevent vulnerable images from running`
4. Go back to your repository and scan both images one at a time (must wait a few minutes after installation so that the vulnerability database is properly populated)
5. `Docker pull alpine:3.8.4` and verify you get an error message that alpine:3.8.4 is vulnerable and can't be pulled
6. `Docker pull alpine:3.10.3` and verify that alpine:3.10.3 can be pulled



### Goal: as a project admin / developer, I would like to configure webhook notifications upon image pushes to my project

1. Create a project called `yourname-webhooks`
2. In that project, go to the Webhooks tab and simulate a webhook by configuring a webhook (listener) by setting endpoint url in web console 
    >Use https://webhook.site/#!/ as webhook receiving endpoint which will auto-generate an endpoint URL for you
    no auth header is needed for this example
    select `verify remote certificate` to use HTTPS POST over HTTP POST
    Click `test endpoint` to make sure it works and click `save`
3. push any image to your project `yourname-webhooks` as follows
    >`docker tag alpine:3.8 yourregistry/yourname-webhooks/alpine:3.8`
    `docker push yourregistry/yourname-webhooks/alpine:3.8`
4. Look at webhook listener and verify webhook payload received
5. Perform any operation listed such as push, pull, delete, or scan an image in the project to see the webhook.
6. Look at webhook listener and verify webhook payload received



### Goal: As a project admin, I would like to scan all images as they are pushed to my project and enable CVE whitelisting

1. Create a project called `yourname-scanned-on-push`
2. Turn on `scan for vulnerability on push` in configuration tab of your project
3. Push one image with no vulnerability (alpine:3.10.3), see image pushed to harbor with no CVE
4. Push another image with vulnerability (alpine:3.8.4), see image pushed to Harbor with one High vulnerability
5. Drill down into (tagged 3.8.4) to see vulnerability `CVE-2019-14697` with severity high
6. Now try `docker pull alpine:3.8.4`, which will fail as `deployment security` is enabled
7. Add the discovered CVE `CVE-2019-14697` to the `project CVE whitelist`
8. Try `docker pull alpine:3.8.4` again which should succeed this time




### Goal: As a developer, I would like to retag and delete certain tags from my project/repo

1. Create a few more tags and push them to the `workshop` project.
    1. `docker tag redis:latest local.goharbor.io/workshop/redis:v2`
	2. `docker tag redis:latest local.goharbor.io/workshop/redis:prod`
	3. `docker push local.goharbor.io/workshop/redis:v2`
	4. `docker push local.goharbor.io/workshop/redis:prod`
2. Go to the Immutable Tag tab and click on Add Rule
3. Enable complete immutability by leaving everything as `**`. Click Add.
4. Going into the images, try to delete any redis image tag. It will fail.
5. Remove the immutability rule so tags can be deleted.
6. Try using multiple rules to see what other things can be done.



### Goal: As a project admin, I'd like to set quotas on my project

1. Create a project `yourname-quota` with 5 image count + 20MB
2. Push 2 small images < 5mb to it, for example the alpine images (alpine:3.8.4, alpine:3.10.3) 
3. Now push a 10mb image ie `redis:alpine`
4. Retag `redis:alpine` as `redis:alpine2` and push this image as well
5. Notice the total artifact count went up to 4 but the second redis:alpine2 added no space since it's the same image, so has no effect on quota
6. Finally push a large image ie. `ubuntu:latest`, which is much larger than 20MB
7. Verify that push will be denied and show error message that `request failed due to quota exceeded`
8. Now as a system admin, go to `project quotas` under Administration (only accessible to system admin) and edit quota for `yourname-quota` to increase to 100MB
9. Repush the `ubuntu:latest` image and verify that push is now be successful
10. Run Garbage Collection since layers from previous push have been pushed so space needs to be freed up
Takeaway: Quotas are great to not fill up your drive with unneeded images. Pushed layers are not automatically released back and GC needs to be run.


scenario 2:
Shared layers s cenario : 
1. Create a new project called `yourname-quota2` with image count 5 and disk space 200MB
2. First pull the following 3 custom images from goharbor repo on Dockerhub
`sudo docker pull goharbor/demo1:20M`
`sudo docker pull goharbor/demo2:60M`
`sudo docker pull goharbor/demo3:160M`

Where demo1:20M's layer is shared with demo2:60M, and demo2:60M's layers are also shared with demo3:160M.

3. Retag 1st image and push as follows:
`docker tag goharbor/demo1:20M 35.166.150.163/alexquota2/shared:20M`
`docker push 35.166.150.163/alexquota2/shared:20M`
4. Check quota that 20MB occupied
5. Retag 2nd image and push as follows:
`docker tag goharbor/demo2:60M 35.166.150.163/alexquota2/shared:60M`
`docker push 35.166.150.163/alexquota2/shared:60M`
6. Check that quota is 60MB and only increased by 40MB since the first layer was shared
7. Retag 3rd image and push as follows:
`docker tag goharbor/demo3:160M 35.166.150.163/alexquota2/shared:160M`
`docker push 35.166.150.163/alexquota2/shared:160M`
8. Check that quota is 160MB and only increased by 100MB since first 2 layers were shared




### Goal: As a system admin, I would like to replicate images between registries

1. Add a registry endpoint as the target.
  1. Go to the Registries in the Administration menu.
	2. Add `docker-hub`, name it DockerHub, and click on Test Connection.
	3. Click OK.
2. Create a replication rule.
  1. Go to Replications in the Administration menu.
	2. Click on New Replication Rule.
  3. Configure the name as `golang`.
	4. Set the replication mode to `pull-based`.
	5. Set the source registry to `DockerHub` that was created earlier.
	6. For resource filter name use `library/golang` and tag `latest`
	7. Set destination namespace as `workshop`
	8. For this demo, keep the trigger as `manual`
	9. Click Save.
3. Click on the new replication rule, and click on the Replicate button.
4. Click Yes on the confirmation box.
5. Wait about 1 minute and then the success rate will change to 100%.
6. Go to the `workshop` Project and see the new golang image.

Test this out on your own doing pulls and pushes between different types of container registry offerings.


### Goal: As a project admin, I'd like to create retention policies for compliance purposes

1. Create a project called `yourname-retention`
2. push some images (particular these images in this order, since we will create a rule to retain based on push time)
        `docker tag alpine:3.6 yourregistry/yourname-retention/alpine:3.6-nightly1`  
        `docker tag alpine:3.6 yourregistry/yourname-retention/alpine:3.6-staging1`    
        `docker tag alpine:3.6 yourregistry/yourname-retention/alpine:3.6-dev1`
        `docker tag alpine:3.7 yourregistry/yourname-retention/alpine:3.7-nightly1`
        `docker tag alpine:3.7 yourregistry/yourname-retention/alpine:3.7-staging1`
        `docker tag alpine:3.8 yourregistry/yourname-retention/alpine:3.8-staging1`
        
    `docker push yourregistry/yourname-retention/alpine:3.6-nightly1`
        `docker push yourregistry/yourname-retention/alpine:3.6-staging1`
        `docker push yourregistry/yourname-retention/alpine:3.7-nightly1`
        `docker push yourregistry/yourname-retention/alpine:3.7-staging1`
        `docker push yourregistry/yourname-retention/alpine:3.8-staging1`
        `docker push yourregistry/retention2/alpine:3.6-dev1`

3. Create tag retention rule #1 -
"For the repositories matching alpine, retain the most recently pushed 1 images with tags matching *staging*"
hit `dry run` and open log to see result
dry run result: only alpine:3.8-staging1 is retained

4. Create tag retention rule #2 -
"For the repositories matching alpine, retain the most recently pushed 2 images with tags matching *staging*"
dry run result: only alpine:3.8-staging1, alpine:3.7-nightly1, alpine:3.7-staging1 are retained, *3.6* are deleted because alpine:3.7-staging1 is retained, so is alpine:3.7-nightly1 since they share same digest

5. Create tag retention rule #3 -
"For the repositories matching alpine, retain the most recently pushed 2 images with tags matching *3.6*"
dry run result: only alpine:3.6-nightly1, alpine:3.6-staging1, alpine:3.6-dev1 are retained, only 2 of 3 alpine:3.6 are retained but since last one shares the same digest with one of the retained tags, this tag will be saved as well 3.7 and 3.8 are not matched for retention and are hence deleted

6. Finally, create tag retention rule #4 -
"For the repositories matching alpine, retain the most recently pushed 1 images with tags excluding *3.6*"
dry run result: only alpine:3.8-staging1 is retained, excluding *3.6* means all *3.6* tags will not be retained, of the remaining 3, only the most recently pushed 3.8 is retained


### [OPTIONAL] Goal: As a system admin, I'd like to configure multiple image scanners (Aqua Trivy, Anchore, Clair) that multiple project admins can consume for scanning for vulnerabilities

1. Prepare the scanners: install one of the below supported external scanner engines by following the deployment guide
    1. Trivy: https://github.com/aquasecurity/harbor-scanner-trivy
    2. Anchore: https://github.com/anchore/harbor-scanner-adapter
2. Log into Harbor as a system admin. Navigate to the `Interrogation Service` under the `Administration` section of the left nav panel
3. In the `Scanner` tab, click `New Scanner` to open the wizard. Input the required name, endpoint url of the scanner you setup in the step 1 and check the option of `Skip Certification Verification` if https with self-signed cert is enabled for the scanner.
4. Click `TEST CONNECTION` to verify the configurations are correct and the scanner is reachable. Then Click `ADD` to add it to the scanner list. A success alert will popup if no errors happened.
5. Activate the new added scanner with one of the following ways:
    1. Click `SET AS DEFAULT` to set the new added scanner as default scanner of the system. That means all the project without configuring specified project level scanner will use this system default one.
    2. Navigate to your project, e.g : `kubecon`, in the `Scanner` tab, click `Edit` button to open the scanner selection dialog. From the scanner list, find your new added scanner and choose it. The project will use this one to scan the artifacts under the project. 
6. Navigate to your project, locate an image tag and click `SCAN` to start the scanning process. After scan completed, check the scan summary which indicates the overall severity and scan timestamp. Click the tag name, you can find more scan details in the opened page.
7. Back to the root of your project, refer 5b to switch the scanner engine of your project. Once successfully done, repeat step 6 and compare the two scan summaries. You`ll find differences between the two scan summaries.
8. Navigate back to the `Interrogation Service` under the `Administration` section of the left nav panel. In the `Vulnerability` tab, click the `SCAN NOW` button to start the process of scanning all the images in the system. You can check the overall progress via a progress report close to the `SCAN NOW` button.
