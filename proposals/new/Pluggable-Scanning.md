# Proposal: `Pluggable Container Scanning`

Author: `Zach Hill (zhill)`

Discussion: [Issue 6234](https://github.com/goharbor/harbor/issues/6234)

## Abstract

Add a vendor agnostic image scanner interface between Harbor and external image scanning systems to facilitate integration of 
other scanners with Harbor and add scanner-specific image checks to optionally gate access to container images.

The plugin interface will support the following high-level capabilities:

1. Scanning images and returning a vulnerability listing mapping vulnerabilities to artifacts in the image
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

Introduce a plugin interface for any scanner to be integrated with Harbor. The drivers may be delivered in-tree or out-of-tree
using go modules, subject to design discussion with Harbor maintainers on larger plugin architecture requirements. Based on the
current system implementation and design, it is assumed that an in-tree implementation will be preferred by maintainers, but this is
subject to further discussion and follow-up.


The plugin interface will provide:

1. Image lifecycle operations:
    1. Image added to Harbor: execute a scan on the digest
    2. Image deleted from Harbor: delete the image in the scanner, configurable to be executed or not, depending on user requirements
    3. Background scan update: execute a scan on an image previously scanned
        1. For some scanners this will be the same as 2.1, but for others it may differ in what/if data is retrieved.
2. Credentialed access to the image content
3. Credentialed access to the scanner itself

#### Plugin Interface Operations

* ScanImage
  * Description: The base scan operation to process an image's content and return a list of found vulnerabilities, some scan metadata, and a check result (scanner specific)
  * Params: image digest, registry URL, pull credential, tags applied to the digest
  * Output:
    scan_status: boolean
    vulnerabilities: array of vulnerable artifacts in the image     
    scan_metadata: json object, scanner specific
    image_check: boolean (true if image is 'ok' according to scanner implementation and/or policy)
    
* ImageDeleted
  * Description: Explicit call to support scanner GC of any scan related data that should be flushed.
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
  * Description: Handler for webhooks invoked by the scanner itself. The driver, with knowlege of the payload, can decide if a new scan task is needed and indicate it in the return value 
  * Params: notification content
  * Output: array of digests to re-scan
  
* CheckImage
  * Description: A scanner-specific synchronous check of an image. Provided for optional use in interceptors or other cases where Harbor may want an up-to-date check result from the scanner to make an admission decision.
  * Params: image digest, image reference (e.g. pullstring if a tag-based manifest fetch)
  * Output: check result (boolean)

#### Configuration

* Driver selection - configured in the Harbor configuration itself
* Driver configuration, as a json document, specific to the driver impl. Config key is the driver id/name.  
  * Scanner credentials - included in the driver-specific configuration if necessary. Should be kept in a secret store in encrypted form.
  * Details tbd with feedback from harbor maintainers on overall configuration handling

#### Error Handling

Driver implementations of these operations should return errors in standard go mechanisms (not outlined here since the are common to all function calls). However, the objects returned
as errors, should be well defined by the driver and implement a common interface:

DriverError:
* Message - string - description of the error, intended to be short for single line presentation
* Detail - string - Additional detail for human consumption that may be longer than a single line and may include remediation information.
* ErrorCode - int - code to uniquely identify the class of error
* CanRetry - bool - an indicator to the caller that the error may be resolved with a retry


#### DAO Updates needed:
* Extend the existing result store to include a json field for:
  * Augmentation of existing vulnerability listing to be more generic
  * Scan metadata from scanner (opaque json object)
  * Image check result  



## Non-Goals

* Changes to the UI presentation of image vulnerability data (such changes may be a goal of a later work or independent work parallel to this)
* More than one scanner configured for use concurrently in Harbor


## Rationale

The proposed approach is intended to provide a generic-enough interface that scanners with different data management and lifecycle designs can still be integrated into the
Harbor and implement only the aspects necessary for that system in the driver. The basic vulnerability listing format is kept normalized so that clients of the Harbor API have
a well-defined format for consuming scan results, but support for additional scanner-specific metadata will allow scanner-aware clients to gain additional insight into the
scan results/details as available for a specific scanner.

The addition of an image check function allows scanners with more functionality than just returning simple vulnerability lists to make recommendations
to Harbor on suitability of an image. For end-users, the raw vulnerability list is rarely sufficient for determining if an image is acceptable or not, but
the mechanisms and inputs to the check decision will be scanner specific and must be handled by the driver implementations themselves.  Additional future work in the
policyChecker or new interceptors can leverage the check recommendations from the scanners or utilize the new CheckImage operation to have control over the staleness of
the check result. The interceptor implementation(s) can decide to use either the last known recommendation or request a new evaluation during request processing.


## Compatibility

TBD

## Implementation

TBD

## Open issues (if applicable)

General approach to plugins in Harbor. Expectation is that they will all be in-tree and compiled into the build, but selected at runtime based on configuration, but this is open for discussion as it will
impact the libraries and licenses of software that the drivers themselves as well as software delivery implications.
