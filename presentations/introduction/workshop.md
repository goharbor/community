# Harbor Workshop

The workshop guide can be used for accomplishing various tasks with Harbor. After completing all the tasks, you will have a better understanding of Project Harbor's features and functionality.

## Environment Setup & Harbor Installation

The first step is to get Harbor installed into an environment where tasks can be performed. There are a few options available.

Environment Options:

1. Local Installation on Mac/Linux
2. An Ubuntu Virtual Machine on VMware Fusion or VirtualBox
3. Create an account on https://demo.goharbor.io/ (this will not allow you to perform all tasks as the user accounts are restricted)

Steps for Installation (taken from [Official Documentation](https://github.com/goharbor/harbor/blob/master/docs/installation_guide.md)):

1. Install Docker - [Ubuntu](https://docs.docker.com/v17.09/engine/installation/linux/docker-ce/ubuntu/), [Mac](https://docs.docker.com/v17.09/docker-for-mac/install/)
2. [Install Docker Compose](https://docs.docker.com/compose/install/) if you are on Ubuntu. It's already included in Docker for Mac.
3. Select either the [online or offline installer and download](https://github.com/goharbor/harbor/releases) the latest Harbor stable release
4. Use tar to extract the installer package `tar xvf harbor-<type>-installer-<version>.tgz`

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
2. Go to Harbor and create a new Project called `workshop`.
3. With the carrot of `Push Image`, copy the command to retag the docker image that was downloaded.
4. Retag the image `docker tag redis:latest local.goharbor.io/workshop/redis:latest`
5. Login to the docker CLI with `docker login https://local.goharbor.io/` using the default `admin` user and password `Harbor12345`.
5. Copy the command to push the image to repository, change the IMAGE[:TAG] to match your new tag and push. `docker push local.goharbor.io/workshop/redis:latest`.
6. Go to the Images tab and look at the new image that was pushed.


### Goal: As a project admin, I would like to ensure that no developer can deploy(pull) a vulnerable container

1. Go into the `workshop` project.
2. Create a policy for vulnerability scanning in the configuration tab with Low and Automatically scan on push.
3. Retag the original redis image and push the new image tag into the project.
	1. `docker tag redis:latest local.goharbor.io/workshop/redis:v1`
	2. `docker push local.goharbor.io/workshop/redis:v1`
4. Go to the redis in the repository and manually scan it.
5. On your local client, remove the image with `docker rmi local.goharbor.io/workshop/redis:v1`
6. Try to pull the image with `docker pull local.goharbor.io/workshop/redis:v1`. Take note of the failure message.
7. Go to the Configuration tab and Remove the policy and save. Pull again and it will work.


### Goal: as a project admin / developer, I would like to configure webhook notifications upon image pushes to my project

1. In the `workshop` project, go to the Webhook tab.
2. To simulate a webhook endpoint, go to https://webhook.site and copy the unique URL.
3. Configure a webhook (listener) by pasting endpoint url in web console. No Auth Header is needed for Authentication for this example. Select `verify remote certificate` to use HTTPS over HTTP.
4. Test the endpoint to make sure it works. Look at https://webhook.site to see the POST operation is complete.
5. Click on Continue to complete setup.
6. Do any operation listed such as push, pull, delete, or scan an image in the project to see the webhook. View the JSON payload to see the information received.


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

1. Create a new project named `quota` with image count of 2 and 100MB in size.
2. Retag and push the redis image to this project
  1. `docker tag redis:latest local.goharbor.io/quota/redis:v1`
	2. `docker push local.goharbor.io/quota/redis:v1`
3. Go into the `quota` project and view the summary tab to see the used count and space.
4. Retag it two more times and try to push. Notice artifact count goes up but the 2nd image adds no space since it's the same image. So no effect on quota for storage. Look at the error on step 4 when pushing more images than allowed.
  1. `docker tag redis:latest local.goharbor.io/quota/redis:v2`
	2. `docker tag redis:latest local.goharbor.io/quota/redis:v3`
	3. `docker push local.goharbor.io/quota/redis:v2`
	4. `docker push local.goharbor.io/quota/redis:v3`
5. Go to `Project Quotas` under Administration and edit the `quota` project to increase the size or image count if needed. Any re-push will be successful.
6. Run Garbage Collection since layers from previous push have been pushed so space needs to be freed up. Quotas are great to not fill up your drive with unneeded images. Pushed layers are not automatically released back and GC needs to be run.


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

We will only keep images that have been tagged `prod`.

1. In the `workshop` project, go to the Tag Retention tab.
2. Click on `Add Rule`
3. Keep `**` for all the repositories and set `By image count or number of days` to `retain always`. Set tags from `**` to `prod`. Click Add.
4. On the bottom half of the screen, click on `Dry Run`.
5. Click on the retention run and look at the log for each. The golang image will be deleted because it doesn't have an image that matches the `prod` tag. The redis image won't be deleted because `prod` tag is the same image as the rest.
6. To see this in more action push more images such as
  1. `docker tag alpine:3.6 local.goharbor.io/workshop/alpine:3.6-nightly1`
  2. `docker tag alpine:3.7 local.goharbor.io/workshop/alpine:3.7-nightly1`
  3. `docker tag alpine:3.7 local.goharbor.io/workshop/alpine:3.7-staging1`
  4. `docker tag alpine:3.8 local.goharbor.io/workshop/alpine:prod`
	5. `docker push local.goharbor.io/workshop/alpine:3.6-nightly1`
	6. `docker push local.goharbor.io/workshop/alpine:3.7-nightly1`
	7. `docker push local.goharbor.io/workshop/alpine:3.7-staging1`
	8. `docker push local.goharbor.io/workshop/alpine:prod`
7. Run the dry run again and you will find only the `alpine:prod` image will remain on retention.
8. Try creating multiple rules for different images and tags to see what happens.
