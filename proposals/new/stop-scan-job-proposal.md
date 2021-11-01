# Proposal: Stop scan job

Author:  `Shengwen Yu` `Weiwei He`

Discussion: 

* https://github.com/goharbor/harbor/issues/14831
* https://github.com/goharbor/harbor/issues/15338

Version: **Draft** | Review | Approved

## Abstract

Scanning a container image to identify and detect potential vulnerabilities is an essentail feature for artifacts management to avoid malicious attack against production environment. Currently Harbor supports Trivy and Clair as two optional scanning tools, which can be configured during the Harbor installation process, to achieve this purpose. Generally speaking, there are two categories of scanning job in Harbor: one of the them is the scan job of a given artifact, the other one is a scan job for all artifacts. Nevertheless, ethier of the two can be resource-consuming, and makes Harbor hardly to handle incoming requests. Therefore, it's worthwhile having a stop scan job feature in Harbor to terminate a "scan all job" or "scan job of a given artifact".

## Goal

1. Be able to terminate a scan all job at the system level for all artifacts.
2. Be able to cancel a scan job of a particilar artifact within a repository of a given project.

## Implementation

### Stop scan all job

#### API definition

When a Harbor user wants to create a scheduled or a manual trigger for the scan all job, he can refer to this API definition for more details:

```bash
POST /system/scanAll/schedule
```

The API introduced to stop "scan all job" is specified within the following API design:

```
POST /system/scanAll/stop
```

```yaml
  /system/scanAll/stop:
    post:
      summary: Stop scanAll job execution
      description: Stop scanAll job execution
      parameters:
        - $ref: '#/parameters/requestId'
      tags:
        - scanAll
      operationId: stopScanAll
      responses:
        '200':
          $ref: '#/responses/200'
        '400':
          $ref: '#/responses/400'
        '401':
          $ref: '#/responses/401'
        '403':
          $ref: '#/responses/403'
        '500':
          $ref: '#/responses/500'
```

#### Handler implementation

The handler for dealing with "stop scan all job" will be implemented like this, within `src/server/v2.0/handler/scan_all.go`file:

```go
// StopScanAll stops the execution of scan all artifacts.
func (s *scanAllAPI) StopScanAll(ctx context.Context, params operation.StopScanAllParams) middleware.Responder {
	if err := s.requireAccess(ctx, rbac.ActionStop); err != nil {
		return s.SendError(ctx, err)
	}

	execution, err := s.getLatestScanAllExecution(ctx)
	if err != nil {
		return s.SendError(ctx, err)
	}
	if execution == nil {
		message := fmt.Sprintf("no scan all job is found currently")
		return s.SendError(ctx, errors.BadRequestError(nil).WithMessage(message))
	}
	err = s.execMgr.Stop(ctx, execution.ID)
	if err != nil {
		return s.SendError(ctx, err)
	}

	return operation.NewStopScanAllAccepted()
}
```

#### Robot account permission

A new action type `ActionStop = Action("stop")` will be added to the rbac definition list for `scan-all` resource to stop a scan-all job.

|     API     | Resource | Action |
| :---------: | :------: | :----: |
| StopScanAll | scan-all |  stop  |

### Stop scan job of a particular artifact

#### API definition

Currently, creating a scan job of a particular artifact is defined in this API: 

```bash
POST /projects/{project_name}/repositories/{repository_name}/artifacts/{reference}/scan
```

A new API will be added to cancel, as needed, a currently running scan job of an artifact, and this new API is defined as below:

```
POST /projects/{project_name}/repositories/{repository_name}/artifacts/{reference}/scan/stop
```

```yaml
  /projects/{project_name}/repositories/{repository_name}/artifacts/{reference}/scan/stop:
    post:
      summary: Cancelling a scan job for a particular artifact
      description: Cancelling a scan job for a particular artifact
      tags:
        - scan
      operationId: stopScanArtifact
      parameters:
        - $ref: '#/parameters/requestId'
        - $ref: '#/parameters/projectName'
        - $ref: '#/parameters/repositoryName'
        - $ref: '#/parameters/reference'
      responses:
        '202':
          $ref: '#/responses/202'
        '400':
          $ref: '#/responses/400'
        '401':
          $ref: '#/responses/401'
        '403':
          $ref: '#/responses/403'
        '404':
          $ref: '#/responses/404'
        '500':
          $ref: '#/responses/500'
```

#### Handler implementation

The handler for "stop single scan job" is implemented as following in `src/server/v2.0/handler/scan.go` file:

```go
func (s *scanAPI) StopScanArtifact(ctx context.Context, params operation.StopScanArtifactParams) middleware.Responder {
	if err := s.RequireProjectAccess(ctx, params.ProjectName, rbac.ActionStop, rbac.ResourceScan); err != nil {
		return s.SendError(ctx, err)
	}

	// get the artifact
	curArtifact, err := s.artCtl.GetByReference(ctx, fmt.Sprintf("%s/%s", params.ProjectName, params.RepositoryName), params.Reference, nil)
	if err != nil {
		return s.SendError(ctx, err)
	}

	if err := s.scanCtl.Stop(ctx, curArtifact); err != nil {
		return s.SendError(ctx, err)
	}

	return operation.NewStopScanArtifactAccepted()
}
```

This `StopScanArtifact` function introduces a new method, `Stop()`, in scan controller interface `src/controller/scan/controller.go`, defined as below:

```go
// Controller provides the related operations for triggering scan.
type Controller interface {
  // ....
  
	// Stop scan job of the given artifact
	//
	//   Arguments:
	//     ctx context.Context : the context for this method
	//     artifact *artifact.Artifact : the artifact whose scan job to be stopped
	//
	//   Returns:
	//     error  : non nil error if any errors occurred
	Stop(ctx context.Context, artifact *artifact.Artifact) error
  
  // ...
}
```

And this `Stop()` method in scan controller is going to be implemented in this file `src/controller/scan/base_controller.go`:

```go
// Stop scan job of a given artifact
func (bc *basicController) Stop(ctx context.Context, artifact * ar.Artifact) error {
	query := q.New(q.KeyWords{"extra_attrs.artifact.id": artifact.ID})
	executions, err := bc.execMgr.List(ctx, query)
	if err != nil {
		return err
	}
	if len(executions) == 0 {
		return errors.New(nil).WithCode(errors.NotFoundCode).
			WithMessage("scan job of artifact ID=%v not found", artifact.ID)
	}
	execution := executions[0]
	return bc.execMgr.Stop(ctx, execution.ID)
}
```

#### Robot account permission

The new action type `ActionStop = Action("stop")` will also be enabled for `scan` resource as well to stop a single scan job of a given artifact.

|       API        | Resource | Action |
| :--------------: | :------: | :----: |
| StopScanArtifact |   scan   |  stop  |

### ShouldStop() check

In the method `func (j *Job) Run(ctx job.Context, params job.Parameters) error {}` of file `src/pkg/scan/job.go`, we will do the `shouldStop` check at some main steps. `shouldStop` is an anolymous function to be added within `func (j *Job) Run(){}` method: 

```go
	// shouldStop checks if the job should be stopped
	shouldStop := func() bool {
		if cmd, ok := ctx.OPCommand(); ok && cmd == job.StopCommand {
			return true
		}
		return false
	}
```

And `shouldStop()` will be invoked in these following scenarios:

1. before `client, err := r.Client(v1.DefaultClientPool)` Do `shouldStop()` check before registering a scanner client.
2. before `resp, err := client.SubmitScan(req)` Do `shouldStop()` check before submitting an actual scanning job of a given artifact.
3. right after `case t := <-tm.C:` Do `shouldStop()` check when everytime trying to fetch a scan report.
4. before persisting scan report data into database, `for i, mimeType := range mimeTypes {...}`

## Webhook

SCANNING_STOPPED is registered and enabled as the topic for stopping scan jobs. Everytime a stop scan job event is happened, the webhook for this scanning stopped event will be triggered. And a sample payload for SCANNING_STOPPED is like this:

```json
{
  "type": "SCANNING_STOPPED",
  "occur_at": 1630650206,
  "operator": "auto",
  "event_data": {
    "resources": [
      {
        "digest": "sha256:e4f0474a75c510f40b37b6b7dc2516241ffa8bde5a442bde3d372c9519c84d90",
        "tag": "1.13.12",
        "resource_url": "10.83.7.171/library/nginx:1.13.12",
        "scan_overview": {
          "application/vnd.scanner.adapter.vuln.report.harbor+json; version=1.0": {
            "report_id": "a461def0-69a5-42d0-adb1-1e3b21740aed",
            "scan_status": "Stopped",
            "severity": "",
            "duration": 20,
            "summary": null,
            "start_time": "2021-09-03T06:23:06Z",
            "end_time": "2021-09-03T06:23:26Z",
            "complete_percent": 0
          },
          "application/vnd.security.vulnerability.report; version=1.1": {
            "report_id": "7334d507-2f5a-4ad5-ada8-e933cdb226ac",
            "scan_status": "Stopped",
            "severity": "",
            "duration": 20,
            "summary": null,
            "start_time": "2021-09-03T06:23:06Z",
            "end_time": "2021-09-03T06:23:26Z",
            "complete_percent": 0
          }
        }
      }
    ],
    "repository": {
      "name": "nginx",
      "namespace": "library",
      "repo_full_name": "library/nginx",
      "repo_type": "public"
    }
  }
}
```

