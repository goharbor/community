# Proposal:  `Pull Through Proxy`

Author: `stonezdj` `ywk253100`

## Abstract

It proposes an approach to enable Harbor to support proxy a remote container registry. 

## Background

For some cases, docker nodes reside in the environment have limit access to internet or no access to the external network to public container registry, or there are too many requests to the public repository that consumes too much bandwidth or it is at the risk of being throttled by the server. there is a need to  proxy and cache the request to the target public/private container repository.

## Proposal

We can enhance the current project implementation, add a new project type proxy project, when a user create a new project in Harbor, the user can enable the proxy project feature and select a existing registry to proxy.

![new project](images/proxy/proxy-project.png)

When proxy project is created, for example, its name is "dockerhub_proxy", the previous command to pull a registry is:
```
docker pull example/hello-world:latest
```
Then the user can pull the image with the new command after login

```
docker login <harbor_servername> -u xxxx -p *****
docker pull <harbor_servername>/dockerhub_proxy/example/hello-world:latest
```

All pull request to the proxy project, if the image is not cached in the proxy project, it pull the image from the target server, dockerhub.com and serves the pull command as if it is a local image. after that, it store the proxied image to local registry. when the pull request to the same image comes the second time, it checks the latest manifest and serves the blob with local content. if the dockerhub.com is not reachable, it serves the image pull command like a normal Harbor server.

Excessive pulling from hosted registries like dockerhub will result in throttling or IP ban, the pull through proxy feature can help to reduce such risks.

## Goal

Because the proxy project need to pull images from remote registry, and also have some concurrent limiation on the request, the overall image pull performance should not be less than the 50% of the Harbor server.  

## Non-Goals

The current implementation is implement the proxy in the project level, not a whole Harbor server level, it is different with the docker distribution's [pull through proxy cache](https://docs.docker.com/registry/recipes/mirror/)

In a proxy project, the retag operation doesn’t bring any side effect to the proxy, it will be kept. the content trust can not be enabled in the proxy project. Other features related to Harbor projects, such as the project membership, label, scanner, tag retention policy, robot account, web hooks, CVE whitelist should work as they were.

The proxied artifact only includes container images.
 
## Terminology


* Target server — The original container registry server
* Proxy Server — The Harbor server that receives the request from client and proxy the request to the target server if when required.


## Compatibility

Support proxy the dockerhub.com and Harbor container registry.

## Implementation

The detail implementation of proxy cache include the following parts:

![component diagram](images/proxy/proxy-cache-comp.png)

To enable the proxy feature in Harbor, it is required to add a proxy middleware, which detects HTTP requests of docker pull command, if it is a request to search the manifest, it search it in the target server and proxied the latest manifest to the client. and also persistent the content to the local registry,  if it is a request to get a blob, it searches the blob in local, if the blob doesn’t exist, it get the blob from the target server. and store the content to the local registry. when the get blob request comes the second time, then the proxy serves the request with the cached content. When the target server is offline, the proxy serves the pull request like a normal container registry.

![pull_manifest](images/proxy/pull-manifest.png)

Because some blob size might be very large, to avoid out of memory, using the io.CopyN() to copy the blob content from reader to response writer.  It might take a long time to pull a large blob. so it is possible that there are many request request the same blob simutaniously, to avoid too many connection/request to the target server, set to setup a mutex lock for each inflight blob, make sure only one reader is created for each blob.

![pull_blob](images/proxy/pull-blob.png)

When a get manifest request comes in, the middleware parse the project name from the URL, if the current project is associated with a proxy registry,  then it handles the request with the authentication and serve the current URL.

Cached manifests and the blobs are stored in the local storage, they are stored in the same way like manifest and blobs in normal repository. In a typical docker pull command, the get request of manifest comes before requests to blobs. the proxy always receives the content of manifest before receiving blobs. thus there is a dependency check to validate all related blobs are ready before put a manifest into Harbor. It queries all dependent blobs in blob table which is updated when pushing proxied blobs.  When all dependent blobs are ready, then push the manifest into the local storage.  if it exceed the max wait time (30minutes), the current push manifest operation is quit.

In order to reduce the impact of existing project implement, proxy projects keep the most of the project function as much as possible. except for pushing image is disabled. the 
The retag operation doesn’t bring any side effect to the proxy, it will be kept. the content trust can not be enabled in the proxy project. Other features related to Harbor projects, such as the project membership, label, scanner, tag retention policy, robot account, web hooks, CVE whitelist should work as they were.

The operation log for the artifact should be recorded when pull images by proxy. 

### proxy settings

#### ProjectMetadata

When the project is created, user can select proxy project and the registry to be proxied. the IsProxy is stored in project metadata table.

#### Image Storage

If the image is pull from library/hello-world:latest, the actual storage is shared with the current registry but it will be named with
dockerhub_proxy/library/hello-world:latest, and share the same blob storage with other repos.
Use this command to pull the latest image from Harbor repository

```
docker pull <harbor_fqdn>/dockerhub_proxy/library/hello-world:latest 
```

#### PUSH

It is not allowed to push image to a proxied project, but it is supported to push to the normal project. this feature is implemented by a PUT middleware on manifest.

#### RBAC

The proxy server use the same RBAC with the existing project,  if current user has permission to access the current project, pull image and cache the images.  each role include guest, master, developer, admin can use the proxy to pull image from remote server. if current user has no permission to access the current project, it returns 404 error to the client.

#### Cached Image expire

The cached tags can be deleted from the server storage after a period (for example 1 week), and only tags are deleted, use the GC to free the disk space used by blobs. there will be a expiry date in the artifact. and when the time expires, the image will be removed.


#### Data Models

There is a project_proxy_config table to store the project proxy relationship and its proxy config

project_id | proxy_registry_id 
-----------| -----------------
   2       |      1

#### API Change

Project Metadata:

URL  | Request Body   | Response
---- | -------------- | ---------
/projects/{project_id}/metadatas/{meta_name} | { "is_proxy":"true"} | 200 - Updated metadata successfully. <br/>400 - Invalid request. <br/>401 - User need to log in first. <br/>403 - User does not have permission to the project. <br/>404 - Project or metadata does not exist. <br/>500 - Internal server errors.

Project proxy config

URL  | Request Body   | Response
---- | -------------- | ---------
/projects/{project_id}/proxyconfig/ | { "proxy_registry_id": 1 } | 200 - Updated metadata successfully. <br/>400 - Invalid request. <br/>401 - User need to log in first. <br/>403 - User does not have permission to the project. <br/>404 - Project or metadata does not exist. <br/>500 - Internal server errors.


#### Misc

Other features such as the quota, vulnerability scan and tag retention should work in the same way with the normal project. the content trust feature can not be enabled because the content trust information can not be cached.

#### Open Questions

* Move registry to src/pkg/registry from src/pkg/replication?
* Can normal project and proxy project be changed to each types? 