# Proposal: `Artifact Processor Extender`

Author: `Ce Gao @gaocegege, Jian Zhu @zhujian7, Yiyang Huang @hyy0322`

Discussion: [goharbor/harbor#12013](https://github.com/goharbor/harbor/issues/12013)

## Abstract

Add support to Harbor for using remote artifact processor to process user defined OCI Artifact.

## Background

There are four types of artifacts, which are image, helm v3, CNAB, OPA bundle, supported by Harbor. Each of them implements its processor to abstract metadata into artifact model defined by harbor. If users want to define a new kind of artifact, they need to implement the processor logic in goharbor/harbor core service, which greatly limits the scalability and extensibility of Harbor.

## Proposal

To achieve the goal of making harbor have the ability to process user defined aitifact whthout adding code in harhor core service which makes harbor extensible in extracting artifact data, the current build-in processor logic interface can be abstract to HTTP API.

New Component:
1. Remote Processor API - HTTP API defining interface between Harbor and remote processor.  
&ensp; i. Defined and maintained by Harbor  
&ensp; ii. Authentication specifics are out-of-scope, but should be supported using the HTTP ```Authorization``` header
2. Remote Processor - HTTP service that implements the Remote Processor API to extracte artifact data.  
&ensp; i.Deployed outside the system boundary of Harbor, not considered an internal component  
&ensp; ii.Implementations are out-of-tree of Harbor  
&ensp; iii.Has independent state management, configuration, and deployment lifecycle from Harbor

```Processor``` interface is defined in Harbor, which is used to process the specified artifact.

```
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

```Registry``` is defined to store ```Processor```.

```
var (
	// Registry for registered artifact processors
	Registry = map[string]Processor{}
)
```

#### Remote Processor API
For a remote processor, the functions defined in ```Processor``` interface can be abstract to HTTP service API. By using these API, harbor core can call remote HTTP processor.

```
GET  {remote-processor-endpoint}/artifacttype
GET  {remote-processor-endpoint}/additiontypes
POST {remote-processor-endpoint}/abstractmetadata
POST {remote-processor-endpoint}/abstractaddition
```

```HTTPProcessor``` is a ```Processor``` implement which make harbor have extensibility to let users use remote HTTP service process their user defined artifacts by API defined above.

```
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

#### Register
Harbor now using ```app.conf``` to set core config. The configuration info is about core service configuration used for beego. So we can use another configration file just for processor configration info. 
Considering defining a specific type of artifact is not frequent behaviour, there is no need for harbor to expose a API for remote processor to register. So it is a simple way to use a yaml file named ```processor.yaml``` mount in core service to register ```processor``` info when core service start.

```
Processors:
- ProcessorUrl: "http://{processor-service-IP}:port"
  ArtifactMediaType: "{media-type-string}"
```

#### Artifact Data Access
Refer to [Artifact Data Access](https://github.com/goharbor/community/blob/master/proposals/pluggable-image-vulnerability-scanning_proposal.md#artifact-data-access), there are same problems for remote processor extracting artifact data possibly.

It is possible that when remote processor extracting artifact data, the remote processor still need to retrive data from harbor using the Docker Registry v2 API exposed by Harbor. So remote processor need credentials provided by harbor when API provided by remote processor called by harbor.

##### Policy Check Interceptor
Harbor can block image distribution based on severity of vulnerabilities found during scan. Since repote processor is deployed outside the system boundary of harbor, the docker clients used by remote processor are supposed to access the registry through external IP configured by ingress or load balancer. Because of the policy check interceptor, there is a problem of accessing registry via external endpoint which might block pulling.

##### OAuth 2 Bearer Tokens
Harbor provides a JWT Bearer token to Clair on scan request. The token is generated in OAuth Client Credentials (with client_id and client_secret) flow and then passed directly to Clair in a HTTP POST request to scan a Clair Layer.

```
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiIsImtpZCI6IkJWM0Q6MkFWWjpVQjVaOktJQVA6SU5QTDo1RU42Ok40SjQ6Nk1XTzpEUktFOkJWUUs6M0ZKTDpQT1RMIn0.eyJpc3MiOiJhdXRoLmRvY2tlci5jb20iLCJzdWIiOiJCQ0NZOk9VNlo6UUVKNTpXTjJDOjJBVkM6WTdZRDpBM0xZOjQ1VVc6NE9HRDpLQUxMOkNOSjU6NUlVTCIsImF1ZCI6InJlZ2lzdHJ5LmRvY2tlci5jb20iLCJleHAiOjE0MTUzODczMTUsIm5iZiI6MTQxNTM4NzAxNSwiaWF0IjoxNDE1Mzg3MDE1LCJqdGkiOiJ0WUpDTzFjNmNueXk3a0FuMGM3cktQZ2JWMUgxYkZ3cyIsInNjb3BlIjoiamxoYXduOnJlcG9zaXRvcnk6c2FtYWxiYS9teS1hcHA6cHVzaCxwdWxsIGpsaGF3bjpuYW1lc3BhY2U6c2FtYWxiYTpwdWxsIn0.Y3zZSwaZPqy4y9oRBVRImZyv3m_S9XDHF1tWwN7mL52C_IiA73SJkWVNsvNqpJIn5h7A2F8biv_S2ppQ1lgkbw
```

Clair, on the other hand, is using the token to pull image layers from Harbor registry. It works because Clair is using a standard ```http``` library and sets a ```Authorization``` header programmatically.

In order to enable Scanner Adapters to bypass Policy Check Interceptor, Harbor's authentication service will generate a dedicated JWT access token and hand it over to the underlying Scanner thru Scanner Adapter in a ScanRequest.

It is reasonable to use the same way for remote processor using bearer tokens to access to the image data from harbor registry.

##### Robot Accounts
Refer to scan job using credentials generated by robot account mechanism, we can use the same way to use the robot account mechanism to generate credentials that work with these common OCI/Docker tooling libraries to provide credentialed access to the image data. The lifecycle of the robot account credentials can be bound to the HTTP request. For every HTTP request call remote processor API, a robot account expired at certain time will be created.Additionally, a modification is needed to ensure that the generated credentials have access to bypass the configured policy checks on the image that normal users are subject to if those checks are configured.


#### Remote Processor API define

```
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
#### Remote Processor
A user defined processor need to build a HTTP service which implement HTTP processor API
```
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

## Develop Plan  

There are totally three things we need to do to complete the proposal
- implement ```HTTPProcessor```
- register ```HTTPProcessor``` to harbor core
- authentication problems

1. At the first stage, we will implement the ```HTTPProcessor```.
At this stage, user defined processor will not register to harbor. So if users want to use remote porcessor, they still need to add registeration logic to harbor code and repcompile harbor core. Also, ```HTTPProcessor``` will make HTTP request to remote processor without privide authentication and Harbor external endpoint. So users need to do some work to generate authentication using other user account. Harbor external endpoint should be configured any way. And policy check interceptor can not be bypassed.
2. At the second stage, registration logic will be added. Users don't need to modify harbor code any more. A remote processor configration file is required to register specific processor to harbor. When harbor core start, it will read the configuration file and register the processor to harbor.
3. At the final stage, using robot account mechanism to generate credentials will be finished. Harbor external endpoint and authentication will be passed directy in HTTP POST request body. Users don't need to consider about the authentication problem. But still need to find a way to use authentication properly.

## Non-Goals

[Anything explicitly not covered by the proposed change.]

## Rationale

[A discussion of alternate approaches and the trade offs, advantages, and disadvantages of the specified approach.]

## Compatibility

[A discussion of any compatibility issues that need to be considered]

## Implementation

[A description of the steps in the implementation, who will do them, and when.]

## Open issues (if applicable)

[A discussion of issues relating to this proposal for which the author does not know the solution. This section may be omitted if there are none.]
