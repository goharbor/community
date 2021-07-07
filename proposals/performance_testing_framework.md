# Proposal: `Harbor Performance testing framework`

Author: ChenYu Zhang / [chlins](https://github.com/chlins)

Discussion:

- [Performanace Workgroup Meeting Notes](https://docs.google.com/document/d/1GH_XkhpbnFtXJp82IZduyVGPg2R0U3bSgBEqZ2WkxRs/edit?usp=sharing)

## Abstract

Provides a unified and easy-to-use harbor performance testing framework, which can run through simple configurations and generate testing reports automaticly after running.

## Backgroud

As enterprise artifacts become more and more numerous, the performance of some of harbor's api's is currently unable to meet the existing business scenarios, we need to provide official performance test reports as a reference, and based on the existing test results to set our expectations to achieve the goal.

why we need a new testing framework?

- There are too many other testing tools, the results will be biased.
- There are usage costs and users need to know the api details of harbor.
- We expect to generate test reports by running them with simple way and get the unified report format.

## Proposal

Use [perf](https://github.com/goharbor/perf) as testing repository to maintain performance testing related tools and cases.

### Goal

**Short-term**: Testing selective api for synchronization scenarios.

**Long-term**: Testing more api in asynchronous scenarios(Replication/Scan/Webhook/GC/Retention).

We want to collect below performance testing metrics.

- The current size of the user's data.
- Current number of concurrent requests.
- Average response time.
- Minimum response time.
- Medium response time.
- Max response time.
- 90% requests response time.
- 95% requests response time.
- Response success rate.

Hardware metrics will be considered in the future.

- cpu
- memory
- disk IO

### Testing Tool

Selection: [xk6-harbor](https://github.com/heww/xk6-harbor), a tool based on [k6](https://github.com/k6io/k6)(A modern load testing tool) and [goswagger](https://github.com/go-swagger/go-swagger) to generate harbor client.

The xk6-harbor tool will still maintain under this [xk6-harbor](https://github.com/heww/xk6-harbor), but testing cases will be maintained under [perf](https://github.com/goharbor/perf) repository.

### Testing Cases

We will provide two commands to initialize harbor and testing harbor.

- initialize harbor: mocking some data for harbor testing (can be configurated to differnet data size).

- testing harbor: use `xk6-harbor`execute testing cases and finally generate union results(json/yaml/csv).

### Testing reports

The testing results data is unified with same format, we provie default scripts for rendering testing reports, but you are also welcome to contribute scripts for reports with beautiful ui.

Below is default testing report format.

| API | Description  | User Data Size | Concurrent | Avg | Min | Med | Max | P(90) | P(95) | Success Rate |
|-----|--------------|----------------|------------|-----|-----|-----|-----|-------|-------|--------------|
| GET /api/v2.0/projects | List Projects | | | | | | | | | |
| GET /api/v2.0/projects/{project_name}/ repositories | List repositories of project | | | | | | | | | |
| GET /api/v2.0/projects/{project_name}/repositories/{repository_name}/artifacts | List artifacts of repository | | | | | | | | | |
| GET /api/v2.0/projects/{project_name}/repositories/{repository_name}/artifacts/{reference}/tags | List tags of artifact | | | | | | | | | |
| GET /api/v2.0/projects/{project_id}/members | List members of project | | | | | | | | | |
| GET /api/v2.0/projects/{project_name}/logs | List logs of project | | | | | | | | | |
| GET /api/v2.0/audit-logs | List audit logs | | | | | | | | | |
| GET /api/v2.0/quotas | List quotas | | | | | | | | | |
| GET /api/v2.0/users | List users | | | | | | | | | |
| GET /api/v2.0/users/search | Search users | | | | | | | | | |
| GET /v2/_catalog | Get Catalog | | | | | | | | | |
