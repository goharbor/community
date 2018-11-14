Proposal: Harbor support images replication to public cloud registry 
Author: Lei Yuan
 ## Abstract
In hybrid cloud scenario, we may need to replicate harbor images to public cloud. However it is impossible to replicate harbor images to a different kind of registy. It will be great, if harbor can replicate images to public cloud directly. 
 ## Solution
Harbor should provide more flexsible structure and configuration for user to customize the replication process. At the same time, harbor should support both "push base replication" and "pull base replication" to adpat more complex network environment in hybrid cloud scenario.

 ## Proposal 
1,When harbor user submit a replicate rule, it should be able to input a project as destination, for public cloud registry need to keep project structure unique.
2,Harbor should expose image replication handler, for public cloud user to register their replication related interface at the replication prepare stage.
3,Harbor better provide options for user to bypass project management when replicate.
4,At the connetction testing point,using GET instead of HEAD as the /v2 api portocal. 
5,Harbor should provide "pull base replication" from public cloud to harbor. Harbor should also be able to receive image replicate requests by two different way -- polling and webhook.
