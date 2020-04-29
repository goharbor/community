# Proposal: `Support Immutable Tags`

Author: `Daojunz / stonezdj, Yan Wang/wy65701436`

Discussion: `https://github.com/goharbor/harbor/issues/3413, https://github.com/goharbor/harbor/issues/9003`

PRD: `https://docs.google.com/document/d/1cPZGf8X0Z7YENp0rq8buq4_A0b2kZimzol6s26kP_lk/edit`

## Abstract

Support Immutable Tags

## Background

Currently Harbor users can repeatedly push an image with the same tag to any repository in Harbor which causes the previous image to be “overwritten” on each push in the sense that the tag now points to a different image and the previous occupant of the tag now becomes tagless.  This is due to Docker’s own implementation which does not enforce the image tag : image digest mapping.  This is undesirable for certain releases that rarely if ever should be tempered with, since the tag can no longer be trusted for identifying the image version and forces digging at the SHA digest for traceability.  The sha256 digest, although reliable and always points to the same build, is not in human-friendly format.  

For example, some tags (e.g. ‘rc’, ‘test’, ‘prod’, ‘nightly’) over the course of their lifetime will likely migrate across different images as new images are pushed to Harbor (e.g. as they are promoted from TEST to QUAL to PROD) while version-specific tags (e.g. v1.6.1, v1.7.2, v1.8.3) or tags auto-generated from CI/CD pipelines like using the branch name or git commit SHA should be immutable as they are meant to represent a point-in-time snapshot.  A version such as ‘Harbor-v1.8.1’ once released should never be changed, any changes should be reflected on the next version such as ‘Harbor-v1.8.2’.  This is further aggravated by the current behavior of deleting a tag will result in the deletion of all other tags that are pointing to the same digest, causing unwanted deletions and having to iterate over images in the repository to find the right image.

By allowing configuring image tags as immutable, i.e. a tag ‘xxx’ always refers to the same image (SHA digest), the Harbor admin can always use the tag to find the specific build that is used to generate the deployed image version.  This has to be a mechanisms based on tags, e.g. if you push an image (e.g. alpine) to an immutable repository (e.g. Harbor.lab.local/test) with a certain tag (e.g. 3.6), then you can not re-push it again to that repository.  

## Proposal

Allow Harbor system and project admin to configure immutability at the project level so images with certain tags cannot be pushed onto Harbor with matching tags so existing images cannot be overwritten.  This mechanism guarantees that an immutable tagged image will always have the same behavior regardless of how subsequent images are pushed, tagged, retagged etc.  Immutable images, cannot be affected by re-pushes, either be deleted.  Immutability can be configured at project level by the combination of filter strings.

Community proposal:
https://github.com/goharbor/harbor/issues/3413

Tag retention example:
```
Docker push harbor.lab.local/test/alpine:3.6
```
When the tag test/alpine:3.6 is set immutable by immutable tag rules, first push is successful. 
Re-push with 
```
Docker push harbor.lab.local/test/alpine:3.6 
```
Harbor throws exception and display error message:
```
Docker unsuccessful because test/alpine is an immutable repository
```
Pushing an update version is perfectly ok
```
Docker push harbor.lab.local/test/alpine:3.7
```
## Non-Goals

Custom permissions set for configuring immutability for certain users, i.e. only Harbor system and project admin can configure immutability

## Rationale

### Mark image tags with immutable label 
    
Mantaining immutable labels for each image tags, it is another way to implement immutable tag, but it takes much effort to do it.

### Rules for immutable tag

For simplify, current implementation only consider rules when filters images should be marked with immutable, not consider rules when images should not be marked with immutable. An image tag should be immutable when it is matched by any rule.

## Compatibility

The immutable image tag is only apply to container images, not include the helm chart.

## Implementation

### The Immutable Tag Rule 

The model for immutable tag rule
```
// ImmutableRule - rule which filter image tags should be immutable.
type ImmutableRule struct {
	ID        int64  `orm:"pk;auto;column(id)" json:"id,omitempty"`
	ProjectID int64  `orm:"column(project_id)" json:"project_id,omitempty"`
	TagFilter string `orm:"column(tag_filter)" json:"tag_filter,omitempty"`
	Disabled  bool   `orm:"column(disabled)" json:"disabled,omitempty"`
}
```
The db schema

```
/** Add table for immutable tag  **/
CREATE TABLE immutable_tag_rule
(
  id SERIAL PRIMARY KEY NOT NULL,
  project_id int NOT NULL,
  tag_filter text,
  disabled BOOLEAN NOT NULL DEFAULT FALSE,
  creation_time timestamp default CURRENT_TIMESTAMP,
  UNIQUE(project_id, tag_filter)
);
```

### API for immutable tags:

For managing and viewing the immutable tag settings, these APIs should be include:

#### Get all immutable tag rules

```
GET /api/projects/{project_id}/immutablerules/
```
On Success: OK
```
Content-Length: <Length>
Content-Type: application/json
[
  
    {"id":1,"project_id":2,"tag_filter":"{\"id\":0,\"project_id\":1,\"disabled\":false,\"priority\":0,\"action\":\"\",\"template\":\"\",\"tag_selectors\":[{\"kind\":\"doublestar\",\"decoration\":\"matches\",\"pattern\":\"release-[\\d\\.]+\"}],\"scope_selectors\":{\"repository\":[{\"kind\":\"doublestar\",\"decoration\":\"matches\",\"pattern\":\".+\"}]}}","enabled":true}
]

```
On Failure: Forbiden

This error happens when the request does not has sufficient permission to get immutable tag rule.
```
403 Forbidden
{"code":403,"message":"Forbidden"}
```

On Failure: Authentication Required

This error happens when the request fails to authenticate.

```
401 Unauthorized
{"code":401,"message":"UnAuthorized"}
```
#### Get single immutable tag rule
```
GET /api/projects/{project_id}/immutablerules/{rule_id}
```
On Success: OK
```
Content-Length: <Length>
Content-Type: application/json
{"id":1,"project_id":2,"tag_filter":"{\"id\":0,\"project_id\":1,\"disabled\":false,\"priority\":0,\"action\":\"\",\"template\":\"\",\"tag_selectors\":[{\"kind\":\"doublestar\",\"decoration\":\"matches\",\"pattern\":\"release-[\\d\\.]+\"}],\"scope_selectors\":{\"repository\":[{\"kind\":\"doublestar\",\"decoration\":\"matches\",\"pattern\":\".+\"}]}}","enabled":true}
```
On Failure: Forbiden

This error happens when the request does not has sufficient permission to get immutable tag rule.
```
403 Forbidden
{"code":403,"message":"Forbidden"}
```

On Failure: Not Found
```
404 Forbidden
{"code":404,"message":"Immutable tag rule not found"}
```

On Failure: Authentication Required

This error happens when the request fails to authenticate.

```
401 Unauthorized
{"code":401,"message":"UnAuthorized"}
```

#### Create an immutable tag rule
```
POST /api/projects/{project_id}/immutablerules/

```
On Success: OK

```
200 OK
```
On Failure: Forbiden
This error happens when the request does not has sufficient permission to create immutable tag rule.
```
403 Forbidden
{"code":403,"message":"Forbidden"}
```
On Failure: Authentication Required
This error happens when the request fails to authenticate.

```
401 Unauthorized
{"code":401,"message":"UnAuthorized"}
```
#### Updated an immutable tag rule
```
PUT /api/projects/{project_id}/immutablerules/{rule_id}
Authorization: xxxxxxx
Content-Type: application/json
{"project_id":2,"tag_filter":"{\"id\":0,\"project_id\":1,\"disabled\":false,\"priority\":0,\"action\":\"\",\"template\":\"\",\"tag_selectors\":[{\"kind\":\"doublestar\",\"decoration\":\"matches\",\"pattern\":\"release-[\\d\\.]+\"}],\"scope_selectors\":{\"repository\":[{\"kind\":\"doublestar\",\"decoration\":\"matches\",\"pattern\":\".+\"}]}}"}

```
On Failure: Forbiden
This error happens when the request does not has sufficient permission to update immutable tag rule.
```
403 Forbidden
{"code":403,"message":"Forbidden"}
```

On Failure: Not Found
```
404 Forbidden
{"code":404,"message":"Immutable tag rule not found"}
```

On Failure: Authentication Required
This error happens when the request fails to authenticate.

```
401 Unauthorized
{"code":401,"message":"UnAuthorized"}
```
#### Delete an immutable tag rule
```
DELETE /api/projects/{project_id}/immutablerules/{rule_id}

```
On Success: OK

On Failure: Forbiden
This error happens when the request does not has sufficient permission to delete immutable tag rule.
```
403 Forbidden
{"code":403,"message":"Forbidden"}
```

On Failure: Authentication Required
This error happens when the request fails to authenticate.

```
401 Unauthorized
{"code":401,"message":"UnAuthorized"}
```
#### Enable/Disable an immutable tag rule
```
PUT /api/projects/{project_id}/immutablerules/{rule_id}
{ "disabled":true }

```

On Success: OK

```
200 OK
```

On Failure: Authentication Required
This error happens when the request fails to authenticate.

```
401 Unauthorized
{"code":401,"message":"UnAuthorized"}
```
On Failure: Forbiden
This error happens when the request does not has sufficient permission to update immutable tag rule.
```
403 Forbidden
{"code":403,"message":"Forbidden"}
```

On Failure: Not Found
```
404 Forbidden
{"code":404,"message":"Immutable Tag Rule not found"}
```


#### Check a tag is immutable

```
function IsImmutable(projectID int, repoName, tagName string) bool 
```

### Apply the immutable tag rule

When a user push an image to Harbor, the code in immutableTagHandler in interceptor filters the image repos and tags of current pushing images, it checks if the current tag exist in database and if it is marked immutable, if current tag already exist and is marked immutable, the push command fails with the message: "The pushing image is already exist and immutable, please push it with another tag". When a user delete an immutable container image, the delete operation should failed with the error message: "The target image is immutable, please change the immutable rule to make it not in the immutable list and try again". Because retag image will result in pushing image, these rules are applied to retag operation.


### UI consideration

We should provide UI components for system admin, project admin and masters to create, view and update the immutable tag rules. it is invisible to developers and guests. when a tag is marked immutable, displays the tag "Immutable". 

## Open issues (if applicable)

All engineering work will be tracked by Epic:  https://github.com/goharbor/harbor/issues/9003

