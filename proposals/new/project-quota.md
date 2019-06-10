# Project Quota

Author: He Weiwei/Yan Wang

## Abstract

Harbor enforces quotas on resource usage of project, setting a hard limit on how much of a particular artifact count and storage your project can use.


## Background

Currently, users can push docker images, upload helm charts to harbor as many as possible without limit, the result is that one project will use up all resource of the system.

## User Stories

### Story 1
As a system administrator, I can set the default limit on project artifact count and project storage. But, I cannot control how many projects can Harbor have.

### Story 2
As a project administrator, I can only view basic quota information in project quota page, which includes quota usage, limits and errors. 

### Story 3
As a project administrator, I can exceed my project limit by sending the request to system admin and wait for response.

### Story 4
As a system administrator, I can enlarge the project quota per request, either on storage usage or artifact count.

### Story 5
As a system administrator, I can view all project quota metrics via a dashboard.

## Proposal

I propose the following solutions:

1. Add quota management page in administration so that system administrators can set storage and number quota for the project.
2. Add quota information page in the project to display the resources used by the project for project administrators.
3. Modify or hook the docker distribution proxy handler in core component, denied push when new pushed image over the storage and number quota.
4. After image uploaded or deleted, update the storage usage of the project, which will be used in step 4.
5. Modify or hook helm chart upload API, denied upload when new uploaded chart over the storage and number quota.
6. After helm chart uploaded or deleted, update the  storage usage of the project, which will be used in step 4.
7. Recalculate the storage usage by project whe upgrade from old version.


### Project Quota Setting

## API

 1. List quotas

    ```
    GET /api/quotas
    [
    	{
    		"id": 1,
    		"project": {
    			...
    		},
    		"storage_quota": 1048576,
    		"number_quota": 100,
    		"storage_usage": 524288,
    		"number_usage": 50,
    		"image_storage_usage": 524000,
    		"image_number_usage": 40,
    		"chart_storage_usage": 288,
    		"chart_number_usage": 10
    	}
    ]
    ```

 2. Update quota

    ```
    POST /api/quotas/:id
    {
    	"storage_quota": 2097152,
    	"number_quota": 120
    }
    ```
    
 3. Read quota for the project

    ```
    GET /api/projects/:pid/quota
    {
      "id": 1,
      "project": {
      	...
      },
      "storage_quota": 1048576,
      "number_quota": 100,
      "storage_usage": 524288,
      "number_usage": 50,
      "image_storage_usage": 524000,
      "image_number_usage": 40,
      "chart_storage_usage": 288,
      "chart_number_usage": 10
    }
    ```

## DB scheme

```
CREATE TABLE quota (
 id SERIAL PRIMARY KEY NOT NULL,
 project_id INTEGER NOT NULL,
 storage_quota BIGINT,
 number_quota BIGINT,
 image_storage_usage BIGINT,
 image_number_usage BIGINT,
 chart_storage_usage BIGINT,
 chart_number_usage BIGINT,
 UNIQUE(project_id)
)
```

### Solution on Registry

## DB scheme

Table -- Blob

```
CREATE TABLE Blob (
 id SERIAL PRIMARY KEY NOT NULL,
 /* 
    digest of config, layer, manifest
 */ 
 digest varchar(255) NOT NULL,
 size int NOT NULL,
 UNIQUE (digest)
);
```

Table -- Image

```
CREATE TABLE Image (
 id SERIAL PRIMARY KEY NOT NULL,
 repo varchar(255) NOT NULL,
 tag varchar(255) NOT NULL,
 /* 
    digest of mainfest
 */
 digest varchar(255) NOT NULL,
 CONSTRAINT unique_image UNIQUE (repo, tag)
);
```

Table -- Manifest

```
CREATE TABLE Manifest (
 id SERIAL PRIMARY KEY NOT NULL,
 digest varchar(255) NOT NULL,
 digest_blob varchar(255) NOT NULL
);
```

Table -- Project Quota Usage

```
CREATE TABLE Project_Quota_Usage (
 id SERIAL PRIMARY KEY NOT NULL,
 project_name varchar (255) NOT NULL, 
 digest_blob varchar(255) NOT NULL,
 reference_count int NOT NULL,
 size_blob int NOT NULL,
 CONSTRAINT unique_quota UNIQUE (project_name, digest_blob)
);
```

## Data Flow in Docker registry

The date flow to push a image into Harbor:

   ![Docker Push flow](../images/project-quota/data_flow_registry.png)
    

## API
 1. Registry Dump (Sysadmin only)

    ```
    POST /api/internal/dumpregistry
    ```

## Consideration of performance
1, Docker push.
> Redirect the HEAD request to DB before pushing a blob.

2, Registry Client in Core.
> Replace the API by calling DB, like get manifest, layer digest, image size.
    
## Non-Goals

# Docker images
Don't split the shared image layer size into pieces, each shared layer will count its size into the total size of a project.
It causes the total usage of a Harbor instance is not reflect true value.

## Compatibility
It has to consider how to handle the migration from older version, like v1.7.0.