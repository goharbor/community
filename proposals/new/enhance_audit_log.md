Proposal: Enhance Audit Log

Author: Stone Zhang

# Abstract

Enhance the audit log to include more information about the actions taken by users in the system. such as user login/logout, user creation/deletion, configuration change etc.

# Background

Harbor is an important component in the cloud-native software security supply chain, it is used to store and distribute artifact through the software develement lifecycle. many users concern about the audit log to log important security events in the Harbor, so that every security incident can be traceable. They want to enrich the event type to add the following:

1. User login, include success and failed login
1. User create/delete
1. Project member add/remove, including user and group member
1. Configuration change, including system-level config and project-level configure
1. Project policy change: include the tag retention, and immutable policy change
1. Audit log cleanup schedule or execution

With the above event type, the Harbor administrator can trace the user's behavior in the system, and know who has done what in the system, and when it happened, and the source of the request. make the Harbor more secure and traceable.

# Related requirement issues

- https://github.com/goharbor/harbor/issues/21148
- https://github.com/goharbor/harbor/issues/20295
- https://github.com/goharbor/harbor/issues/20293
- https://github.com/goharbor/harbor/issues/20292
- https://github.com/goharbor/harbor/issues/18351
- https://github.com/goharbor/harbor/issues/15134
- https://github.com/goharbor/harbor/issues/14277
- https://github.com/goharbor/harbor/issues/4426
- https://github.com/goharbor/harbor/issues/11996

# Personas and User Stories

1. As a Harbor administrator, I want to know who has logged in/logout to the system, so that I can trace the user's behavior in the system.
1. As a Harbor administrator, I want to know who has created/updated/deleted a user, so that I can trace the user's behavior in the system.
1. As a Harbor administrator, I want to know who has added/removed a project member, so that I can trace the user's behavior in the system.
1. As a Harbor administrator, I want to know who has changed the system configuration, so that I can trace the user's behavior in the system.
1. As a Harbor administrator, I want to know who has changed the project configuration, so that I can trace the user's behavior in the system.
1. As a Harbor administrator, I want to know who has changed the project policy, so that I can trace the user's behavior in the system.

# Solution

## Event Format
The audit log format should be changed as follow

```go
type AuditLog struct {
    ID           int64     `orm:"pk;auto;column(id)" json:"id"`
    ProjectID    int64     `orm:"column(project_id)" json:"project_id"`
    Operation    string    `orm:"column(operation)" json:"operation"`
    OperationDescripton string
    OperationResult string
    ResourceType string    `orm:"column(resource_type)"  json:"resource_type"`
    Resource     string    `orm:"column(resource)" json:"resource"`
    Username     string    `orm:"column(username)"  json:"username"`
    OpTime       time.Time `orm:"column(op_time)" json:"op_time" sort:"default:desc"`
    RequestPayload string
}
```

Add OperationDescription, OperationResult, RequestPayload to the audit log.

## Middleware to capture the audit log event

Create an audit log middleware which capture the http request and response v2.0 related API
If the request is a POST method, it indicate a create operation , user login also use POST method.
If the request is a PUT method, it indicate an update operation 
If the request is a DELETE method, it indicate a delete operation
Use a ResponseWriter to get response code and the response header,  
If the http response code between 200 and 201, then it is considered to be success,  others should be failure.
If it is a POST event, it maybe a create operation, then the Location should be put in the response header, the audit log could retrieve the resource id from the location field.

## Audit Log Handling Flow

In the current audit log flow, the audit log is handled asynchronously, the audit log event is sent to the event queue, and the audit log handler will fetch the event from the queue, call ResolveToAuditLog, and create an audit log item.
```
Metadata --> notification.Event -> Resolve to Event -> Resolve to Audit Log Event
```

Under this framework, if need to add a new event type, it requires the following steps:

1. Add new event metadata in the controller/event/metadata folder and implement the Resolve method to resolve the current Metadata to the event.
1. Add new event type in the controller/event/topic.go file, and implement the ResolveToAuditLog method to resolve the current event to the audit log.
1. Add topic for each event type in the controller/event/topic.go file, and register the event handler in the controller/event/handler.go file.
1. Update the controller/event/handler/init.go file to add the auditlogHandler to subscribe to the new event type.
1. Update the controller/event/handler/auditlog/auditlog.go file to handle the new event type.

The above steps are cumbersome and error-prone when there are too many event types. To simplify the process, we can create a common event metadata and a common event that can handle all events related to the v2.0 API. When an event occurs, create a metadata and call notification.AddEvent(ctx, event, true) to send the event queue. The middleware will process the event in the queue when the request is complete. These events will be handled asynchronously. These events will be sent to same topic, the audit log handler will fetch the event from the queue, call ResolveToAuditLog, and create an audit log item.

The common event metadata should include the context information of the current event and resolve it into a CommonEvent. it includes all required context information of the current event.  and implement the Resolve method to resolve the current Metadata to common event.

```go
type Metadata struct {
	Ctx context.Context
	// Username requester username
	Username string
	// RequestPayload http request payload
	RequestPayload string
	// RequestMethod
	RequestMethod string
	// ResponseCode response code
	ResponseCode int
	// RequestURL request URL
	RequestURL string
	// ResponseLocation response location
	ResponseLocation string
}
```

## Log Middleware

There is an existing log middleware to add the 'X-Request-ID' to the request context, we can update the log middleware to capture the audit log event.

```go

func Middleware() func(http.Handler) http.Handler {
    ...
    // Add audit log middleware
		enableAudit := false
		urlStr := r.URL.String()
		username := "unknown"
		re := regexp.MustCompile("^/c/log_out$")
		var requestContent string
		if r.Method == http.MethodPost || r.Method == http.MethodPut || r.Method == http.MethodDelete || (r.Method == http.MethodGet && re.MatchString(urlStr)) {
			enableAudit = true
			lib.NopCloseRequest(r)
			body, err := io.ReadAll(r.Body)
			if err != nil {
				http.Error(w, "Failed to read request body", http.StatusInternalServerError)
				return
			}
			requestContent = string(body)
			if secCtx, ok := security.FromContext(r.Context()); ok {
				username = secCtx.GetUsername()
			}
		}
        // use a wrapper to get the response code and response header
		rw := &ResponseWriter{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
		}

		next.ServeHTTP(rw, r)

		if enableAudit {
			ctx := r.Context()
			event := &commonevent.Metadata{
				Ctx:              ctx,
				Username:         username,
				RequestMethod:    r.Method,
				RequestPayload:   requestContent,
				RequestURL:       urlStr,
				ResponseCode:     rw.statusCode,
				ResponseLocation: rw.header.Get("Location"),
			}
			notification.AddEvent(ctx, event, true)
		}
}
```

Except the logout, which is a GET method and is required to be captured by the audit log, so we need to add a regular expression to match the logout event. Any request with POST, PUT, DELETE method will be captured by the log middleware, and the audit log event will be sent to the event queue.
According to the REST API standard, response codes between 200 and 201 is considered to be successful; others should be considered failures. 

1. If it is a POST event, it maybe a create operation, then the Location should be put in the response header, the audit log could retrieve the resource id from the location field.
1. If it is a PUT event, it maybe an update operation, the resource id should be retrieved from the request URL.
1. If it is a DELETE event, it maybe a delete operation, the resource id should be retrieved from the request URL.
1. If it is a GET event, it maybe a query operation and can be ignored.

If the API of create/delete/update follows the REST API standard, and the the response code and response header are set correctly, and the base URL has and only has the resource ID in the end, it could be covered by basic event type.

If the Event is not a basic event type, we need to add a new resolver to resolve the common event to the specific event type.

## Event Resolve 

The common event metadata includes all context information of the current event, the Resolve method can resolve to different event types according to the request URL and request method.

```go
var urlResolvers = map[string]Resolver{
	`/api\/v2\.0\/configurations$`:                   configureEventResolver,
	`/c\/login$`:                                     loginEventResolver,
	`/c\/log_out$`:                                   loginEventResolver,
	`/api\/v2\.0\/users$`:                            userResolver,
	`^/api/v2\.0/users/\d+/password$`:                userResolver,
	`^/api/v2\.0/users/\d+/sysadmin$`:                userResolver,
	`^/api/v2\.0/users/\d+$`:                         userResolver,
	`^/api/v2.0/projects/\d+/members`:                projectMemberResolver,
	`^/api/v2.0/projects/\d+/members/\d+$`:           projectMemberResolver,
	`^/api/v2.0/projects$`:                           projectResolver,
	`^/api/v2.0/projects/\d+$`:                       projectResolver,
	`^/api/v2.0/retentions$`:                         tagRetentionResolver,
	`^/api/v2.0/retentions/\d+$`:                     tagRetentionResolver,
	`^/api/v2.0/projects/\d+/immutabletagrules$`:     immutableTagEventResolver,
	`^/api/v2.0/projects/\d+/immutabletagrules/\d+$`: immutableTagEventResolver,
	`^/api/v2.0/system/purgeaudit/schedule$`:         purgeAuditResolver,
	`^/api/v2.0/robots$`:                             robotResolver,
	`^/api/v2.0/robots/\d+$`:                         robotResolver,
}


// Resolve parse the audit information from CommonEventMetadata
func (c *Metadata) Resolve(event *event.Event) error {
	for url, r := range urlResolvers {
		p := regexp.MustCompile(url)
		if p.MatchString(c.RequestURL) {
			return r.Resolve(c, event)
		}
	}
	return nil
}

```
For each basic event type, we can create a resolver to resolve the common event to the specific event type, such as userResolver, projectResolver, robotResolver, etc.
For other event type, which can not be resolved by the current resolver, we can add a new resolver to resolve the common event to the specific event type. such as the projectMemberResolver, loginEventResolver, purgeAuditResolver, etc. these resolver also implements the Resolver interface.

## Disable Specific Audit Log Event 
Because there are lots of event types add to the audit log, some user might need to skip some unwanted event type. to disable it, the user need to configure audit_log_disable like that
```
create_user, delete_user, update_user
```
It skip to log the user create, user delete, user update event to audit log table.

In the handler of audit log, add condition to check if the current <operation>_<resourcetype> is enabled, default value is enabled for all event type.
```go
func (h *Handler) Handle(ctx context.Context, value interface{}) error {
	...
		if auditLog != nil && config.AuditLogEnabled(ctx, fmt.Sprintf("%v_%v", auditLog.Operation, auditLog.ResourceType)) {
			_, err := audit.Mgr.Create(ctx, auditLog)
			if err != nil {
				log.Debugf("add audit log err: %v", err)
			}
		}
	...
}
```
With this feature, the previous configure option `pull_audit_log_disable` can be deprecated. Just use `audit_log_disable` to disable the unwanted event type.

## Purge Audit Log

Because purge audit log will delete the audit log periodically,  and it allow user to select the event to purge, the new type of event should be added to the selection, such as user login/logout, user create/delete, project member add/remove, configuration change, project policy change. it involves too many event type, so we can categorize the event type to the following:
common api event type by the resource name, such as user, project, robot, tag retention, immutable tag rule, purge audit, etc. previous event type is removed from option, and just add new resource types to the selection.

## Related UI changes

### Disable Audit Log Event Type

Add a new configuration item in the system configuration page to disable the unwanted audit log event type.
Add the `audit_log_disable` configuration item in the Configuration -> System Settings page, the user can input the event type to disable the audit log event, the event type should be separated by comma. Because the event type is the combination of operation and resource type, the user can input the operation and resource type to disable the audit log event. it is a string type configuration item. 

![Disable Audit Log Event Type](../images/enhance_auditlog/config_disable_event_type.png)


### Audit Log Page

Update audit log page to display the audit log event, the user can filter the audit log event by the operation, resource_type, resource, the operation description and operation_result is visible to users.

![List Audit Log Event Type](../images/enhance_auditlog/audit_log.png)

### Cleanup Audit Log

In the previous implementation, only image related event types could be selected to purging, such as create/delete/pull. we need to add more options to select new event types. Because there are too many event types to display in the UI, just provide the resource type to clean up the audit log.


![Cleanup Audit Log Event Type](../images/enhance_auditlog/cleanup_audit_log.png)


## Schema Change

Because previous audit_log table maybe contains large amount of old record, it might cause the update to this table very slow, so we need to create a new table to store the new audit log event, and the old audit log table will be deprecated.

The audit_log_v2 table schema should be changed to adapt the new audit log format. 

```sql
create table audit_log_v2
(
	id bigint auto_increment
		primary key,
	username varchar(50) null,
	project_id bigint,
	operation varchar(50) null,
	op_desc varchar(500) null,
	op_result varchar(50) null,
	resource_type varchar(50) null,
	resource varchar(50) null,
	payload text null,
	op_time datetime null,
);

```

Because the audit log can be forworad to log process endpoints such as LogInsight, ELK(Elastic Logstash Kibana) etc, if add the `op_desc` operation description makes the information more readable to the end user.

The `op_result` field is used to store the operation result, it is useful to know if the operation is success or failure.
`payload` is a reserved column.

## Security

All passwords in the payload field will be masked before storing in the audit log. 
In previous implementation, the audit log is visible to all users, because there are lot of sensitive information might be store in the audit log, in this release, the audit log is only visible to the project admin role and system admin role.

## Compatibility

The new audit log event type is compatible with the previous audit log event type, the previous audit log event type is still supported, and the new audit log event type is added to the audit log v2 table. 
After enable Audit Log Forward Syslog Endpoint option, it can be forward to the log process endpoints such as LogInsight, ELK(Elastic Logstash Kibana) etc.


## Failure Cases

Because the audit log is handled asynchronously in the harbor-core container, if the harbor-core crashes before the audit log is recorded, the audit log event in the queue will be lost. it is a known issue in the current implementation, and it is out of the scope of this proposal.

## Breaking Changes

The audit log is only visible to the project admin role and system admin role. for a normal user not in project admin neither sys admin, the audit log should be invisible in the UI.

## Non-Goals

The current audit log is based on the http middleware, it means it can only capture the event has http request and http response, and it is initiated by the user, usually it is a user action. for system level background job, such as the job service, the event is not captured by the audit log. it is out of the scope of this proposal.

## Terms

```mermaid
sequenceDiagram
    participant LogMiddleware
    participant RequestEventQueue
    participant NotificationMiddleware

    LogMiddleware->>LogMiddleware: createMetadata()
    LogMiddleware->>RequestEventQueue: addEvent(event)
    loop Iterate events in queue
        NotificationMiddleware->>RequestEventQueue: Iterate
        alt event.isSuccess or event.mustNotify
            NotificationMiddleware-->>NotificationMiddleware: BuildAndPublish(event)
        end
    end
```