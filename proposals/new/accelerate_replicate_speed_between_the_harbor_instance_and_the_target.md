Author: < ZHANGYI / markzhang >
Discussion:

## Abstract

This proposal will provide a solution to accelerate replicate speed between the source harbor instance and the target. For those who require the extremely strict time lag when using the policy based replication among different harbor/registry instance.

## Background
Harbor is famous for its `Policy Based Replication` function which really benefits for those users who want to build a multi-regional private image registry. While, the replicates process among different registry instance is stable but time-consuming.

The job of replication service is triggered by notification of image pushed success, schedulers job, or direct API.  Policy of replication job which based on the image tags  will pull the image manifest file and all of the blobs layer from source registry URL, and push them to the target URL one after another.

## Proposal
This proposal is aimed at adding a function of accelerating replication speed for user's choice.

The principle of replication acceleration is as follows:

1.  When one image is uploaded to the source harbor address, all requests will be forwarded through the proxy of the ui module.

2. In the forwarding logic of reverse proxy in ui module, by getting the response of HEAD request for each layer of blob returned, it is determined that the replication acceleration switch in the database is turned on.

3. When the response status code of HEAD request of each blob layer returns 200, a direct blobtransfer operation is performed.

4. Without making any intrusive changes to the original jobservice module, when replication task started, it was found that the specified overlapping layer already exists at the target address, and it will not be uploaded repeatedly.

## Implementation

1. When adding the replication accelerates option to the front-end module, we append the target destination address of the harbor and accelerate entry to the replication_target table of corresponding database.

2. When the response status code of HEAD request for each blob layer returns 200, the operation of blobs transfer to the target registry is performed in the reverse proxy logic of the ui module.

3. By using the worker pool goroutines in ui module, synchronize the image blob layer to the target registry address that enables replication acceleration concurrently.


