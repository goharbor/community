# Proposal: Purge and Forward Audit Log 

Author: stonezdj

Discussion: 
   [#128](https://github.com/goharbor/harbor/issues/128)
   [#15653](https://github.com/goharbor/harbor/issues/15653)
   [#15496](https://github.com/goharbor/harbor/issues/15496)
   [#13513](https://github.com/goharbor/harbor/issues/13513)
   [#13373](https://github.com/goharbor/harbor/issues/13373)


## Abstract

The audit_log table grows rapidly sometimes, need to delete some history records for better query performance and free disk space.
When the number of records is greater than 100M, it might significantly slow down related queries. the table size of audit_log in some env might be 10-20GB, it has some impact on the database performance and need to rotate periodically.

## Background

The audit_log is used to record the image pull/push/delete operations in Harbor. administrators could retrieve the history of the operation log. In a typical large Harbor server, there might be a large amount pull request and small amount of push request, delete request. most of the request are pull requests to public repository. the audit_log of these request might consumes 90% of the request. the query to the audit_log cannot work properly because the records in audit_log is huge, the query to this table might be timeout.

Because the audit log is stored in database table, it cost of amount DB IO time to write the audit_log, it is better to provide a configurable way to log these information in either the file system or database.

The current audit_log just log the push/pull/delete event related to the image, there are variaty of operation event need to log in the audit log, for example, add/remove the member of a project, change the project tag retention policy etc. there should be flexible and extensible implementation of the audit_log

The audit_log table because of it is large size, it requires the DBA to create a job to clean up it periodically and it also cause the historical data cannot be retrieved.

## Proposal

Purge the audit log with a specified schedule, for example, every day at 00:00:00, or every week at 00:00:00. it could specify the operations need to delete and the retention hours need to keep. user could schedule the job to delete the audit_log records manually or periodically. if the audit log retention hours is set to 0, it means the audit log will be kept.

The purge audit log job could be scheduled by cron job or manually. after executed the job, the purge job history could be retrived by the API.

Forward the audit log to the external service, for example, the audit log could be forwarded to the LogInsight and logstash service. if no audit log forward enpoint configured, then there should be no audit log output. if the current audit log forward endpoint is not reachable, there is no audit log output and it will be a warning message in the core log.

## User stories

* As a system admin, user can configure the audit log purge job.
* As a system admin, user can schedule/run the audit log purge job
* As a system admin, user can check the run history of audit log job.
* As a system admin, user can check the log of a specific audit purge job.
* As a system admin, user can disable the audit log in database.
* As a system admin, user can configure the audit log forward settings

## Non-Goals

- If a user upgrade Harbor from previous version, the default behavior should be the same as the previous version.
- Backup the audit_log table in database
- Extended the audit log format to log more information like the project member change, project olicy change, etc. 
- Requirement discussed: 
https://github.com/goharbor/harbor/issues/15134
https://github.com/goharbor/harbor/issues/14277


## Rationale

Log all event in the audit log table and periodically rotate the audit_log table to the audit.log file maybe an option, but it will be a lot of DB IO time. also the audit log file's event time is not accurate. it will record the event time in the audit_log table, but the audit.log file will be the real event time.

The purge job of the audit_log table is not a good idea, it will cause the historical data cannot be retrieved in the UI, but it could be retrieved from the LogInsight or other log analysis tool.

The purge job could be implemented as goroutine in harbor-core, but it will create too many unmanaged goroutine in harbor-core and is possible to cause performance issue in harbor-core.

## Compatibility

The previous version's data in audit_log table could be purged by audit log purge job.

## Implementation

The implementation could be specified in two parts, the first part is the audit logger forward, the second part is the audit log rotate job.

### Audit logger

#### Init audit logger

```
// InitAuditLog redirect the audit log to the forward endpoint
func InitAuditLog(level syslog.Priority, logEndpoint string) error {
	al, err := syslog.Dial("tcp", logEndpoint,
		level, "audit")
	if err != nil {
		logger.Errorf("failed to create audit log, error %v", err)
		return err
	}
	auditLogger.setOutput(al)
	return nil
}

```

If the audit log forward endpoint is changed, need to run the InitAuditLog again in the configuration handler.
The log forward endpoint's status will be monitored, if the status is inactive, the audit log forward will be disabled, and there should be an error in the core.log.

#### Log audit event in the audit log controller

```
// Create ...
func (c *AuditLogController) Create(ctx context.Context, audit *model.AuditLog) (int64, error) {
	if strings.EqualFold(audit.Operation, "pull") {
		log.AL.WithField("operator", audit.Username).
			WithField("time", audit.OpTime).
			Infof("%s :%s", audit.Operation, audit.Resource)
	}
	if !config.AuditLogInDB(ctx)  {
		return 0, nil
	}
	return c.auditMgr.Create(ctx, audit)
}
```

Replace the audit log manager with the audit log controller in audit_log.go.

```
func (h *Handler) Handle(ctx context.Context, value interface{}) error {
	...
	if addAuditLog {
		resolver := value.(AuditResolver)
		al, err := resolver.ResolveToAuditLog()
		if err != nil {
			log.Errorf("failed to handler event %v", err)
			return err
		}
		auditLog = al
		if auditLog != nil {
			_, err := audit.Ctl.Create(ctx, auditLog)
			if err != nil {
				log.Debugf("add audit log err: %v", err)
			}
		}
	}
	...
}
```

#### Purge the audit log table

The Purge audit log should be implemented as job service type

```
// Run the replication logic here.
func (j *AuditJob) Run(ctx job.Context, params job.Parameters) error {
	logger := ctx.GetLogger()
	logger.Info("Purge audit job starting")
	j.parseParams(params)
	ormCtx := ctx.SystemContext()
	if j.retentionHour == -1 || j.retentionHour == 0 {
		return nil
	}
	if err := audit.Mgr.Purge(ormCtx, j.retentionHour, includeOperations); err != nil {
		log.Errorf("failed to purge audit log, error %v", err)
	}
	// Successfully exit
	return nil
}
```

### UI

There is an audit log config in the main nativgation tree.
It includes three tabs:

### Purge Job

In purge job schedule, there are two items:

1. Audit log retention hour -- the audit log retention hour, default is 0, means no purge operation. this value could be changed by the administrator.
2. Audit log purge include operations -- the audit log purge operation, default is all operations, if specify operations, only the specified operations will be purged. for example, when pull is specified, then only pull operation will be purged.
3. Audit log purge job schedule -- the audit log purge job schedule, default is empty, means no schedule, if it is not empty, it will be used to schedule the audit log purge job. for example 
`0 0 0 * * *` is the cron expression for the audit log purge job for every day at 0:00:00. when the user trigger the purge job, there should be a warning message that purge job will delete data from audit_log table and can't be recoverd, please backup the table first.

### Purge Job History

In the purge job history page, it list the execution of the purge job, when purge job history is completed, the log of the purge job will be shown.

### Audit log forward endpoint

There are three audit log forward endpoint configure items:

1. No audit log in database -- Do not log the audit log in the database, default is false.
2. Log forward endpoint  -- the audit log forward endpoint, it could be syslog server. default is harbor-log:10514, it is the docker-compose syslog forward endpoint.

### Other UI changes

If a user enable the option no audit log in database, then all audit log related UI should be hidden. it include the logs in main UI and the project tab.

## Open issues (if applicable)

The current audit log implementation is syslog, it is not work as previous core.log or registry.log, which are log to stdout of the container. the audit log might need to configure separately in kubernetes.

The schema of the audit_log will be changed in furture, users might have to change the query to get a specific information in LogViewer/LogInsight.

The audit log retention job will be implemented with job service, and it will be scheduled by the jobservice with higher priority such as 5000.(jobservice priority range 1000-10000)