<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Proposal: `Artifact Processor Extender`](#proposal-artifact-processor-extender)
  - [Abstract](#abstract)
  - [Background](#background)
  - [Motivation](#motivation)
  - [Goals](#goals)
  - [Non-Goals](#non-goals)
  - [Implementation](#implementation)
  - [In-tree processor](#in-tree-processor)
    - [Config schema](#config-schema)
    - [GeneralProcessor](#generalprocessor)
      - [```GeneralProcessor``` Implement](#generalprocessor-implement)
  - [Out-of-tree processor](#out-of-tree-processor)
      - [HTTPProcessor and Processor Extender](#httpprocessor-and-processor-extender)
      - [`HTTPProcessor`](#httpprocessor)
      - [Processor Extender](#processor-extender)
    - [Configuration file `processors.yaml`](#configuration-file-processorsyaml)
    - [Artifact Data Access](#artifact-data-access)
      - [Policy Check Interceptor](#policy-check-interceptor)
      - [OAuth 2 Bearer Tokens](#oauth-2-bearer-tokens)
      - [Robot Accounts](#robot-accounts)
    - [Development Process](#development-process)
      - [First Iteration: HTTPProcessor and Extender without Auth](#first-iteration-httpprocessor-and-extender-without-auth)
      - [Second Iteration: Registration](#second-iteration-registration)
      - [Third Iteration: Auth in the Processor Extender](#third-iteration-auth-in-the-processor-extender)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Proposal: `Artifact Processor Extender`

Author:

- Yiyang Huang [@hyy0322](https://github.com/hyy0322) \<huangyiyang@caicloud.io\> (Corresponding Author)
- Ce Gao [@gaocegege](https://github.com/gaocegege)
- Jian Zhu [@zhujian7](https://github.com/zhujian7)

Links:

- Discussion: [goharbor/harbor#12013](https://github.com/goharbor/harbor/issues/12013)
- Slides: [Feature Request: Harbor Artifact Processor Extender](https://docs.google.com/presentation/d/1rX7v9IhXjXEAmbJP29nkSU2RJXUrpLJujL8iemqcjnU/edit#)

## Abstract

Harbor v2.0 makes Harbor the first OCI-compliant open source registry capable of storing a multitude of cloud-native artifacts like container images, Helm charts, OPAs, Singularity, and much more. It found strong demand on extending artifact types to support more complex scenarios. But the artifact authors now have to implement the processing logic in Harbor Core, which is not extensible.

The current design might go against the adoption of Harbor in industries since there are always proprietary artifact types. Thus we design the artifact processor extender to address the problem in this proposal. When new custom artifact types are registered into Harbor Core, the core service will communicate with the remote artifact processor extender via RESTful API. Artifact-specific logic will keep in the extender, and the Harbor Core will be artifact-neutral.

## Background

There are four types of artifacts, which are image, helm v3, CNAB, OPA bundle, supported by Harbor. Each of them implements its processor to abstract metadata into artifact model defined by harbor. If users want to define a new kind of artifact, they have to implement the processor logic in Harbor Core service, which greatly limits the scalability and extensibility of Harbor.

## Motivation

When we use Harbor to store custom artifacts, we cannot get the expected result from the API provided by Harbor `{}/api/v2.0/projects/{}/repositories/{}/artifacts/{}`. For example, we store a new artifact using [caicloud/ormb](https://github.com/caicloud/ormb), which is a OCI artifact specification for Machine Learning models, we get the result from the API:

```
{
  "digest": "sha256:123aa..",
  "id": 2,
  "manifest_media_type": "application/vnd.oci.image.manifest.v1+json",
  "media_type": "application/vnd.caicloud.model.config.v1alpha1+json",
  "project_id": 2,
  "repository_id": 1,
  "size": 12927980,
  "tags": [
    {
      "artifact_id": 2,
      "id": 2,
      "immutable": false,
      "name": "v1",
      "pull_time": "0001-01-01T00:00:00.000Z",
      "push_time": "2020-05-15T04:04:19.516Z",
      "repository_id": 2,
      "signed": false
    }
  ],
  "type": "MODEL"
}
```

But when we store the Helm Chart and send request to the same API, we get more attributes. The extra attributes store the content of the config layer of the Helm Chart. Thus we can think the result is self-contained.

```diff
{
+  "extra_attrs": {
+    "apiVersion": "v1",
+    "appVersion": "0.8.0",
+    "description": "Host your own Helm Chart Repository",
+    "home": "https://github.com/helm/chartmuseum",
+    "icon": "https://raw.githubusercontent.com/helm/chartmuseum/master/logo2.png",
+    "keywords": [
+      "chartmuseum",
+    ],
+    "maintainers": [
+      {
+        "email": "opensource@codefresh.io",
+        "name": "codefresh-io"
+      }
+    ],
+    "name": "chartmuseum",
+    "version": "1.8.2"
+  },
  "digest": "sha256:123aa..",
  "id": 1,
  "manifest_media_type": "application/vnd.oci.image.manifest.v1+json",
  "media_type": "application/vnd.cncf.helm.config.v1+json",
  "project_id": 2,
  "repository_id": 2,
  "size": 12927980,
  "tags": [
    {
      "artifact_id": 1,
      "id": 1,
      "immutable": false,
      "name": "v1",
      "pull_time": "0001-01-01T00:00:00.000Z",
      "push_time": "2020-05-15T04:04:19.516Z",
      "repository_id": 2,
      "signed": false
    }
  ],
  "type": "CHART"
}
```

The self-contained response is also necessary for these user-defined artifact types. Or we cannot use Harbor directly for most scenarios. The `extra_attrs` field is processed by the Helm Chart processor, which is an implementation of artifact processor interface `Processor`.

The current design of the artifact processor is shown in Fig. 1. `Processor` interface is defined in Harbor Core, and there are four implementations for different types which embeds `base.IndexProcessor` and `base.ManifestProcessor`.

<p align="center">
<img src="images/artifact-processor-extender/current-design.png" height="330">
<p align="center">Fig. 1 Current Design of Harbor Artifact Processor</p>
</p>

When artifact authors extend the artifact types, they implement corresponding processor logic in Harbor Core, as shown in Fig. 2. For example, there will be four new processor implementations in Harbor Core with at least four different maintainers from different communities if we want to support these four artifact types.

<p align="center"> 
<img src="images/artifact-processor-extender/extend-problem-1.png" height="330">
<p align="center">Fig. 2 More Harbor Artifact Processor in Harbor Core</p>
</p>

Besides this, there will be more proprietary artifact types in industries, just like Kubernetes CRDs, as shown in Fig. 3. Each artifact vendor has to maintain their own fork to keep their proprietary artifact types, which may make Harbor a fragmented platform.

<p align="center">
<img src="images/artifact-processor-extender/extend-problem-2.png" height="330">
<p align="center">Fig. 3 Fragmented Problems in Harbor</p>
</p>

## Goals

This proposal is to:

- Design the new processor to extend artifact types in runtime.
- Keep non-invasive to the current built-in processors, at the same time.

## Non-Goals

This proposal is not to:

- Support whitelist for artifact types. [goharbor/harbor#12061](https://github.com/goharbor/harbor/issues/12061)

## Implementation

To address these problems, we propose a new feature **artifact processor extender** in Harbor Core. There are two ways to achieve our goals. One is in-tree processor which we define config JSON object in a certain format in the config layer of an artifact. The other is out-of-tree processor which define data format in HTTP API. 

## In-tree processor

Contributions about in-tree processor:  

- Define a JSON schema for the config layer of an artifact.
- The new processor struct ```GeneralProcessor``` to support user-defined artifacts.

### Config schema
manifest
```
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
   "config": {
      "mediaType": "application/vnd.custom.artifact.config.v1+json",
      "size": 11830,
      "digest": "sha256:2ffd3c3d87aac9d99c93ba84fbec6ae59c9946cbef2531bb1dc5e02fb905971a"
   },
   "layers": []
}
```
As is showed above, we can define a media type ```application/vnd.custom.artifact.config.v1+json``` to show it is a media type of user-defined artifact config


config layer
```
{ 
    // user defined config
    // abstract metadata will use this config data as extra attrs
    "key1": ...,
    "key2": ...,

    // harbor defined config
    "harbor": {
        // artifact config
        "artifactMetadata":{
            // artifact type
            "type": "ORMB",
            // artifact media type
            "mediaType": "application/vnd.caicloud.ormb.xxx",
            // additions
            "additions": [
                {
                    // content type
                    "contentType": "plain"
                    // addition type name, one of addition type
                    "type": "type_xxx",
                    "digest": "sha256:xxx"
                },
                {
                    "contentType": "json",
                    "type": "type_xxx",
                    "digest": "sha256:xxx"
                },
                {
                    "contentType": "markdown"
                    "type": "type_xxx",
                    "digest": "sha256:xxx"
                },
                ...
            ]
        }
    }
}
```
Mainly there are two parts about this config. One is custom for user to put their config, the other is harbor defined config.

### GeneralProcessor

The Processor interface is defined in Harbor Core.

```go
// Processor processes specified artifact
type Processor interface {
	// GetArtifactType returns the type of one kind of artifact specified by media type
	GetArtifactType() string
	// ListAdditionTypes returns the supported addition types of one kind of artifact specified by media type
	ListAdditionTypes() []string
	// AbstractMetadata abstracts the metadata for the specific artifact type into the artifact model,
	// the metadata can be got from the manifest or other layers referenced by the manifest.
	AbstractMetadata(ctx context.Context, manifest []byte, artifact *artifact.Artifact) error
	// AbstractAddition abstracts the addition of the artifact.
	// The additions are different for different artifacts:
	// build history for image; values.yaml, readme and dependencies for chart, etc
	AbstractAddition(ctx context.Context, artifact *artifact.Artifact, additionType string) (addition *Addition, err error)
}
```
We need config layer digest for every functions defined above. So we need to do a little change about the ```Processor``` interface. ```artifact.Artifact``` is needed in all fuctions.

```go
// Processor processes specified artifact
type Processor interface {
	// GetArtifactType returns the type of one kind of artifact specified by media type
	GetArtifactType(artifact *artifact.Artifact) string
	// ListAdditionTypes returns the supported addition types of one kind of artifact specified by media type
	ListAdditionTypes(artifact *artifact.Artifact) []string
	// AbstractMetadata abstracts the metadata for the specific artifact type into the artifact model,
	// the metadata can be got from the manifest or other layers referenced by the manifest.
	AbstractMetadata(ctx context.Context, manifest []byte, artifact *artifact.Artifact) error
	// AbstractAddition abstracts the addition of the artifact.
	// The additions are different for different artifacts:
	// build history for image; values.yaml, readme and dependencies for chart, etc
	AbstractAddition(ctx context.Context, artifact *artifact.Artifact, additionType string) (addition *Addition, err error)
}
```

#### ```GeneralProcessor``` Implement
```
func (g *GeneralProcessor) GetArtifactType(artifact *artifact.Artifact) string {
	configLayer := pullBlob(artifact.manifest.config.digest)
	return configLayer.harbor.artifactMetadata.type
}

func (g *GeneralProcessor) ListAdditionTypes(artifact *artifact.Artifact) []string {
	configLayer := pullBlob(artifact.manifest.config.digest)
	// Traverse configLayer.harbor.artifactMetadata.additons array to get all addition type
	return []string{configLayer.harbor.artifactMetadata.additons.type...}
}

func (g *GeneralProcessor) AbstractMetadata(artifact *artifact.Artifact) error {
	configLayer := pullBlob(artifact.manifest.config.digest)
    // do something with configLayer json, remove harbor object, keep user config
    userConfig := ...
	artifact.ExtraAttrs = configLayer.userConfig
}

func (g *GeneralProcessor) AbstractAddition(artifact artifact *artifact.Artifact, additionType string) (addition *Addition, err error) {
	configLayer := pullBlob(artifact.manifest.config.digest)
	// make a map map[type]struct{
	//                         contentType
	//                         digest
	//                     }
	additionDigest := map[type]struct.digest
	additionLayer := pullBlob(additionDigest)
	return Addition{
		Content: additionType,
		Content: additionLayer,
	}
}
```

<p align="center">
<img src="images/artifact-processor-extender/in-tree-workflow.png" height="600">
<p align="center">Fig. 4 Workflow of Pushing an Artifact using the General Processor</p>
</p>


## Out-of-tree processor

Some contributions have been made about out-of-tree processor:

- The new Processor struct `HTTPProcessor` to support artifact processor extender feature for extending custom artifact types. The current design of `Processor` interface is not changed at the same time, thus the new feature will not affect the existing supported types like OCI Image, CNAB and Helm Chart.

- The new configuration file `processors.yaml` to register artifact types with processors in runtime.

- The similar mechanism to Scanner to support Auth in `HTTPProcessor`, which will be used to pull manifests from the Registry.


#### HTTPProcessor and Processor Extender

The Processor interface is defined in Harbor Core and we do not propose any change for it.

```go
// Processor processes specified artifact
type Processor interface {
	// GetArtifactType returns the type of one kind of artifact specified by media type
	GetArtifactType() string
	// ListAdditionTypes returns the supported addition types of one kind of artifact specified by media type
	ListAdditionTypes() []string
	// AbstractMetadata abstracts the metadata for the specific artifact type into the artifact model,
	// the metadata can be got from the manifest or other layers referenced by the manifest.
	AbstractMetadata(ctx context.Context, manifest []byte, artifact *artifact.Artifact) error
	// AbstractAddition abstracts the addition of the artifact.
	// The additions are different for different artifacts:
	// build history for image; values.yaml, readme and dependencies for chart, etc
	AbstractAddition(ctx context.Context, artifact *artifact.Artifact, additionType string) (addition *Addition, err error)
}
```

We propose a new implementation of the `Processor` interface, `HTTPProcessor`. The design of the processor is shown in Fig. 5. The processor acts as a proxy to the processor extender. There are two new components in the architecture:

1. Remote Processor API - HTTP RESTful API between Harbor and remote processor.  
    - The API itself is defined and maintained by Harbor.
    - Authentication specifics are out-of-scope, but should be supported using the HTTP ```Authorization``` header.
2. Remote Processor Extender - Long-running RESTful service that implements the Remote Processor API to extract artifact data.  
    - The extender is deployed outside Harbor Core.
    - The extender has independent configuration management, and deployment lifecycle.

<p align="center">
<img src="images/artifact-processor-extender/arch.png" height="330">
<p align="center">Fig. 5 Design of HTTPProcessor</p>
</p>

For a remote processor, the functions defined in ```Processor``` interface can be abstract to HTTP service API. By using these APIs, Harbor Core can communicate with remote HTTP processor extender.

```
GET  {remote-processor-endpoint}/artifacttype
GET  {remote-processor-endpoint}/additiontypes
POST {remote-processor-endpoint}/abstractmetadata
POST {remote-processor-endpoint}/abstractaddition
```

#### `HTTPProcessor`

`HTTPProcessor` makes harbor more extensible to allow users using their own processor extender to process the custom artifacts. The `HTTPProcessor` acts as a proxy to the extender. The pseudo code is here.

```go
type HTTPProcessor struct {
	MediaType    string
	ProcessorURL string
	Client       *http.Client
}

func (h *HTTPProcessor) GetArtifactType() string {
	/*
		http request to remote processor service
	*/
	return ""
}

func (h *HTTPProcessor) ListAdditionTypes() []string {
	/*
		http request to remote processor service
	*/
	return nil
}

func (h *HTTPProcessor) AbstractMetadata(ctx context.Context, manifest []byte, artifact *artifact.Artifact) error {
	/*
		http request to remote processor service
	*/
	return nil
}

func (h *HTTPProcessor) AbstractAddition(ctx context.Context, artifact *artifact.Artifact, additionType string) (addition *Addition, err error) {
	/*
		http request to remote processor service
	*/
	return nil, nil
}
```

The workflow of pushing a custom artifact to Harbor with the help of `HTTPProcessor` is shown in Fig. 6. The Harbor works as a proxy to the registry when the user uploads the content layers and config layer. Harbor ensures that the repository exists. Then Harbor puts the manifest to the registry. After that, Harbor will check if the artifact by digest exists. In this step, Harbor will use `Processor.AbstractMetatda` in `Abstractor` to abstract the metadata ant keep in the artifact.Artifact model.

<p align="center">
<img src="images/artifact-processor-extender/workflow-new.png" height="600">
<p align="center">Fig. 6 Workflow of Pushing an Artifact using the HTTPProcessor</p>
</p>

When `HTTPProcessor.AbstractMetadata(ctx context.Context, manifest []byte, artifact *artifact.Artifact) error)` is invoked, it will send a HTTP POST request to the processor extender:

```
POST {remote-processor-endpoint}/abstractmetadata
{
    "registry": {
        // A base URL of the Docker Registry v2 API.
        "url": "registry:5000",
        // For example, `Basic: Base64(username:password)`.
        "authorization": "hsakjh..."
    },
    "manifest": "{\"config\":...}",
    "artifact": artifact.Artifact{}
}
```

The `manifest` and `artifact` will be sent to the extender to abstract the metadata. If the registry needs Auth, `registry` will be sent, just like Scanner.

When users deal with these built-in artifact types like OCI Image, CNAB or Helm Chart, the workflow **is not affected**, like Fig. 7. For example, the user uploads a Helm Chart to Harbor, we will use Helm Chart processor to abstract the metadata. Thus the design of `HTTPProcessor` is non-invasive to the current design.

<p align="center">
<img src="images/artifact-processor-extender/workflow.png" height="600">
<p align="center">Fig. 7 Workflow of Pushing an Artifact using the Build-in Processor</p>
</p>

#### Processor Extender

We have four RESTful APIs provided by the extender.

```
GET  {remote-processor-endpoint}/artifacttype
GET  {remote-processor-endpoint}/additiontypes
POST {remote-processor-endpoint}/abstractmetadata
POST {remote-processor-endpoint}/abstractaddition
```

The data structure used by the extender is shown here:

```go
// Registry represents Registry connection settings.
type Registry struct {
	// A base URL of the Docker Registry v2 API exposed by Harbor.
	URL string `json:"url"`
	// An optional value of the HTTP Authorization header sent with each request to the Docker Registry for getting or exchanging token.
	// For example, `Basic: Base64(username:password)`.
	Authorization string `json:"authorization"`
}


// GET  {remote-processor-endpoint}/artifacttype respose
type GetArtifactTypeResponse struct {
	ArtifactType string
	Error        string
}

// GET  {remote-processor-endpoint}/additiontypes response
type ListAdditionTypesResponse struct {
	AdditionTypes []string
	Error         string
}

// POST {remote-processor-endpoint}/abstractmetadata request
type AbstractMetadataRequest struct {
	Registry *Registry
	manifest []byte
	Artifact *artifact.Artifact
}

// POST {remote-processor-endpoint}/abstractmetadata response
type AbstractMetadataResponse struct {
	Artifact *artifact.Artifact
	Error    string
}

// POST {remote-processor-endpoint}/abstractaddition request
type AbstractAdditionRequest struct {
	Registry     *Registry
	Artifact     *artifact.Artifact
	AdditionType string
}

// POST {remote-processor-endpoint}/abstractaddition respose
type AbstractAdditionResponse struct {
	Addition *Addition
	Error    string
}

```

A processor extender needs to build a HTTP service which provides these four APIs.

```go
func GetArtifactType() *ListAdditionTypesResponse {
	return &ListAdditionTypesResponse{}
}

func ListAdditionTypes() *ListAdditionTypesResponse {
	return &ListAdditionTypesResponse{}
}

func AbstractMetadata(req *AbstractMetadataRequest) *AbstractMetadataResponse {
	return &AbstractMetadataResponse{}
}

func AbstractAddition(req *AbstractAdditionRequest) *AbstractAdditionResponse {
	return &AbstractAdditionResponse{}
}
```

### Configuration file `processors.yaml`

```app.conf``` is used to configure Harbor Core. The configuration info is about core service configuration used for beego. So we can use another configuration file for processor configuration info. 

Considering defining a specific type of artifact is not frequent, there is no need for Harbor to expose a API for remote processor to register. It is simple to use a YAML file named ```processor.yaml```, which will be mounted into core service to register ```processor``` info when core service start.

```yaml
Processors:
- ProcessorUrl: "http://{processor-service-IP}:port"
  ArtifactMediaType: "{media-type-string}"
```

The registration will look like the pseudo code here:

```go
Registry = map[string]Processor{}
Registry[Processors[].ArtifactMediaType] = HTTPProcessor{ProcessorURL: Processors[].ProcessorURL}
```

### Artifact Data Access

Refer to [Artifact Data Access](https://github.com/goharbor/community/blob/master/proposals/pluggable-image-vulnerability-scanning_proposal.md#artifact-data-access), there are same problems for remote processor extracting artifact data possibly.

It is possible that when remote processor extracts artifact data, the remote processor still need to retrieve data from Harbor using the Docker Registry v2 API exposed by Harbor. So remote processor need credentials provided by Harbor when API provided by remote processor called by Harbor.

#### Policy Check Interceptor

Harbor can block image distribution based on severity of vulnerabilities found during scan. Since processor extender is deployed outside the system boundary of harbor, the client used by processor extender is supposed to access the registry through external IP configured by ingress or load balancer. Because of the policy check interceptor, there is a problem of accessing registry via external endpoint which might block pulling.

#### OAuth 2 Bearer Tokens

Harbor provides a JWT Bearer token to Clair in the request. The token is generated in OAuth Client Credentials (with client_id and client_secret) flow and then passed directly to Clair in a HTTP POST request to scan a Clair Layer.

```
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiIsImtpZCI6IkJWM0Q6MkFWWjpVQjVaOktJQVA6SU5QTDo1RU42Ok40SjQ6Nk1XTzpEUktFOkJWUUs6M0ZKTDpQT1RMIn0.eyJpc3MiOiJhdXRoLmRvY2tlci5jb20iLCJzdWIiOiJCQ0NZOk9VNlo6UUVKNTpXTjJDOjJBVkM6WTdZRDpBM0xZOjQ1VVc6NE9HRDpLQUxMOkNOSjU6NUlVTCIsImF1ZCI6InJlZ2lzdHJ5LmRvY2tlci5jb20iLCJleHAiOjE0MTUzODczMTUsIm5iZiI6MTQxNTM4NzAxNSwiaWF0IjoxNDE1Mzg3MDE1LCJqdGkiOiJ0WUpDTzFjNmNueXk3a0FuMGM3cktQZ2JWMUgxYkZ3cyIsInNjb3BlIjoiamxoYXduOnJlcG9zaXRvcnk6c2FtYWxiYS9teS1hcHA6cHVzaCxwdWxsIGpsaGF3bjpuYW1lc3BhY2U6c2FtYWxiYTpwdWxsIn0.Y3zZSwaZPqy4y9oRBVRImZyv3m_S9XDHF1tWwN7mL52C_IiA73SJkWVNsvNqpJIn5h7A2F8biv_S2ppQ1lgkbw
```

Clair, on the other hand, is using the token to pull image layers from Harbor registry. It works because Clair is using a standard ```http``` library and sets a ```Authorization``` header programmatically.

In order to enable Scanner Adapters to bypass Policy Check Interceptor, Harbor's authentication service will generate a dedicated JWT access token and hand it over to the underlying Scanner thru Scanner Adapter in a ScanRequest.

It is reasonable to use the same way for processor extender using bearer tokens to access to the image data from harbor registry.

#### Robot Accounts

Refer to scan job using credentials generated by robot account mechanism, we can use the same way to use the robot account mechanism to generate credentials that work with these common OCI/Docker tooling libraries to provide credentialed access to the image data. The lifecycle of the robot account credentials can be bound to the HTTP request. For every HTTP request call remote processor API, a robot account expired at certain time will be created.Additionally, a modification is needed to ensure that the generated credentials have access to bypass the configured policy checks on the image that normal users are subject to if those checks are configured.

### Development Process  

There are totally three things we need to do to complete the proposal:

- Implement ```HTTPProcessor```
- Register ```HTTPProcessor``` to Harbor Core using `processors.yaml`
- Implement the mechanism to support Auth.

Thus we propose to have three iterations. Each of them is self-contained and supposed to be merged into Harbor Core.

#### First Iteration: HTTPProcessor and Extender without Auth

At this stage, user defined processor will not register to harbor. So if users want to use processor extender, they still need to hard-code some logic to harbor code to register the type with the corresponding processor manually.

Also, ```HTTPProcessor``` will make HTTP request to the extender without providing authentication and Harbor external endpoint. So users need to do some work to generate authentication using other user account. Harbor external endpoint should be configured any way. And policy check interceptor can not be bypassed.

#### Second Iteration: Registration

At the second stage, registration logic will be added. Users don't need to modify harbor code any more. A remote processor configuration file is required to register specific processor to harbor. When harbor core starts, it will read the configuration file and register the processor to harbor.

#### Third Iteration: Auth in the Processor Extender

At the final stage, using robot account mechanism to generate credentials will be finished. Harbor external endpoint and authentication will be passed directly in HTTP POST request body. Users don't need to worry about the authentication problem. But still need to find a way to use authentication properly.
