# Proposal: `Pluggable Container Scanning`

Author: `Zach Hill (zhill)`

Discussion: [Issue 6234](https://github.com/goharbor/harbor/issues/6234)

## Abstract

Add a generic image scanner abstraction layer between Harbor and external image scanners. Scanner integrations are achieved
by implementing an adapter which implements the scanner adapter interface and which is loaded, configured, and invoked by the
a generic scanner job.

The adapter interface will support the following high-level capabilities:

1. Scanning images achieved by the scanner fetching image data and returning a vulnerability listing mapping vulnerabilities to artifacts in the image
2. Providing a image check pass/fail recommendation based on the specific capabilities/polices of the scanner (new)
3. Cleanup of data in the scanner when an image is deleted from Harbor (for image lifecycle completeness) (new)

## Background

Harbor contains a tightly-coupled interface to Clair for security scans of image content uploaded to the registry. 
Some users have other container scanning solutions already, or would like to leverage a solution with other desirable 
features without duplicating image scans. It will add convenience and value to Harbor deployments to allow such scanners 
to provide results for Harbor in place of the default integration.

The current implementation for scanner support is included in the following components:

1. Job service's ClairJob job type for executing scans
2. DAO - Internal data model for storing and retrieving scan results
3. API for both viewing and triggering scans
5. API for receiving notifications from the scanner to trigger new scans
4. Initialization and configuration (including ClairDB init in the DAO layer)
5. policyChecker implementation consumes the vulnerability overview produced by the scanner to make access decisions

Scans are initiated by the job service due to:
* New image pushed
* Scheduled scan interval
* User API call
* Notification (POST) from Clair to _/service/notifications/clair_ indicating an update available

The scan job (ClairJob) interacts with the scanner (Clair) and process the result for hand-off to the DAO layer to be persisted.
The persisted result (ImgScanOverview) is made available via the Harbor API as well as consumed by the policyChecker interceptor if configured.

The policyChecker interceptor consumes the scan result for comparison with the configured vulnerability-severity-based policy 
and determines if specific HTTP requests are to be allowed.

The Harbor UI also consumes the scan results and visualizes them to the user as well as providing UI components to configure and execute scans.

## Proposal

Introduce a layer of abstraction between the scan invocation logic and the scanner-specific logic: an adapter interface for any scanner to be integrated with Harbor. 
The existing Clair implementation (ClairJob, etc) will be moved into a Clair adapter invoked by the common scan. 

A ScanJob layer will added that will load, configure, and invoke the appropriate adapter defined in the Harbor configuration.

The new ImageScannerAdapter interface provides:

1. Execute a scan on the image data, retrievable by the digest of the image manifest document (aka the "image digest") (same as current impl)
1. Notify the scanner that the image is removed from Harbor. Depending on scanner and configuration this may be a no-op. (new)
1. Execute a rescan of an image previously scanned (Note: For some scanners this will be the same as #1, but for others it may differ in what/if data is retrieved.) (new, but largely identical to current impl)
1. Execute a "check" operation for an image against the scanner, if implemented, to provide an evaluation and pass/fail (new)

### Accessing Image Data

The adapter interface passes a reference to the image data to the adapters: the image digest (digest of the image manifest object) and the registry url 
necessary to retrieve the data via registry API mechanisms. An example reference would be: internalharborregistry:5000/project/image@sha256:abc123.
From such an reference the scanners may use HTTP GET to download the image manifest that describes the additional data layers needed for analysis. Optimization of
the data retrieval and analysis is left to the individual adapters and scanner implementations as an implementation detail.

The current implementation of the scanner integration assumes that the scanner has access to the internal registry API without first passing thru the proxy component
that implements access control for external Harbor users. This allows the scanners to fetch image data even when external users cannot retrieve image data due to 
access restriction caused by the scan status and/or vulnerability status of the image as configured by the API policyChecker component. As such, either a given
scanner to be integrated with Harbor must have access to internal network interfaces not exposed to external users, or else must implement a proxy that can run
within that network that is exposed externally (presumably with authc/authn) to ensure access to the data regardless of the access status for Harbor users.

As an example, the current implementation runs Clair in the same docker-compose network so it can access ports that are not exposed to the host itself. Such a model
will work for some scanners, but will require additional implementation work for adapters for scanners that are external to the registry deployment (e.g. Saas or externally hosted to the registry).

#### Adapter Interface Operations

* ScanImage
  * Description: The base scan operation to process an image's content and return a list of found vulnerabilities, some scan metadata, and a check result (scanner specific)
  * Params: image digest, registry URL, pull credential, tags applied to the digest
  * Output:
    scan_status: boolean
    vulnerabilities: array of vulnerable artifacts in the image     
    scan_metadata: json object, scanner specific
    image_check: boolean (true if image is 'ok' according to scanner implementation and/or policy)
    
* NotifyImageDeleted
  * Description: Explicit call to notify scanner that a specific image manifest has been deleted from Harbor and the scanner may flush any state if necessary.
  * Params: image digest, tags, registry URL
  * Output: status code (ok or error)
  
* RescanImage (since some scanners may need to treat this differently)
  * Description: functionally the same as the Scan Image operation, but may occur at different lifecycle events for an image and provided here to support scanners which need to differentiate between a new image scan and a re-scan.
  * Params: image digest, registry URL, pull credential, tags applied to the digest
  * Output:
      scan_status: boolean
      vulnerabilities: array of vulnerable artifacts in the image     
      scan_metadata: json object, scanner specific
      image_check: boolean (true if image is 'ok' according to scanner implementation and/or policy)

* HandleScannerNotification
  * Description: Handler for webhooks invoked by the scanner itself. The adapter, with knowledge of the payload, can decide if a new scan task is needed and indicate it in the return value 
  * Params: notification content
  * Output: array of digests to re-scan
  
* CheckImage
  * Description: A scanner-specific synchronous check of an image. Provided for optional use in interceptors or other cases where Harbor may want an up-to-date check result from the scanner to make an admission decision.
  * Params: image digest, image reference (e.g. pullstring if a tag-based manifest fetch)
  * Output: check result (boolean)

#### Configuration

* adapter selection - configured in the Harbor configuration itself
* adapter configuration, as a json document, specific to the adapter impl. Config key is the adapter id/name.  
  * Scanner credentials - included in the adapter-specific configuration if necessary. Should be kept in a secret store in encrypted form.
  * Details tbd with feedback from harbor maintainers on overall configuration handling

#### Error Handling

Adapter implementations of these operations should return errors in standard go mechanisms (not outlined here since the are common to all function calls). However, the objects returned
as errors, should be well defined by the adapter and implement a common interface:

AdapterError an error normalization abstraction between the adapter framework and adapter implementations:
* Message - string - description of the error, intended to be short for single line presentation
* Detail - string - Additional detail for human consumption that may be longer than a single line and may include remediation information.
* ErrorCode - int - code to uniquely identify the class of error
* CanRetry - bool - an indicator to the caller that the error may be resolved with a retry
a
#### DAO Updates needed:

Overall, the objective is to require as little DAO change as possible to minimize upgrade and db maintenance impact.

* Extend the existing result store to include json fields for:
  * Augmentation of existing vulnerability listing to be more generic (primarily column/table naming, not schema).
  * Scan result metadata from scanner (opaque json object)
  * Image check result - a boolean and a json object returned by the scanner

## Non-Goals

* Changes to the UI presentation of image vulnerability data (such changes may be a goal of a later work or independent work parallel to this)
* More than one scanner configured for use concurrently in Harbor

## Rationale

The proposed approach is intended to provide a generic-enough interface that scanners with different data management and lifecycle designs can still be integrated into the
Harbor and implement only the aspects necessary for that system in the adapter. The basic vulnerability listing format is kept normalized so that clients of the Harbor API have
a well-defined format for consuming scan results, but support for additional scanner-specific metadata will allow scanner-aware clients to gain additional insight into the
scan results/details as available for a specific scanner.


This proposal includes 2 new capabilities not found in the current Clair-specific implementation:
1. Full data lifecycle management
    1. The current implementation assumes that the admin is manually managing the data lifecycle for scan state in the scanners. That is certainly always an option but
  quickly imposes some operational issues with resource provisioning of the scanner (db storage sizes, etc).
  1. By including a notification mechanism that an image is logically deleted, the scanner may, based on its configuration and how the user wants it deployed, be able
  to clean up its own scan state and maintain some parity with the image state of the Harbor deployment. This is purely a notification mechanism, not an actuation, and the scanner adapters
  are free to implement as makes sense, including a no-op.

1. Scanner-implemented image evaluation with a policy recommendation
    1. The addition of an image check function allows scanners with more functionality than just returning simple vulnerability lists to make recommendations
to Harbor on suitability of an image. For end-users, the raw vulnerability list is rarely sufficient for determining if an image is acceptable or not, but
the mechanisms and inputs to the check decision will be scanner specific and must be handled by the adapter implementations themselves.  Additional future work in the
policyChecker or new interceptors can leverage the check recommendations from the scanners or utilize the new CheckImage operation to have control over the staleness of
the check result. This check is not intended to replace other policy evaluations but to augment them.
    1. This functionality could be abstracted into a separate Policy adapter layer in the future if Harbor intends to build a generic policy layer. However, this proposal attempts to avoid significant changes outside of the image scan flow.  

## Compatibility

TBD

## Implementation

Overall approach is to add an abstraction layer, then extend it

### Phase 1: Abstract existing Clair implementation into the adapter model

Add abstraction layer between existing ScanJob logic and the existing ClairJob interface.

Example interfaces:

``` 

// The interface that each scanner implementation would implement
// The ScannerAdapter objects should have default constructors to facilitate lazy initialization

type ScannerAdapter interface {
  func configure(conf map[string]interface{}) err
  func scanImage(imgReference ImageReference, credentials AccessCredentials) *VulnerabilityReport, *ImageCheckReport, err
  func rescanImage(imgReference ImageReference, credentials AccessCredentials) *VulnerabilityReport, *ImageCheckReport, err
  func notifyImageDeletion(imgReference ImageReference) err
  func checkImage(imgReference ImageReference) PolicyResult, err  
}

type ScanResult struct {
  vulnResult VulnerabilityReport
  checkResult ImageCheckReport
}

type ImageReference struct {
  registryUrl string
  digest string
  tag string
}

// Access credentials for the image content
type AccessCredentials struct {
  token string
  tokenUrl string
}

// For now, use the existing vuln format for ease of conversion into the db model 
type VulnerabilityReport ClairVulnerabilityEnvelope

// Optionally implemented, 
type ImageCheckReport struct {
  imageDigest string
  imagePasses boolean //Pass/Fail flag
  checkTimestamp time.Time
  details map[string]interface{} // Opaque json object for scanner-specific results if implemented by the scanner  
}

```

### Phase 2: Add one or more non-Clair adapters
Likely the Anchore adapter and Aqua Microscanner adapters.


### Phase 3: Add new image data lifecycle capabilities

Specifically, the delete lifecycle call, invoked in the proxy handler on a successful response from the backing registry implementation.



## Open issues (if applicable)

General approach to adapters in Harbor. Expectation is that they will all be in-tree and compiled into the build, but selected at runtime based on configuration, but this is open for discussion as it will
impact the libraries and licenses of software that the adapters themselves as well as software delivery implications.
