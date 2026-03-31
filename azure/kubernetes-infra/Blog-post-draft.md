# Tutorial: Building a Small Kubernetes Cluster on Azure VMs with Terraform

This article walks through the real work behind the `azure/kubernets-infra` project in this repository.

It is not a "copy these files blindly" guide. It is a tutorial-style walkthrough of:

- what you should know before attempting this project
- how the project fits into the Azure learning path in this repo
- what infrastructure was built
- why the network was designed the way it was
- how SSH access was modeled
- what lessons mattered while turning Terraform basics into a multi-node Kubernetes setup

The end goal is a small Kubernetes cluster on Azure VMs using:

- 1 control-plane node
- 2 worker nodes
- 1 shared resource group
- 1 shared virtual network
- 1 shared subnet
- 1 shared network security group
- 1 public IP on the control plane only
- private worker nodes

## Who Should Read This

This tutorial is for learners who:

- are comfortable with basic Linux and SSH
- want to learn Terraform on Azure by building something more realistic than a single VM
- want to understand the infrastructure behind a Kubernetes cluster on cloud VMs
- are willing to build the mental model first instead of just pasting Terraform

If you are brand new to Azure or Terraform, do not start here. Work through the earlier Azure stages in this repo first, then return to this project.

## Prerequisite Knowledge

The `kubernets-infra` project assumes that you already understand Azure and Terraform at a foundational level.

If you are a beginner, follow the stages in this repository in order before attempting this project.

### Stage 1: Learn the Azure mental model and your first VM stack

Start with:

- https://github.com/endiesworld/multicloud-kubernetes/tree/main/azure/stage-1
- https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/stage-1/azure-README.md
- https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/stage-1/README.md

These teach:

- Azure tenant, subscription, resource group, region, SKU, and provider concepts
- how Terraform talks to Azure
- how a VM stack is built from resource group, VNet, subnet, NIC, and VM
- how to authenticate locally with Azure CLI

Do this stage first if you still need clarity on:

- what a resource group is
- how Azure regions work
- why a VM needs a NIC and subnet
- how Terraform resource references work

### Stage 2: Learn Terraform variables

Then study:

- https://github.com/endiesworld/multicloud-kubernetes/tree/main/azure/stage-2
- https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/stage-2/README.md

This stage teaches:

- how to declare variables
- how to use `terraform.tfvars`
- how to separate Terraform logic from environment-specific values
- why hard-coded values become a problem quickly

That matters because the Kubernetes project is parameterized and depends on that habit.

### Stage 3: Learn locals, outputs, and modules

Then move to:

- https://github.com/endiesworld/multicloud-kubernetes/tree/main/azure/stage-3
- https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/stage-3/README.md

This stage teaches:

- how `locals` reduce repetition
- how `outputs` expose useful infrastructure values
- how Terraform modules work
- how a root module differs from a child module

This is the direct bridge into `kubernets-infra`, where you stop thinking in one VM and start thinking in a reusable cluster design.

## What This Project Builds

The current implementation in:

- https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/main.tf
- https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/variables.tf
- https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/outputs.tf

builds a small Azure VM-based Kubernetes environment with:

- one shared resource group
- one shared VNet
- one shared subnet
- one shared NSG
- one public IP for the control plane
- three NICs, one per node
- three Linux VMs created through a reusable `kubernetes-node` module

The design is intentionally opinionated:

- the control plane is the public admin entry point
- the workers stay private
- inter-node traffic stays on the VNet

That is a better beginner architecture than exposing every VM publicly.

## Step 1: Understand the Right Terraform Mental Model

Before looking at Kubernetes-specific concerns, the most important idea is this:

- a cluster is not "three copies of one VM"
- a cluster is "shared infrastructure plus repeated node resources"

In this project, the shared resources are:

- resource group
- VNet
- subnet
- NSG

The repeated node resources are:

- NIC
- VM
- public IP only where needed

That is the key Terraform design boundary for this tutorial.

## Step 2: Build the Shared Azure Network First

The root module in https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/main.tf creates the shared network foundation:

- `azurerm_resource_group`
- `azurerm_virtual_network`
- `azurerm_subnet`
- `azurerm_network_security_group`
- `azurerm_subnet_network_security_group_association`

This matters because Kubernetes nodes are not isolated machines. They are part of a distributed system that must communicate reliably over private networking.

That means:

- workers must reach the API server
- the control plane must reach kubelets
- pod networking must work across nodes

The VNet and subnet are therefore cluster infrastructure, not VM-specific details.

## Step 3: Create One NIC Per Node

Next, the project defines:

- one NIC for the control plane
- one NIC for worker 1
- one NIC for worker 2

This is the right model for Azure:

- one VM
- one primary NIC
- one private identity in the subnet

The control-plane NIC also gets a public IP attached. The worker NICs do not.

That gives you a deliberate access pattern:

- public administration path to the control plane
- private-only access path to workers

## Step 4: Restrict Public Access to the Control Plane

The current design attaches a public IP only to the control plane.

That does **not** mean all ports are open.

It means only this:

`Internet -> Public IP -> Control-plane NIC -> VM`

That path still depends on:

- NSG rules
- guest OS firewall rules
- whether the SSH service is listening

This distinction is one of the most important beginner lessons in the project.

For a more detailed explanation, see:

- https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/SSH-access-patterns.md
- https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/Network-primitives-reference.md

## Step 5: Allow Only the Traffic the Cluster Needs

The NSG rules in https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/main.tf include a baseline set for cluster operation:

- `22/TCP` for SSH administration
- `6443/TCP` for the Kubernetes API server
- `10250/TCP` for kubelet communication
- `2379-2380/TCP` for etcd
- `10257` and `10259` for control-plane components
- `10256/TCP` for kube-proxy
- `4240/TCP` and optionally `8472/UDP` for Cilium-related traffic

The important lesson here is not to memorize ports first.

Instead ask:

- who needs to talk to whom?
- over which path?
- should that traffic stay private?
- does this need to be internet-facing at all?

That is a better network-security mindset than opening ports first and reasoning later.

## Step 6: Expose Useful Outputs

As soon as the infrastructure became operational, Terraform outputs became necessary.

The project now exposes:

- `control_plane_public_ip`
- `control_plane_ssh_target`
- `worker_private_ips`

- https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/outputs.tf

They matter because after `terraform apply`, you immediately need operational values for:

- SSH access to the control plane
- identifying worker private IPs
- connecting through the jump-host pattern

This is where Stage 3 concepts become practical, not just theoretical.

## Step 7: Use the Control Plane as the Jump Host

Because the workers do not have public IPs, they are not directly reachable from the public internet.

That is intentional.

The admin path becomes:

`Laptop -> control-plane public IP -> control-plane VM -> worker private IP`

This is documented in:

- https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/Worker-access-via-control-plane.md

This is the operational model:

1. SSH from your laptop to the control plane.
2. SSH from the control plane to the worker private IP.

That keeps worker nodes private while still making them manageable.

## Step 8: Use SSH Agent Forwarding for the Second Hop

One of the most useful real-world lessons from this project came from an SSH failure.

At one point:

- laptop to control plane worked
- control plane could reach the worker private IP
- but SSH from control plane to worker failed with `Permission denied (publickey)`

That turned out not to be a network problem.

It was a key-forwarding problem.

The fix was:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/azure/kubernetes
ssh -A -i ~/.ssh/azure/kubernetes azureuser@<control-plane-public-ip>
ssh azureuser@<worker-private-ip>
```

The lesson is simple:

- network reachability and SSH authentication are separate concerns

This project forced that lesson in a practical way.

## Step 9: Bootstrap Kubernetes on the Control Plane

Once the Azure infrastructure and SSH model were correct, I was able to bootstrap the Kubernetes control plane.

The results showed:

- the control-plane node became `Ready`
- the API server, controller manager, scheduler, and etcd were running
- Cilium was running
- CoreDNS was running

That confirmed that:

- the control-plane VM was healthy
- the cluster bootstrap path worked
- the network design was viable enough for Kubernetes control-plane operation

## Step 10: Join the Workers Through Private Networking

The next phase is worker-node installation and `kubeadm join` over the private subnet.

Because the workers are reachable from the control plane by private IP, the intended path is:

- access control plane via public IP
- connect to workers via private IP
- install prerequisites on the workers
- run the join command from the workers

This is a much better beginner mental model than assigning public IPs to every node just because you need administrative access.

## The Biggest Lessons from the Project

### Lesson 1: A public IP is not the same thing as open access

A public IP only creates a possible public route.

You still need:

- NSG allow rules
- guest OS firewall allowance
- a listening service

### Lesson 2: An NSG allow rule is not the same thing as reachability

A worker can be allowed by policy and still not be publicly reachable.

Why:

- no public IP
- no public load balancer NAT
- no firewall DNAT
- no VPN path

This distinction is critical.

### Lesson 3: Keep the workers private

This project reinforced that the control plane should be the admin entry point and the workers should stay on private networking unless there is a strong reason to do otherwise.

### Lesson 4: Outputs are operational tools

Outputs are not just for demos. They become necessary once you need to actually use what Terraform built.

### Lesson 5: Terraform structure matters

The cluster became easier to reason about when the code followed the architecture:

- shared network resources in the root
- per-node resources in repeated patterns

That is the difference between Terraform that "works" and Terraform that teaches the right infrastructure model.

## What Beginners Should Do Next

If you finish the earlier stages and then work through this project, the next useful learning steps are:

1. Trace every resource in https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/main.tf and explain whether it is shared infrastructure or per-node infrastructure.
2. Use the outputs in https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/outputs.tf to practice reaching the control plane and then the workers.
3. Read https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/SSH-access-patterns.md until the difference between public path and allowed traffic feels obvious.
4. Read https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/Network-primitives-reference.md until you can clearly explain the roles of Public IP, NIC, NSG, and ASG.
5. Read https://github.com/endiesworld/multicloud-kubernetes/blob/main/azure/kubernets-infra/Worker-access-via-control-plane.md and practice the jump-host workflow.

## Final Advice

If you are learning from this repository, do not treat `kubernets-infra` as the beginning.

Treat it as the first project where the earlier Terraform and Azure concepts become a real system.

The right learning path is:

1. Azure mental model
2. Single VM stack
3. Variables
4. Locals, outputs, and modules
5. Shared network plus repeated nodes
6. Kubernetes bootstrap and private worker access

That sequence will teach you both the tooling and the architecture, which is the real goal of this project.

## Official References

These are the main external references that support the tools and concepts used throughout this project.

### Terraform

- Install Terraform:
  https://developer.hashicorp.com/terraform/install
- Terraform language documentation:
  https://developer.hashicorp.com/terraform/language
- AzureRM provider documentation:
  https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs

### Azure

- Install Azure CLI:
  https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
- Azure CLI documentation:
  https://learn.microsoft.com/en-us/cli/azure/
- What is a resource group:
  https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal
- Azure Virtual Network overview:
  https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-faq
- Azure network interfaces:
  https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-network-interface
- Configure IP addresses for an Azure NIC:
  https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/virtual-network-network-interface-addresses
- Azure NSG overview:
  https://learn.microsoft.com/en-us/azure/architecture/networking/guide/network-level-segmentation
- How NSGs filter traffic:
  https://learn.microsoft.com/en-us/azure/virtual-network/network-security-group-how-it-works
- Manage NSGs and application security groups:
  https://learn.microsoft.com/en-us/azure/virtual-network/manage-network-security-group
- Azure availability zones:
  https://learn.microsoft.com/en-us/azure/availability-zones/az-overview

### Kubernetes

- Install `kubeadm`:
  https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- Create a cluster with `kubeadm`:
  https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
- Install `kubectl` on Linux:
  https://kubernetes.io/docs/tasks/tools/install-kubectl-linux
- Container runtimes:
  https://kubernetes.io/docs/setup/production-environment/container-runtimes/
- Kubernetes ports and protocols:
  https://kubernetes.io/docs/reference/ports-and-protocols/

### Cilium

- Cilium quick installation:
  https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default.html
- Cilium installation for `kubeadm` clusters:
  https://docs.cilium.io/en/stable/installation/k8s-install-kubeadm.html
