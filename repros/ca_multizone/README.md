# Cluster-autoscaler working nodepool with multiple zones

All following scenario requires to clone this repository and run `provision.sh`
first. See access-instructions.md after compleing `provision.sh` on how to
have kubectl access to the created cluster.

For each of the test scenario, remove previous test deployments and wait for
sufficient time for cluster-autoscaler to recover.

Execute in VSCode in a bash terminal.

Tested May 2024

## Test Scenarios

### scenario 1: multizone nodepool, 1 starting node, scale up with zone of the existing node

On a new provisioned cluster, run [scenario1.sh](./scenario2.sh)

Result: Scale-up triggered several rounds. Each scale up created a node in different zone (observed in sequence: zone1, zone2, zone3, zone1 etc). Pod can only scheduled on node in zone1 (as per deployment spec), so only every third scale-up event would actual assist in placing pod onto the node. Pods are scheduled after 24 minutes. Noting that many more than necessary nodes were created (actually 10 nodes) and scattered across different zones.

Key Commands:
- kubectl get pods -o wide
- kubectl get deployments
- kubectl describe nodes | grep -e "Name:" -e "topology.kubernetes.io/zone"
- kubectl rollout status deployment/scenario1

Clean up: 
- kubectl delete deployment scenario1

### scenario 2: multizone nodepool, 1 starting node, scale up with zone of non-existing node

On a new provisioned cluster, run [scenario2.sh](./scenario2.sh).\
If running on the same cluster as scenario 1, make sure to delete the deployment from scenario 1 first and wait approx. 30 minutes for the scale down to complete.

Result: None of the pods get scheduled. Scale-up not triggered.

Clean up: 
- kubectl delete deployment scenario2

### scenario 3: multizone nodepool, 0 starting node, scale up with zone 1

On a new provisioned cluster, run [scenario3.sh](./scenario3.sh)\
If running on the same cluster as scenario 1, make sure to delete the deployment from scenario 1 first and wait approx. 30 minutes for the scale down to complete.

Result: Scale-up triggered several rounds. Each scale up created a node in different zone (observed in sequence: zone1, zone2, zone3, zone1, zone3, zone1, zone3, zone1 etc). Pod can only scheduled on node in zone1 (as per deployment spec), so only when scale-up event created a node in zone1 would actual assist in placing pod onto the node. Pods are scheduled after 30 minutes. Noting that many more than necessary nodes were created (actually 10 nodes) and scattered UNEVENLY across different zones.\

Interestingly, the deployment deletion left the nodes in zone1 to last.

Key Commands:
- kubectl get pods -o wide
- kubectl get deployments
- kubectl describe nodes | grep -e "Name:" -e "topology.kubernetes.io/zone"
- kubectl rollout status deployment/scenario3

Clean up: 
- kubectl delete deployment scenario3

### scenario 4: multizone nodepool, 0 starting node, scale up with zone=<region>-1__<region->2__<region>-3

On a new provisioned cluster, run [scenario4.sh](./scenario4.sh)

Result: **Scale-up triggered** once. None of the pods get scheduled.

Key Commands:
- kubectl get pods -o wide
- kubectl get deployments
- kubectl describe nodes | grep -e "Name:" -e "topology.kubernetes.io/zone"
- kubectl rollout status deployment/scenario4

Clean up: 
- kubectl delete deployment scenario4

### scenario 5: singlezone nodepool (zone 1), 0 starting node, scale up with zone 1

On a new provisioned cluster, run [scenario5.sh](./scenario5.sh)

Result: Scale up triggered, all of the pods get scheduled within 10 minutes.

## What Happened?

> Why are there more than necessary nodes scheduled in scenario 1?

When a multi-zone nodepool is configured in AKS, scale-up is done by scaling up
the underlying VMSS. Since the nodepool is configured with multiple zones, the
setting is directly set in the VMSS. Cluster-autoscaler scales up the VMSS
directly, and **VMSS zone balancing logic dictates zone of the new node**, not
the nodeSelector in the deployment yaml.

> Why doesn't scale up happen in scenario 2?

When node exists in a nodePool, one of the nodes will be taken as the node
template for scale-up simulation. All labels of the node will be honored,
including the zone labels. In scenario 2, although it is possible for our
nodepool to provision nodes in all 3 zones, the predicted node outcome is fixed
on the existing node. Hence cluster-autoscaler predicates it is a label
mismatch.

> How come scenario 5 works, but scenario 3 doesn't? And what happened with
> scenario 4?

Scaling up from 0 nodes is different from scaling up from 1 or more nodes
since different templates are used, because the cluster-autoscaler uses a
MixedTemplateNodeInfoProvider to provide node "template" to be used in
simulation. The simulation leverages real kube-scheduler logic and test whether
the nodepools the "templates" represents are good candidates for the scale up
by seeing whether scheduler can schedule on those nodes.

When the nodePool has existing nodes, as explained before, the templates takes
[one of the existing nodes](https://github.com/kubernetes/autoscaler/blob/a2f890247b01a7dd621f3c86642d4e1cfe4d4f40/cluster-autoscaler/processors/nodeinfosprovider/mixed_nodeinfos_processor.go#L125).
When scaling up from 0 nodes,
[the cloud provider is consulted](https://github.com/kubernetes/autoscaler/blob/a2f890247b01a7dd621f3c86642d4e1cfe4d4f40/cluster-autoscaler/processors/nodeinfosprovider/mixed_nodeinfos_processor.go#L155)
to generate a template.

For Azure, see [here](https://github.com/kubernetes/autoscaler/blob/a2f890247b01a7dd621f3c86642d4e1cfe4d4f40/cluster-autoscaler/cloudprovider/azure/azure_template.go#L65)
on how zones are joined together in the template, which causes strange behavior
in scenario 3 and scenario 4, but works fine for scenario 5. 
