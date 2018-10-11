# Proposal: `Integration with dragonfly`

Author: `Steven Zou` / [Steven Zou](https://github.com/steven-zou)

Discussion:

* [#5308](https://github.com/goharbor/harbor/issues/5308)
* [alibaba/Dragonfly#108](https://github.com/alibaba/Dragonfly/issues/108)

## Abstract

Integrate trusted cloud-native registry Harbor with Dragonfly to provide a joint image management and distribution solution to support containerized environments.

## Background

**Harbor:**  Project Harbor is an open source trusted cloud-native registry project that stores, signs, and scans content. Harbor extends the open source Docker Distribution by adding the functionalities usually required by users such as security, identity, and management. Having a registry closer to the build and run environment can improve the image transfer efficiency. Harbor supports replication of images between registries and also offers advanced security features such as user management, access control, and activity auditing. For more details, please refer to [README](https://github.com/vmware/harbor/blob/master/README.md).

**Dragonfly:** Dragonfly is an intelligent P2P based file distribution system. It aims to resolve issues related to low-efficiency, low-success rate and a waste of network bandwidth in file transferring process. Especially in large-scale file distribution scenarios such as application distribution, cache distribution, log distribution, **image distribution**, etc. For more details, please refer to [README](https://github.com/alibaba/Dragonfly/blob/master/README.md)

With the emergence and development of Kubernetes, it's becoming possible to run and operate large-scale containerized applications and services in enterprise environments. Meanwhile, there are still existing big challenges which cannot be ignored. How to securely and effectively manage the lots of container images produced in the enterprise organizations and distribute them to the large-scale runtimes with less time and efforts when starting applications or services on demand. To address the above challenge, we should build a joint solution from the open source trust cloud-native registry **Harbor** and the open source intelligent P2P based file distribution system **Dragonfly**. 

**These two open sourced projects have very obviously complementary advantages to each other and the joint solution will definitely expand the scenarios of image lifecycle management and improve the securities, reliabilities, and efficiencies.**

## Proposal

### Overview

* The integration should be a **loose couple** way, by calling related APIs to complete the required work. The system admin of Harbor registry can configure the related options to enable the API calling from Dragonfly side. The options may include but not limit the following ones:

  * API endpoint
  * API access token or required credentials
  * Possible calling policies or automation rules etc.

* The integrated configurations can be verified to make sure the connection between the two systems is not broken by testing or ''dry run" etc.

* The images are produced by CI/CD pipeline or any other ways and pushed to the Harbor registry. The newly pushed images can be marked with labels automatically or manually. In addition, the admin of the registry can also scan the images to make sure it's secure. Of course, the admins can do any other management work if they want.

* The admin of the registry can select any ready image to **promote** it to the supervise node of Dragonfly P2P network for the upcoming image pulling requests to improve the distribution performance. The **promote** action can be triggered by clicking button or auto-triggered by pre-configured rules/policies (_If match some conditions, then promote it_).

* Then if the containerized environments need to pull that image, the Dragonfly will help to distribute it to the nodes by layers via the P2P network.

### Basic Workflow

![harbor dragonfly](https://user-images.githubusercontent.com/5753287/42671176-576f857a-8691-11e8-802e-7f39e836cffa.png)

### Architecture

An architecture design based on the above draft idea:
![dragonfly h](https://user-images.githubusercontent.com/5753287/43447108-4ba61ac4-94dd-11e8-9072-0c143b58e70d.png)

The components with light blue background are the new things need to be implemented.

* The controller provides related API methods to handle the overall workflow
* The config will handle loading and saving of the related configurations based on the existing Harbor configuration service
* The policy engine handles the CRUD of policy as well as the evaluation of the policies
* Hook controller is designed to take charge of event hook related things
* Image distribution driver will define as an interface to provide the related methods to talk to the Dragonfly API
* API from Dragonfly side provides the required capabilities of publishing images to the supervise node and returning necessary status info and/or metrics if required

## Non-Goals

N/A.

## Rationale

None.

## Compatibility

The 1st version (prototype) may be built based on 1.6 code base, there might be some compatibilities with new code base (`rebase` required).

## Implementation

A prototype version is under development to verify the integration idea. This proposal targets a formal integration between Harbor and Dragonfly.

**Todo List of Dragonfly:**

* By Alibaba team
* [ ] 08.15 the specification of API between Dragonfly and Harbor is completed
  * check verify the connection between Dragonfly and Harbor
  * heat send a image preheating task to Dragonfly
  * query view the status of the preheating task
* [ ] 09.07 dfdaemon supports to download private container image
* [ ] 10.12 the API of dragonfly controller and heater module are completed
* [ ] 10.31 integrating demo between Dragonfly and Harbor is completed

**TODO list of Harbor:**

* By Steven Z
* [ ] User can configure Dragonfly service endpoint from the web portal - **09/31**
  * Depend on Dragonfly related API

* [ ] User can `pre-release` or `promote` the specified image to the Dragonfly supervise node - **10/31**

* [ ] Extended: User can setup a automation policy to `pre-release` or `promote` the matched images to the Dragonfly supervise node - **11/14**
