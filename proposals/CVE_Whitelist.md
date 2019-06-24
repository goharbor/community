# Proposal: `Support white list of vulnerabilities in project policy`

Author: `reasonerjt`

## Abstract

It proposes to add settings in system/project level to define a white list, so that the vulnerabilities in this list will
be ignored when Harbor is calculating the vulnerability level of an image.

## Background

Currently Harbor supports "Deployment Security" policy, which prevents images with vulnerabilities higher than threshold from 
being pulled.  There will be problem if a vulnerability is found and there's no fix for it, in such case, user will have to 
wait for the fix or disable the policy skip all vulnerabilities.  For some users, they are willing to take the risk after reviewing
the vulnerabilities and explicitly ignore some of them during the policy checking.

## Proposal

We propose to introduce the "whitelist" of vulnerabilities (a.k.a CVE whitelist) to project policy to solve this problem.  
The system or project admin can define a list of CVE, when checking the scan result to compare the the threshold setting in 
"Deployment Security" policy, the vulnerabilities in the white list will be ignored, such that user can pull an image with 
certain vulnerabilities higher than the threshold without having to update or disable the policy.

Each whitelist can optionally have a expiration time.  Once it's expired, the CVEs in that list will not be filtered when 
calculating the overall vulnerability level.

**NOTE:**
Each project can only have one CVE whitelist.
The support for expiration may be a P1 for v1.9 release depending on the date and resource.
There's not a limit of the number of items the a CVE whitelist but we need to think about it when implementing the UI.

In detail, it will involve the following use cases:

* #### System admin defines system level whitelist

There will be only one system level vulnerable white list, which by default is empty.
The system admin should be able to add or remove CVEs to the whitelist via UI or API.

* #### Project admin reuse the system level whitelist or define the custom whitelist for the project

The "Vulnerability whitelist" will be added to "Deployment Security" as a setting.  A project admin can choose to reuse the 
system level whitelist or set the custom whitelist that is only effective for the project.

When it is set to reuse the system level whitelist, it's a "reference" relationship so that the latest change made by system 
admin can be reflected at the project level.

* #### Pulling image from project with vulnerability whitelist

Upon receiving a request to pull an image, instead of querying the "scan overview" in Harbor's DB, Harbor will call Clair's 
API to list all the vulnerability of this image and apply to whitelist, if it's not expired, to filter out some of them, 
and consolidate the result to get the overall vulnerability level.

**NOTE:**
Making the switch from querying local DB to calling Clair's API may have some impact on performance.  Storing the full CVE 
list of every scanned image is not very effective.  We'll have to measure the performance during the refactor and lower the
impact.

## Non-Goals

When user views the overview or detail list of vulnerabilities of an image, the vulnerabilities in whitelist will still 
be taken into account.
This proposal does not cover how to provide a general framework for project level policy management.

## Compatibility

As the CVE is a standard by NIST, as long as the vulnerability list returned by scanner contains the CVE ID in each of the 
entries, using such whitelist to define what vulnerabilities to ignore works with other scanners.

## Implementation

### API for system vulnerability whitelist:

For managing and viewing the system level whitelist, these APIs should be added:

#### Get system vulnerability whitelist:

All Harbor users should have permission to Call this API to view the list of system level vulnerability whitelist:

```HTTP
GET /api/system/CVEWhitelist
Authorization: xxxxxxx
```

##### On Success: OK

```HTTP
200 OK
Content-Length: <length>
Content-Type: application/json
{
	"items": [{
			"cve_id": "CVE-2019-12310"
		},
		{
			"cve_id": "CVE-2017-16775"
		}
	],
	"expires_at": 1573254000   <------------ seconds since epoch, optional attribute
}
```

##### On Failure: Authentication Required

This error happens when the request fails to authenticate.

```HTTP
401 Unauthorized
{"code":401,"message":"UnAuthorized"}
```

#### Update System vulnerability whitelist

Only system admin has permission to call this API, which overwrites the whitelist according to the request body.

```HTTP
PUT /api/system/vuln_whitelist
Authorization: xxxxxxx
Content-Type: application/json

{
	"items": [{
			"cve_id": "CVE-2019-12310"
		},
		{
			"cve_id": "CVE-2017-16775"
		}
	],
	"expires_at": 1573254000  <---------  optional
}

```

##### On Success: OK

```HTTP
200 OK
```

##### On Failure: Forbidden
                  
This error happens when the request does not has sufficient permission to do the update
 
```HTTP
403 Forbidden
{"code":403,"message":"Forbidden"}
```

### Add whitelist information to project metadata

Given the way we handle project level configuration currently, we don't plan to introduce new APIs.  Instead, when issuing 
API to update the metadata, new attribute `vuln_whitelist` will be added to the request:

```HTTP
PUT /api/projects/{id}
Authorization: xxxxxxx
Content-Type: application/json
{
	"metadata": {
	   .....
	   "reuse_system_cve_whitelist": false,
	   "cve_whitelist": {
	   	"items": [{
       			"cve_id": "CVE-2019-12310"
       		},
       		{
       			"cve_id": "CVE-2017-16775"
       		}
       	],
       	"expires_at": 1573254000    <------------ optional attribute
	}
}
```

When `reuse_system_whitelist` is set to true, the system level CVE whitelist will be applied to this project, and the `cve_whitelist` 
in the JSON will be ignored.

A table `cve_whitelists` will be created to store project and system level cve whitelists.

### Applying the whitelist when handling request to pull the image

The code in `vulnerableHandler` in interceptors will be updated to call Clair API to get the full vulnerability list of
an image and filter out the ones in the whitelist, then use the highest level of the one in the filtered list and the overall
vulnerability level.

We need to make sure to log the filtering of the vulnerability in a very explicit way.

The code in the job handler of `scanjob` to store the overview of scan result will be removed.  The API code will call Clair's
API to generate the "scan overview" data object to help UI render the diagram.

The webhook handler to handle the notification from Clair will be removed.

### UI consideration
We should provide UI components for system admin to view and update the system level CVE whitelist.  Including the list and 
expiration.  It should be able to explicitly inform the user when the white list is expired.

We should also provide UI components for project admin to reuse the system level whitelist or create/update CVE whitelist for the project.
 
Initially we can assume a regular whitelist does not contain many items (less than 20, usually less then 10), but we need 
to make sure the user can easily view/update the items in the whitelist when the number grows.

## Open issues (if applicable)

The engineering work will be tracked by the Epic:  
https://github.com/goharbor/harbor/issues/7942
