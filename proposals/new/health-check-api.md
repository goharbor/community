# Proposal: Health Check API

Author: Wenkai Yin

## Abstract

The proposal introduces an unified health check API for all Harbor services.

## Background

The stability and availability are essential for the modern applications. The awareness of health status of an application is the precondition to make corresponding decisions when encountering software failure.  

The health check API introduced by this proposal can be used to integrated with other monitor systems to help operators manage the Harbor service easier.

## Implementation
Using pull mode, health check API collects status of every components and returns them to the client.  

We'll implement a `HealthChecker` for every components, and the components can determine how to check its status. The `HealthChecker` can collect the status and store it in the memory periodically to reduce the latency.  

The `HealthChecker` is an interface:
```
type HealthChecker interface {
	CheckHealth() error
}
```

The API design is as follow:  

Request:
```
GET /api/health
```

Response(healthy):
```
200 OK
{
  "status": "healthy",
  "components": [
    {
      "name": "core",
      "status": "healthy"
    },
    {
      "name": "clair",
      "status": "healthy"
    },
    ...
  ]
}
```
Response(unhealthy), the status is unhealthy as long as the status of one of the components is unhealthy:
```
200 OK
{
  "status": "unhealthy",
  "components": [
    {
      "name": "core",
      "status": "unhealthy",
      "error": "here is the error message"
    },
    {
      "name": "clair",
      "status": "healthy"
    },
    ...
  ]
}
```

The components that health check API exposes:

Component | Check health | How to check | Comment 
------------|------------|------------|------------
 | Core | Yes |  | As the API is in the same process with Core, we can always return healthy currently  
 | Portal | Yes | HTTP `GET /` |  
 | Jobservice | Yes | HTTP `GET /api/v1/stats` |  
 | Registry | Yes | HTTP `GET /` |  
 | RegistryCtl | Yes | HTTP `GET /api/health` |  
 | Chartmuseum | Yes | HTTP `GET /health` |  
 | Database | Yes | Run test SQL | Check status when using external database either 
 | Redis | Yes | Run simple query | Check status when using external Redis either 
 | Clair | Yes | HTTP `GET /health` |  
 | Notary Server | Yes | HTTP `GET /_notary_server/health` |  
 | Proxy | No | | 
 | Notary Signer | No | |  
 | Log collector | No | | 


The configurations(environment variables) needs to be added in `core`:

Name | Comment  
------------|------------
 | PORTAL_URL | The URL of portal  
 | REGISTRYCTL_URL | The URL of registryctl 
 | CLAIR_HEALTH_CHECK_SERVER_URL | The URL of clair health check server. As the health check server listens on a different port(default: 6061) with clair core server(default: 6060 ), we need another configuration to configure it
 
## Non-Goals
The `healthy` status returned by this API means that the processes of Harbor service are running well, but cannot guarantee every function works as expected.