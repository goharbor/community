# Harbor Community Proposal - We should build all Harbor Images based Scratch

Status: In Progress
Created by: Vadim Bauer
Created time: February 07, 2024 1:17 PM
Last Edited: February 07, 2024 1:52 PM

# **Proposal: Scratch Images**

# **Abstract**


https://hub.docker.com/_/scratch/

This proposal advocates switching to use Scratch images for Harbor. 
This approach reduces container size, enhances security, and optimizes resource utilization. 
It streamlines the deployment process, reducing image footprint and accelerating application startup. 
Utilizing Scratch images leads to a more agile development cycle and improved scalability. 

Using Scratch images aligns with Golang's philosophy of simplicity and performance, 
creating a streamlined and resource-efficient containerized environment for Golang applications.

# **Background**

Today Harbor is using PhotonOS base images. On top of the base image that already 
comes with many unnecessary dependencies, we are installing addition tools that 
increase the potential attack surface even further.

The consequence is that the project received regular vulnerability reports that 
primary affect those dependencies. 
Most of the older images don't receive vulnerability patches.

PhotonOS base image patching can be also delayed by weeks and months, making the process unnecessary slow.   

# **Proposal**
The proposal is replacing as many base images with scratch as possible.
Images where it would make sense can be migrated to distroless, or remain Photon based. 


# **Benefits for Harbor and the Ecosystem**

* Reduced Image sizes result in faster turnaround time while developing and distributing software. 
* Good for the environment; as less power, storge is used in transfer and storage
* Attack surface of the core applications is drastically reduced. 
* Less maintenance and patching
* Faster build for local development
* Easier to support Arm or any other infrastructure  


# **Non-Goals**

Replace all images with distroless or scratch. While this would be definitely a 
great achievement the easier part would be to replace what is currently possible. 


## Rationale

Scratch is the most stripped down version of a Docker container. 
Scratch contains nothing in it except for the executable binary which you add to it. 
It has no shell, nothing extra.

An Alternative To Scratch
A distroless image is not a single image to solve the problem, like scratch is. 
Instead, distroless images are a class of minimal images which contain only your 
application and the application’s runtime dependencies.

The static distroless image, gcr.io/distroless/static, is the simplest of all the distroless images. 
It contains a minimal Linux, glibc-based system with:

📝 ca-certificates
🔒 A /etc/passwd entry for a root user
🗑️ A /tmp directory
⌚ tzdata

Currently there are two major distroless streams google and Wolfi. 
The second one has a commercial purpose only, and can't be used in the Open Source Context


[A discussion of alternate approaches and the trade offs, advantages, and disadvantages of the specified approach.]

## Compatibility

Downsides of Scratch, is that they only work for compiled languages, and debugging
only works with a debug container or pod.
There are already many elaborated solutions for [debugging container in Docker](https://docs.docker.com/engine/reference/commandline/debug/) and [Kubernetes](https://kubernetes.io/docs/tasks/debug/debug-cluster/kubectl-node-debug/)   


## Implementation

In the first phase, we would focus on the migration of the core application like 
core, registry, exporter, jobservice, registryctl, trivy-adapter 

## Open issues (if applicable)

As mentioned, the only open issue if scratch can be used only applies to: 

* Nginx (portal)
* Postgres (db)
* Redis (cache)

In the given cases we can evaluate and test if 
