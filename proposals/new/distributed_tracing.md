# Proposal: Add Distributed Tracing for Harbor

Author: `<ninjadq>` `<stonezdj>`

## Abstract

Tracing is an essential feature for modern application. In this proposal we plan to leverage Open-Telemetry to add the distributed tracing feature in Harbor. In order to ease the throubleshooting in production and add a new persperctive to have insight of Harbor. 

## Background

Metric, log and distributed tracing are three pillar of observability which is an essential character of modern application. The metrics and logs are already included in harbor. The last pillar distributed tracing is not provided by harbor but it is really helpful to improve performance and debug in production espicially in Cloud Native envrionment.

## Proposal

### Library used to collect trace data

In this proposal we plan to use the [Open-Telemetry]([OpenTelemetry](https://opentelemetry.io/)) (a project merged by open-tracing and open-cences) to provide distributed tracing. 

![](/Users/dengq/Work/goharbor/community/proposals/images/tracing/trace_arch.png)

### Tracing Data to Provide

* Harbor-core
  * HTTP Server
  * HTTP Client
  * DB access related trace (optional)
* Harbor-Jobservice
  * HTTP Server
  * HTTP Client
  * Job details (optional)
* Registry-ctl
  * HTTP Server
  * HTTP Client
  * GC details (optional)

### Tracing data Expose Format

* Jaeger
* Open-zipkin
* Otlp



### Integrating with K8S Env

In this proposal we didn't provide some special changes for k8s. But users can provide tracing agent or collector by themselves. Then configure harbor with the defined agent or collecor. As a result, users can consuming the all these tracing data provided by Harbor.



## Non-Goals

* Add distributed tracing in third party component which used in Harbor(like postgres, redis, trivy, etc.).

* Process, storage and analysis the tracing data



## Rationale

### The choice of Tracing Library

There are so many choices for adding distributed tracing feature. We invastigated Jaeger, Open-zipkin, Opentracing, Open-cencus, Open-telemetry.

both jaeger and Open-zipkin are faumous distruibuted solution. But their SDK aren't  general enough and compatible with each other or other solution. And we remove them from our candidate pool.

The open-tracing standard are well accpected in industry and Open-cencus are originated from google and has a lot of third party libraries and well tested in large scale environment like google cloud. However they did almost the same thing. Therefore, Their commnunity plan to have a merge. The merged project is Open-Telemetry, 

Open-Telemetry can do all the overservabilitie jobs like metrics, tracing and logging. But we only focused on the tracing part which is tested by some big companies and the tracing API is stable enough.

Although the thrid party support isn't comparable with open-tracing or open-census, we believe with the time by, this will not be a problem. Besides, there is a project Otel-collector which can transfer the data from one format to another format. So we finnaly choosen the Open-Telemetry.

### Metrics vs. Distributed Tracing

Metrics is focused on the overview of the project. The Tracing focused on a specific request. From the metrics dashborad, users can know if the system or function are in a unhealthy status. The tracing can tell you what service and what function call caused the exceptional status. For example, From the metrics, you can know some API are slow in some period of time. With Tracing, you can konw the elaspped time of each trace span inside a slow request.

### Logs vs. Distributed Tracing

Every system has a lots logs but most of them are not useful for you. Maybe only 1/1000 of logs you really care about. So tracing provide a way to show the important logs with a modernized visualization approach. In which you can easily locate the logs you recorded in tracing and their context information.

### Profiling vs. Distributed Tracing

Profiling is useful tool for throubleshooting. It can provide tremendous informations like all the cpu time, memory, goroutine data. But at the same time it will also cost plenty of resources as well. So we can not open the profiling all the time. And profiling only can collect data from one application or service. On the contrary, the Tracing only cost a little resource and always open in production environment. And provide the context information can be taken to locate the root cause. And the cotent collected of tracing is different, The profiling collect all the datas, tracing only collect span data you defined in your code.

### 

## Compatibility

No breaking changes in this feature. All the features in previous version are also work with trace in bosh K8S and docker compose env.

## Implementation

### Add trace related configuration

```yaml
# Configuration file of Harbor

# The IP address or hostname to access admin UI and registry service.
# DO NOT use localhost or 127.0.0.1, because Harbor needs to be accessed by external clients.
hostname: reg.mydomain.com

... ...

trace:
  enabled: true
  sample_rate: 1
  jaeger:
    endpoint: http://localhost
    username: http://localhost
    password:
    agent_host: localhost
    agent_port: 6832
  otel:
    trace:
      endpoint: http://localhost
      url_path: /v1/traces
      compression: no
      insecure: false
      timeout: 10s
    max_attemps: 5
    backoff: 300ms
    retry:
      enabled: true
      initial_internal: 5s
      max_interval: 30
      max_elapsed_time: 1m
  zipkin:
  # ...

```

### HTTP 

server

```go
...
http.Handle("/", otelhttp.NewHandler(http.HandlerFunc(helloGoHandler), "root"))
log.Fatal(http.ListenAndServe(":8080", nil))
...
```

client

```go
...
client := http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)}

...

res, err := client.Do(req)
if err != nil {
	panic(err)
}
...
```

Middleware

```go
func Middleware() func(http.Handler) http.Handler {
  trace := span.TracerProvider().Tracer("goharbor/harbor/core/http")
	return middleware.New(func(w http.ResponseWriter, r *http.Request, next http.Handler) {
		if traceEnabled == true {
		  ctx := c.Ctx.Request.Context()
    	span := trace.SpanFromContext(ctx)
			next.ServeHTTP(w, r.WithContext(ctx))
      span.End()
		} else {
			next.ServeHTTP(w, r)
		}
	})
}

```

Main.go

```
import "go.opentelemetry.io/otel/trace"


var tracer trace.Tracer

func init() {
   tracer = otel.Tracer("github.com/harbor/core/main")
}


ctx, childSpan = tracer.Start(cxt, "my-child-span")
span := trace.SpanFromContext(ctx)
defer childSpan.End()
```

