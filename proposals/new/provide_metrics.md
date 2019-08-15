# Proposal: Provide metrics data

Author: `<Fan Shang Xiang / MartinForReal>`, `<Dang Li/DangLi>`

Discussion: [goharbor/harbor#4557](https://github.com/goharbor/harbor/issues/4557)

## Abstract

This proposal introduce a unified endpoint which provides metrics data for monitoring system.

## Background

Monitoring and obervability is crucial to application operation. And statistical data gathered by monitor services can be used for auto-scaling, capacity plan, auditing and etc.

## Proposal

Collect metrics data from Harbor components and provide metrics facade for monitoring system.

## Non-Goals

Implementing dashboard is out of scopde.

## Rationale

To provide metrics data, we need to think about what we really care about harbor instance, how to collect them and how to present data. And we should follow kiss principle to avoid unnecessary work.

From architecture perspective, Harbor have serveral open source components which already have provided metrics data. Details as follows:

| Component     | Version  | How to get metrics   | Comment                                       |
| ------------- | -------- | -------------------- | --------------------------------------------- |
| Core          | master   |  /statistics         |                       not in prometheus format                        |
| Jobservice    | master   | not provided         |                                               |
| Proxy         | 1.15.11  | [nginx exportor](https://github.com/nginxinc/nginx-prometheus-exporter) |                                               |
| RegistryCtl   | master   | not provided         |                                               |
| Notary Signer | master   | not provided         |                                               |
| Log collector | master   | not provided         |                                               |
| Registry      | v2.7.1   | HTTP `GET /metrics`  | set debug.prometheus=enabled in configuration |
| Chartmuseum   | v0.9.0   | HTTP `GET /metrics`  |                                               |
| Database      | postgres | [postgres exporters](https://github.com/wrouesnel/postgres_exporter) |                                               |
| Redis         | 5.0.5    | [redis exporters](https://github.com/oliver006/redis_exporter) |                                               |
| Clair         | v2.0.9   | HTTP `GET /metrics`  |                                               |
| Notary Server | v0.6.1   | HTTP `GET /metrics`  |                                               |

## Compatibility

Prometheus(aka openmetrics) is the de-facto standard of metrics data format but we still need to provide mechanism to integrate other monitor system, such as zabbix.

For now, harbor doesn't provide offical ha solution but we need to make sure our metrics service design should work under HA scenario.

## Implementation

First, we need to implement metrics service for components as listed above. Here we listed a few measurement indexes  we care when harbor is running in our production system.


| Component     | metrics data                                      | Reference                                                    |
| ------------- | --------------------------------------------------------- | ------------------------------------------------------------ |
| Core          | Number of unauthenticated requets                       |
| Core          | Number of repos                       |                                                                    |
| Core          | Number of users                       |                                                                    |
| Core          | Number of projects                       |                                                                    |
| Core          | Disk usage info                       |                                                                    |
| Core          | Number of chart repo                      |                                                                    |
| Core          | Number of requests                     |  
| Jobservice    | Number of running jobs                         |                                                              |
| Jobservice    | Number of failure jobs                         |                                                              |
| Jobservice    | Number of jobs                         |                                                              |
| Jobservice    | Number of scheduled jobs                         |                                                              |
| RegistryCtl   | Number of failed gc jobs executed in last week            |                                                              |
| RegistryCtl   | Number of gc jobs executed in last week            |                                                              |

Then, A unified metrics data interface should be defined. 

The reason why we need a metrics api is because it simplify the process of processing metrics data in monitoring system by adding more workload related context information.

Last, metrics collector should be implemented to collect metrics data. 

There are open source tools available to help us implement this feature. [opencensus](https://opencensus.io/) is a toolset which helps application expose metrics and trace data to different backend. and it is going to be merged with [opentelemetry](https://opentelemetry.io/).

Opencensus agent collects data in different format from application and expose these data to opencensus collector and other backend. And metrics data can be exposed to different monitoring system without any code change. With opencensus collector's help, metrics data can be exposed in opentelemetry format and can be exported into zabbix server.

## Open issues (if applicable)

[goharbor/harbor#4557](https://github.com/goharbor/harbor/issues/4557)
