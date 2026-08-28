
# Proposal: Unified API for Pluggable Image Scanners

Authors: Prahalad Deshpande @prahaladd
Proposed Reviewers: Steven Zou @szou, Daniel Pacak @danielpacak, Zach Hill @zhill


- [Proposal: Unified API for Pluggable Image Scanners](#proposal-unified-api-for-pluggable-image-scanners)
  - [Discussions](#discussions)
  - [Abstract](#abstract)
  - [Use Cases](#use-cases)
  - [Unified API Requirements](#unified-api-requirements)
  - [Unified API Design](#unified-api-design)
    - [Supporting multiple scan types](#supporting-multiple-scan-types)
    - [Scan capability advertisement by scanner implementations](#scan-capability-advertisement-by-scanner-implementations)
    - [Single endpoint to trigger scans](#single-endpoint-to-trigger-scans)
    - [Scan API Endpoint Multiplexing](#scan-api-endpoint-multiplexing)
    - [Scan API response handling](#scan-api-response-handling)
    - [Error Handling](#error-handling)
  - [Advantages of proposed design](#advantages-of-proposed-design)
  - [References](#references)

## Discussions

[Initial Meeting of the Harbor Scanner Workgroup on 19th March 2021](https://drive.google.com/file/d/1TXjsASDPEBL30yFAk0Wnmg5sB3Ka4yw2/view?usp=sharing)
## Abstract

Maintaining the security and compliance of container images stored within the Harbor registry entails more than just software package and OS vulnerability scanning results such as enumerating the Bill of Materials present in an image or validating the contents of the container file system. 
Such a functionality would be exposed by one or more scanners that are specialized to perform the respective type of scan and return the results.
However, with multiple types of scan reports being generated the number of APIs that would need to be implemented by the third-party scanners and their corresponding registration and management within Harbor would soon become an error prone and tedious process.
This proposal details a specification that provides a unified API surface for different kinds of scanners that want to integrate with Harbor while also reducing the registration and management overhead within Harbor

## Use Cases

Ensuring security and compliance of the container images stored within a Harbor registry may involve more than just OS and software package vulnerability management. Below is a (non-exhaustive) list of use cases that also lie in the area of security and compliance management

 - Maintaining a detailed Bill of Materials (BoM) of all the software packages being used.
 - Maintaining a list of all the licenses associated with the software packages being used.
 - Running pre-checks on the contents and permissions of files and directories on a container image before rolling out the image to production.
 - Scanning Docker images for sensitive information (such as passwords or secret keys leaked through environment variables)
  
  The above use cases can be addressed either by a single sophisticated scanner that can provide information required above (and additional data) or by a collection of scanners each specialized for a specific type of scan.

  Irrespective of the number of scanners involved in the scanning process, Harbor must provide a mechanism for the scanners to register themselves and advertise their scanning capabilities, submit scan jobs to these scanners and then collate the resulting scan data (and errors) to provide a unified output that can be presented to the UI or the caller.

  ## Unified API Requirements

  * Expose a small canonical set of public REST endpoints ensuring standard behavior by all implementations and simplified management.
  * De-couple Harbor core and pluggable scanner API evolution from the evolution of the actual scanner implementation.
    * Responses from the API should leverage existing  scanner implementations.
    * The data format returned  by the scanners should leverage or be backward compatible with the existing data format.
  * Provide mechanisms for API clients to specify parameters that provide fine grain control over the scanning process
  * Extensible in supporting new types of scanning functionalities over periods of time
  * Well defined error handling mechanisms.
  
## Unified API Design

The approach for designing a unified API surface is detailed below. 

### Supporting multiple scan types

There would be one MIME type for the result data of each scan type. A few MIME types are proposed below:

| Mime Type | Type | Version | Status | 
| --- | --- | --- | --- |
| application/vnd.security.vulnerability.report; version=1.1 | OS/Package vulnerability data | 1.1 | Released in Harbor 2.3.0 |
| application/vnd.security.bom.report; version=1.0 | Bill of Materials (BoM) | 1.0 | Proposed |
| application/vnd.security.filesystem.report; version=1.0 | File system content validation | 1.0 | Proposed |


### Scan capability advertisement by scanner implementations

Every scanner advertises the supported scanning capabilities using the existing mechanism of publishing scanner metadata.
The existing `v1.1` endpoint `/metadata` would be used to advertise this information.

### Single endpoint to trigger scans
There will be a single `/scan` endpoint that would be used to trigger scans for multiple types of reports. The `/scan` endpoint will be enhanced to allow clients to specify the types of scan reports to be generated and also a mechanism to control the scanning process. An example request is shown below
```shell
curl -XPOST http://scanner-adapter:8080/api/v2/scan -H 'Content-Type: application/vnd.scanner.adapter.scan.request+json; version=2.0' -d {
         "registry": {
           "url": "harbor-harbor-registry:5000",
           "authorization": "Bearer: JWTTOKENGOESHERE"
         },
         "artifact": {
           "repository": "library/mongo",
           "digest": "sha256:917f5b7f4bef1b35ee90f03033f33a81002511c1e0767fd44276d4bd9cd2fa8e"
         }
         "scanTypes": {
         	"application/vnd.security.vulnerability.report; version=1.1" : {},
         	"application/vnd.security.bom.report; version=1.0" : {"allowGNU" : "false", "format": "spdx"}
         } 
       }
```
In the above request the `scanTypes` key refers to an object that contains key-value pairs with the MIME type as a key.
 - Each type of scan is identified by it's MIME type - in the above request we are requesting for vulnerability scan and BoM scan from a scanner.
 - Each type of scan can be further controlled or additional params passes in using the key value pairs. For e.g. in the above sample request, the BoM scanner can be controlled using the keys allowGNU and the format of representing the BoM information (in this case spdx).
 - Scanner can be requested to perform only a specific type of scan by including only the specific corresponding MIME type in the request along with any control parameters.

The response from the scanner are packaged in an uber-container structure again keyed by the MIME type. The object against each MIME type would contain the following
   - Internal scan tracking identifier for the composite scan.
   - The scan id and status for each MIME type. The status would be either one of started, completed, running, aborted, failed

  
 A sample response for the above request is provided

```shell
Content-Type: application/vnd.scan.report; version=2.0;
Status: 200 OK
{
    "scanId": "1",
    "application/vnd.security.vulnerability.report; version=1.1" : {
        "scanId" : "1",
        "scanProgress" : "started",
    },
    "application/vnd.security.bom.report; version=1.0" : {
        "scanId": "2",
        "scanProgress": "started"
    }
}
```
### Scan API Endpoint Multiplexing

To satisfy the API request and response patterns mentioned above, the scanner API endpoint middleware for scan would perform the following actions:

* Extract the MIME type from the request
* Validate the MIME types present in the request.
  * Check the MIME type is in the list of known MIME types
  * Check that there is a scanner available for specified MIME type
* For each MIME type in the scan request payload, in a non-blocking manner:
  * Send the scan request to the registered scanners for the MIME type
  * Collect the scan result (or error) for the MIME type.
* Create an uber-container data structure which will contain the scan results keyed by the corresponding MIME types and send the result to client.

### Scan API response handling
The scanning process would be executing multiple types of scans asynchronously and hence a sophisticated response handling mechanism would required.

For a given job, the multiplexer component would maintain a mapping between the composite scan Id and the granular status of each of the component scans  as and when received from the scanner. 

A client can request for the either of the composite scan status or the status of the individual scans. This mechanism allows to offload the responsbility of the timing of the scan result to the client implementation. It also greatly simplifies error handling since clients can opt to handle errors at the composite scan level or the granular scan level. 

If a client submits a composite scan job containing multiple scan types, then it can choose between polling for the completion of the complete composite job and then retrieving the results or polling separately for the individual scans and retrieving results as and when they are ready.


### Error Handling

The above API invocation pattern requires an enhanced error handling mechanism since multiple scan jobs of different types would be executing and some of them could potentially error out. There are three important aspects to be considered in error handling
  -  how does the scanner report an error to Harbor core?
  -  how is the error reported to the caller?
  -  what is the impact of an error on the overall scan job?

A clean, simple and efficient mechanism to handle errors would be as follows
 
 - Scanners use the existing mechanism to report their scan errors to Harbor
 - If a scanner reports an error when scanning for a particular MIME type, then the uber-container response to the client will contain the serialized error against the MIME type.
 - Each scan is mutually exclusive of the other and the failure of one does not affect the other. The response of a composite scan job submission would contain the error details for each MIME type and it is the responsibility of the client to handle the error appropriately.


## Advantages of proposed design
1. Prevents combinatorial explosion of REST endpoints for each type of scan (and/combinations) to be supported.
2. Adopts a "what you send is what you receive" model.
3. Allows clients to control what data they want from the scanner adapter - when the same scanner supports multiple types of scan functionalities
4. Provides a mechanism to fine tune scanning operation.
5. Incremental changes on the existing API model exposed by Harbor.
6. Provides complete control to clients with respect to retrieval of results, handling of job status and errors.
7. Decouples Harbor pluggable scanner API evolution from the actual pluggable scanner capability by providing a "wrapper" over already existing MIME types. For e.g, we do not need re-define a new MIME type for vulnerability scan. Also consider a use case where-in the scanner adapter supports only the 1.0 version of the vulnerability report and is also a BoM scanner. In such cases all that the client needs to specify is the appropriate MIME type. Hence scanner adapters can adopt API specs at their pace and independent of Harbor releases.

## References

 -  [Pluggable Scanner API Specification v1.1](https://github.com/goharbor/pluggable-scanner-spec)
  







