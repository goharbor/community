Proposal: Support referrer API in proxy cache

Author: Stone Zhang

## Abstract

Harbor already implements the referrers API defined in [OCI Distribution Spec 1.1](https://opencontainers.org/posts/blog/2024-03-13-image-and-distribution-1-1/) to support the use case of querying artifacts referring to a specific artifact, such as querying signatures or SBOMs referring to an image. However, the current implementation only supports artifacts stored in the local registry and does not fetch referrers stored in the upstream registry. This proposal aims to enhance the current implementation to support fetching referrers from the upstream registry when the image is pulled from a proxy cache project.

## Motivation

Users want to get all referrers of an artifact, regardless the artifact is stored in Harbor or in the upstream registry of a proxy cache project.
For example, if a user generate a SBOM for library/ldaputils:latest in HarborA, then calls the referrer API to get the sbom, it works as expected. but it doesn't work when using proxy cache.



Set up a proxy cache project in HarborB to proxy artifacts from HarborA, then pull images by proxy cache.
```
docker pull <HarborB>/proxycache_project/library/ldaputils:latest
```
When calling the referrer API in HarborB, it only returns referrers stored in HarborB, but not the SBOM stored in HarborA.
```
GET http://<HarborB>/v2/proxycache_project/library/ldaputils/referrers/sha256:6ed0f1192837ea7e8630b95d262d5a7aa9ce84b5db2dbf99c2ca02c0a2e20046
```
The response is:
```
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": []
}
```
The current proxy cache doesn't support fetching referrers from upstream registry, this proposal is to enhance the current implementation to support this feature.

Once this feature completed, the referrer's API send GET request to the proxy cache in HarborB, it should return the same content in HarborA

```
GET http://<HarborB>/v2/proxycache_project/library/ldaputils/referrers/sha256:6ed0f1192837ea7e8630b95d262d5a7aa9ce84b5db2dbf99c2ca02c0a2e20046
```
The response should be
```
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "sha256:e1d424dc9f484622730e3308ead73ab07fa4a7616384f73abfbcc5c5aab4721a",
      "size": 767,
      "annotations": {
        "created": "2025-11-14T05:55:08Z",
        "created-by": "Harbor",
        "org.opencontainers.artifact.created": "2025-11-14T05:55:08Z",
        "org.opencontainers.artifact.description": "SPDX JSON SBOM"
      },
      "artifactType": "application/vnd.goharbor.harbor.sbom.v1"
    }
  ]
}
```

## Issues

[Harbor proxy cache doesn't proxy the referrer API](https://github.com/goharbor/harbor/issues/20808)

## Goals and Non-Goals

1. Only Harbor and dockerhub.com will be verified as the upstream registry for proxy cache projects. verification for other registries can be considered in future enhancements.

1. This feature only supports the referrers API defined in OCI Distribution Spec 1.1, accessory related features are not covered in this proposal. for example, there is an option to enable or disable the deployment security for notation or cosign signatures, because they are using the accessory related API such as:

   1. GET `/api/v2.0/projects/{project_name_or_id}/artifacts` to list artifact with accessory in the Harbor. 
   1. GET `/api/v2.0/projects/{project_name}/repositories/{repository_name}/artifacts/{reference}/accessories` to list accessories of an artifact in Harbor.
   
so the proxy cache project can not proxy the accessory related API. it means when pulling an image from a proxy cache project, the accessory API doesn't fetch the accessory information from the upstream registry. the OCI tools such as cosign and notation doesn't rely on the Harbor's accessory API to get the signature information can work with the proxy cached project because the referrer API can fetch the referrer information from the upstream registry. Harbor will switch to use the referrer API to get the sigature information by issue: https://github.com/goharbor/harbor/issues/23024.



## Solution

Add an option named `Proxy referrers API`, in the proxy cache project create dialog, check/uncheck it to enable or disable the referrers API proxying feature. When it is checked, Harbor will fetch referrers from the upstream registry and cache the content in local. When the upstream registry is offline, the local cached content can be served. If this option is not enabled, the referrers API will behave as it does with a non proxy cache project, it doesn't fetch referrers from upstream registry. the default value is disabled.

When a client, such as docker client, cosign or notation, send GET referrers API request to a proxy cache project, the following steps should be performed:

1. Check if the upstream is healthy, if not, return the cached referrers from local storage.
2. Call the upstream referrers API to get referrers list.
  2.1. If upstream registry response with HTTP 404, return the 404 to the client directly so that the client can make the decision to fall to the referrers tag API or not. 
  2.2. If the upstream registry response is not 404. but the response the format is invalid, return the empty referrer and return the local referrers to the client(fallback to local). if it is valid, merge the referrers from upstream registry and local storage, return the merged referrers list to the client. the referrer from local storage means the referrer's record in the artifact_accessory which source is from "local", because the upstream referrers information maybe cached by proxy cache project, to avoid duplicate, filter the record with source is "local", means only merge referrers generated/pushed from local registry. 
3. Cache upstream referrers list in redis for future use in background.


## Implementation Details

Add a new middleware to handle the referrers API request for proxy cache projects, it should be registered before the existing referrers API handler.

```
	root.NewRoute().
		Method(http.MethodGet).
		Path("/*/referrers/:reference").
		Middleware(metric.InjectOpIDMiddleware(metric.ReferrersOperationID)).
		Middleware(repoproxy.ProxyReferrerMiddleware()). // referrers proxy middleware
		Handler(newReferrersHandler())
```

In the `repoproxy` package, implement a new middleware `ProxyReferrerMiddleware` to handle the referrers API request for proxy cache projects.

The `ProxyReferrerMiddleware` should perform the following steps:
1. Extract the project and artifact information from the request context.
2. Check if the upstream registry can be proxied, if not, return the next handler directly.
3. Call the upstream referrers API to get the referrers list. return the referrers list if the format is valid, the upstream referrers will be cached in the redis, default TTL is 7 days, and for each cache object, its size is limited to 1MB. if the upstream referrers API call response 404, return the 404 to the client directly. if other error occurs in the proxy referrer API function, return the error to the client. 
4. If the response code is 200, cache the referrers list in the redis by URL for future use. when upstream registry is not available, the cached referrers list can be returned as referrer from upstream registry, and the it will be merged with the local referrer list. if there is no pagination parameter in the request, the referrers list return the full content of the upstream registry + local referrers list and no pagination will be applied in this case, if there is pagination parameter in the request, it will append the local referrers list to the last page of upstream referrers list and also update the pagination information in the response header.
5. If the upstream registry is unhealthy, try to get the cached referrers list from redis, if found, fetch the cached referrers list, merge it with the local referrers list and return it to the client, if not found, return the next handler to get the local referrers .

Because the proxy cache's registry interface doesn't include the referrers API, a new interface `ListReferrers` should be added to the registry client interface to support calling the referrers API in the upstream registry.

```go
type RegistryClient interface {
    // existing methods...

    // ListReferrers lists the referrers of the specified artifact.
	  ListReferrers(repository, ref string, rawQuery string) (*v1.Index, headerMap map[string][]string, error)
}
```

The authorization of the upstream referrers API call should be handled in the existing registry client interface implementation. it uses the same authorization mechanism as other API calls to the upstream registry. but it should handle the referrers API specific URL path.
The referrers API URL path is `/v2/<repository>/referrers/<subject digest>`, in the method parseScope, the registry client implementation should extract the repository from the URL path and pass it to the getToken method to get the authorization token.

The registry client provide a default implementation of the `ListReferrers` method, any registry support `/v2/<repository>/referrers/<subject digest>` API can use this default implementation in theory.

When client send GET request to an accessory only exist in the upstream registry, the Harbor of the proxy cache project will proxy the request to the upstream registry and also cache it in the local storage later. During the process of pushing the accessory to local proxy cache project, the subject middleware will create record in artifact_accessory table, if the security context is from proxycache, set its source to `proxycache`, else set it to `local`. so that the accessory source can be identified later. when merging the referrers from local storage and upstream registry in future, the source information can be used to avoid duplication.


## Database Schema Changes

Add a new varchar column `source` to the existing table `artifact_accessory` to indicate the source of the accessory, it can be `local` or `proxycache`. if they proxy cache
```
ALTER TABLE artifact_accessory IF NOT EXISTS ADD COLUMN source VARCHAR(64) DEFAULT 'local' NOT NULL;

```

### Migration

When the new `source` column is added with a default value of `local`, all existing records in the `artifact_accessory` table will be treated as sourced from the local registry. In practice, some of those records may have originated from a proxy cache upstream registry, meaning the `source` field would be inaccurate for those rows after migration.

However, this inconsistency is acceptable and self-healing: proxy cache artifacts are volatile by nature. When a client requests such an artifact again, Harbor will re-fetch it from the upstream registry and re-cache it locally, at which point the record will be written with the correct `proxycache` source value. Over time, as cached artifacts are accessed and refreshed, the stale `local` designations will be replaced with accurate source information.

No explicit data backfill is required for existing records.

## Compatibility

For Harbor older than v2.8.0, the referrers API is not supported.

For Harbor v2.8.0 - v2.14.x, the referrers API in proxy cache project doesn't fetch referrers from upstream registry, it will return empty referrers with HTTP code 200 if no referrers stored in local storage.

For Harbor v2.15.0 and later, if the `Proxy referrers API` option is enabled in the proxy cache project, the referrers API will fetch referrers from upstream registry. if the upstream registry supports the referrers API, the referrers stored in upstream registry will be returned. if the upstream registry doesn't support the referrers API, it will return 404 not found to the client directly.

If the `Proxy referrers API` option is disabled, the referrers API will behave as it does with a non proxy cache project, it doesn't fetch referrers from upstream registry. the detailed compatibility matrix is as below:


| Harbor Version            | Proxy referrers API | Upstream referrers API | Behavior                                                                                   | Typical Response |
|--------------------------|---------------------|------------------------|--------------------------------------------------------------------------------------------|------------------|
| < v2.8.0                 | N/A                 | N/A                    | Referrers API not supported                                                                | 404              |
| v2.8.0 – v2.14.x         | Not available       | Ignored                | Proxy cache does not fetch upstream; returns only local referrers; empty if none           | 200              |
| v2.15.0+ (enabled)       | Enabled             | Supported              | Fetches referrers from upstream and returns them                                           | 200              |
| v2.15.0+ (enabled)       | Enabled             | Not supported          | Returns 404 from upstream to client                                                        | 404              |
| v2.15.0+ (disabled)      | Disabled            | N/A                    | Behaves like non proxy cache; returns only local referrers; empty if none                  | 200              |





