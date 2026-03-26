# Beginner's Guide to Building a Kubernetes Cluster on Azure VMs with Terraform

This article teaches a beginner how to think about, design, provision, and operate a small Kubernetes cluster on Azure virtual machines using Terraform.

The goal is not just to help you "get something working." The goal is to help you understand:

- what you are building
- why the architecture is designed that way
- how Azure networking and Kubernetes networking relate to each other
- how Terraform should model a cluster correctly
- how to move from beginner understanding to production-minded thinking

This guide is intentionally opinionated. A beginner learns faster from one strong baseline design than from a long list of equally presented options.

---

## Who This Guide Is For

This guide is for you if:

- you have created at least one VM before
- you understand basic Linux commands
- you are new to Kubernetes clusters on cloud VMs
- you want to understand the design, not just copy commands
- you want to use Terraform as infrastructure as code

This guide is **not** primarily for:

- managed Kubernetes services like AKS
- laptop-only clusters like Kind or Minikube
- highly available multi-control-plane production clusters

Those are valid topics, but they are not the best starting point for this learning path.

---

## What You Will Build

In this guide, you will build a small Kubernetes cluster on Azure with:

- 1 control-plane node
- 2 worker nodes
- 1 shared resource group
- 1 shared virtual network
- 1 shared subnet
- 1 shared network security group
- Terraform-managed Azure infrastructure
- `kubeadm` for cluster bootstrapping
- `containerd` as the container runtime
- Cilium as the CNI

This is the recommended beginner architecture for this project because it is:

- simple enough to understand
- realistic enough to teach the right concepts
- secure enough to avoid bad habits
- flexible enough to grow into more advanced designs later

---

## What You Should Understand by the End

By the end of this guide, you should understand:

- why a Kubernetes cluster should use shared private networking
- why a cluster is not just "three separate VMs"
- how Azure VNets, subnets, NICs, NSGs, and public IPs fit together
- which traffic paths are required for a small Kubernetes cluster
- how Terraform should separate shared infrastructure from repeated node infrastructure
- how CNI choice affects networking behavior
- how to validate that the cluster really works
- how to think about hardening and next-stage improvements

---

## The Core Design Principle

The most important idea in this guide is this:

> A Kubernetes cluster is a distributed system, not a collection of isolated machines.

That means the machines must be able to communicate with each other reliably and predictably.

If you already know how to create one VM with SSH access, that is a useful starting point, but it is not yet a cluster design.

To build a cluster, you must shift from:

- "How do I make a VM reachable from my laptop?"

to:

- "How do these machines communicate privately, securely, and predictably as one system?"

That mindset shift is the bridge from single-server infrastructure to cluster infrastructure.

---

## Why This Guide Uses One Opinionated Baseline

There are many ways to run Kubernetes:

- `kubeadm`
- `k3s`
- managed services like AKS
- local learning tools like Kind and Minikube
- different CNIs such as Calico, Flannel, and Cilium

But a beginner should not start by trying to compare everything at once.

This guide chooses one baseline path:

- **Bootstrap method**: `kubeadm`
- **Runtime**: `containerd`
- **Cluster shape**: 1 control plane + 2 workers
- **Network shape**: 1 shared VNet + 1 shared subnet
- **CNI**: Cilium

Why `kubeadm`?

Because `kubeadm` is designed to bootstrap a minimum viable Kubernetes cluster. It does **not** provision the machines for you. That is important, because it makes the division of responsibilities clear:

- Terraform provisions the Azure infrastructure
- `kubeadm` bootstraps Kubernetes on the nodes

That separation teaches the right mental model. Source: Kubernetes documentation on `kubeadm`:
https://kubernetes.io/docs/reference/setup-tools/kubeadm/

---

## The Target Architecture

For this guide, the target architecture is:

- `cp-1`: control-plane VM
- `worker-1`: worker VM
- `worker-2`: worker VM
- all three VMs inside the same Azure VNet
- all three VMs inside the same subnet
- one NSG applied consistently to control traffic
- a public IP on the control plane only
- no public IPs on worker nodes
- node-to-node traffic over private IPs

This architecture is recommended for beginners because it is easier to reason about:

- all nodes live in one private network boundary
- inter-node communication stays private
- SSH exposure is minimized
- the design resembles real-world cluster thinking
- troubleshooting is much simpler

---

## Visual Mental Model

Think about the environment like this:

```text
Azure Subscription
└── Resource Group
    ├── Virtual Network (VNet)
    │   └── Subnet
    │       ├── cp-1 NIC -> cp-1 VM
    │       ├── worker-1 NIC -> worker-1 VM
    │       └── worker-2 NIC -> worker-2 VM
    ├── Network Security Group
    └── Public IP
        └── attached only to cp-1
```

And then think about the Kubernetes layer on top:

```text
Kubernetes Cluster
├── Control Plane
│   ├── API server
│   ├── scheduler
│   ├── controller manager
│   └── etcd
└── Worker Nodes
    ├── kubelet
    ├── container runtime
    └── application workloads
```

Azure gives you the machines and the private network.
Kubernetes turns those machines into a cluster.

---

## Azure Concepts You Must Understand First

Before writing Terraform, make sure these Azure concepts are clear.

### Resource Group

A resource group is the logical Azure container for everything related to this cluster.

For a beginner project, putting the full cluster infrastructure into one resource group keeps the environment easy to manage, observe, and destroy.

### Virtual Network (VNet)

The VNet is the cluster's private network boundary in Azure.

All three nodes should live inside the same VNet so they can communicate privately.

### Subnet

A subnet is a smaller IP range inside the VNet.

For a first cluster, one subnet is enough. That keeps the networking model easy to reason about.

### Network Interface (NIC)

Each VM needs a NIC. The NIC is what attaches the VM to the subnet and gives it a private IP address.

### Network Security Group (NSG)

The NSG is your traffic filter. It decides which inbound and outbound traffic is allowed or denied.

For this guide, the simplest model is:

- one shared NSG
- attached at the subnet

That gives you one central place to reason about cluster traffic.

### Public IP

A public IP gives internet-facing access.

For this beginner cluster, only the control-plane node needs a public IP, and even that is mainly for learning convenience so you can SSH in and use `kubectl` easily.

Workers should remain private.

---

## Kubernetes Concepts You Must Understand First

Now separate the Azure layer from the Kubernetes layer.

### Control Plane

The control plane manages the cluster. In a small `kubeadm` cluster, the control-plane node usually runs:

- kube-apiserver
- kube-scheduler
- kube-controller-manager
- etcd

### Worker Nodes

Worker nodes run workloads. They host pods and communicate with the control plane to receive instructions.

### kubelet

The kubelet runs on every node. It is the local node agent that helps Kubernetes manage the machine.

### API Server

The API server is the main control-plane endpoint. It is how `kubectl`, workers, and cluster components talk to Kubernetes.

### etcd

`etcd` stores the cluster's state. In a small starter cluster, it is commonly colocated with the control plane.

### CNI

The CNI provides pod networking. It is what makes pods on different nodes communicate as one networked system.

In this guide, that CNI is Cilium.

---

## Why Shared Networking Matters

If you only know how to provision one VM, the natural beginner instinct is often:

- create VM 1
- create VM 2
- create VM 3

But that mindset often leads to the wrong Terraform structure:

- each VM with its own resource group
- each VM with its own VNet
- each VM with its own subnet
- each VM with its own NSG

That is the wrong abstraction for a Kubernetes cluster.

A cluster needs:

- shared network foundations
- repeated node resources attached to those shared foundations

So the better mental model is:

- create the shared network once
- plug the three nodes into it

That is how you should think both architecturally and in Terraform.

---

## Think in Communication Flows Before Ports

Beginners often ask:

- what ports do I need to open?

That is a reasonable question, but the better question is:

- who needs to talk to whom?

Start with communication flows.

### Flow 1: You manage the control plane

You need to:

- SSH into the control-plane node
- possibly run `kubectl` against the control plane from your machine

### Flow 2: Workers must join and talk to the API server

Workers need to reach the control plane so they can join the cluster and continue normal operation.

### Flow 3: Control plane manages the nodes

The control plane needs to communicate with node-level components such as the kubelet.

### Flow 4: Nodes and pods communicate internally

Cluster-internal communication should stay on private IPs inside the VNet and subnet.

### Flow 5: Applications may be exposed later

This is optional and should not be confused with the baseline cluster communication required just to make Kubernetes work.

Once you understand those flows, the firewall rules make sense.

---

## The Core Kubernetes Ports You Should Know

The official Kubernetes ports and protocols reference identifies the main component ports. Source:
https://kubernetes.io/docs/reference/networking/ports-and-protocols/

For a small cluster, the most important ones are:

- `6443/TCP`
  Kubernetes API server
- `2379-2380/TCP`
  etcd client/server API
- `10250/TCP`
  Kubelet API
- `10257/TCP`
  kube-controller-manager
- `10259/TCP`
  kube-scheduler
- `10256/TCP`
  kube-proxy

For a beginner, you do not need to memorize all of them equally.

The high-value ones are:

- `22/TCP` for SSH
- `6443/TCP` for the API server
- `10250/TCP` for kubelet communication
- `2379-2380/TCP` if your control plane runs stacked etcd

NodePort ranges and other application-facing traffic are optional and should be introduced later.

---

## Azure NSGs: The Important Beginner Insight

Azure NSGs have default security rules, including rules that allow traffic within the `VirtualNetwork` service tag.

That matters because it means:

- if all your nodes live in the same VNet
- if they live in the same subnet
- and if you have not overridden that behavior with more restrictive rules

then much of the private node-to-node traffic may already be allowed.

This is a crucial beginner insight.

You usually do **not** need to begin by opening every Kubernetes-related port to the internet.

Instead:

- keep node-to-node traffic private
- allow administration traffic intentionally
- add explicit public exposure only where necessary

Source:
https://learn.microsoft.com/en-us/azure/architecture/networking/guide/network-level-segmentation

---

## A Beginner-Safe NSG Strategy

For a first cluster, keep the explicit rules small and intentional.

### Required for Administration

- allow `22/TCP` from your public IP to the control plane
- optionally allow `22/TCP` to worker nodes only if you truly need direct SSH

Better long-term practice:

- SSH to control plane only
- reach workers through the control plane or a bastion later

### Required for Cluster Operation

- allow `6443/TCP` to the control plane from:
  - your public IP
  - the VNet or subnet
- allow `10250/TCP` for internal node management paths as needed
- allow `2379-2380/TCP` for local/cluster etcd communication when using stacked etcd

### Optional and Deferred

- NodePort ranges
- ingress-controller traffic
- application load balancer traffic

These should not be part of the minimum viable cluster firewall discussion.

---

## Where Cilium Fits In

This guide uses Cilium as the CNI.

That means:

- Kubernetes provides the control-plane and node orchestration
- Cilium provides pod networking and related network behavior

The important beginner takeaway is:

- the Azure architecture stays the same
- the CNI affects internal cluster networking behavior
- some firewall considerations become CNI-specific

Cilium's documentation includes a `kubeadm` installation path and a system requirements section, including firewall rules that matter in stricter environments. Sources:

- `kubeadm` installation with Cilium:
  https://docs.cilium.io/en/stable/installation/k8s-install-kubeadm.html
- Cilium system requirements:
  https://docs.cilium.io/en/stable/operations/system_requirements.html

For example, Cilium documents additional traffic such as:

- `8472/UDP` for VXLAN overlay networking
- `4240/TCP` for `cilium-health`

That does **not** mean you should blindly expose these ports to the internet.

It means:

- if you move to stricter explicit node-to-node firewall rules
- or if you stop relying on Azure's broader internal VNet allowances

then you must account for the CNI's internal communication requirements too.

So the right mental model is:

- Kubernetes component ports are not the whole story
- your chosen CNI also has networking implications

---

## Why This Guide Uses `kubeadm` + `containerd`

According to Kubernetes documentation, `kubeadm` bootstraps the cluster but does not provision the machines. That is exactly what you want for this project, because Terraform should own provisioning while `kubeadm` owns cluster bootstrap.

The official kubeadm installation guide also highlights important prerequisites:

- compatible Linux hosts
- full network connectivity between machines
- unique hostname, MAC address, and product UUID per node
- certain ports open
- enough CPU and memory

Source:
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

That makes `kubeadm` a strong teaching choice because it keeps the responsibilities clean:

- Terraform provisions Azure resources
- OS preparation configures the Linux nodes
- `kubeadm` initializes and joins the cluster
- Cilium provides pod networking

---

## The Terraform Mental Model You Should Learn

Before writing Terraform, understand this boundary clearly.

### Resources Created Once

These are shared cluster foundations:

- resource group
- VNet
- subnet
- shared NSG

### Resources Created Per Node

These belong to individual machines:

- NIC
- VM
- public IP, when needed

This is the correct Terraform cluster model.

If you instead write a module that creates:

- resource group
- VNet
- subnet
- NSG
- VM

all in one block and call it repeatedly, you are still thinking like a single-VM author, not like a cluster designer.

That structure can work for isolated VMs, but it is the wrong abstraction for a Kubernetes cluster.

---

## A Recommended Terraform Layout

A clean beginner-to-intermediate Terraform layout for this project would look like this:

```text
azure/kubernets-infra/
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── modules/
    └── kubernetes-node/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

The root module should own:

- resource group
- VNet
- subnet
- subnet NSG

The child node module should own:

- NIC
- VM
- optional public IP

The root module then instantiates the node module three times:

- `cp-1`
- `worker-1`
- `worker-2`

This teaches a foundational Terraform principle:

- create shared resources once
- repeat only what is truly repeated

---

## The Learning Path: From Beginner to Expert

Do not try to learn everything in one jump.

Use this staged progression.

### Stage 1: Understand One VM

Learn:

- how a VM is created
- how a NIC works
- how a subnet assigns private IPs
- how SSH access is controlled

You already have the beginning of this stage.

### Stage 2: Understand Shared Cluster Networking

Learn:

- why the three nodes should share a VNet
- why they should usually share a subnet initially
- why internal traffic should use private IPs
- why worker nodes do not need public IPs

This is the stage where you stop thinking "three separate servers" and start thinking "one cluster network."

### Stage 3: Understand Cluster Communication

Learn:

- worker-to-control-plane traffic
- control-plane-to-worker traffic
- internal node and pod communication
- CNI-specific networking needs

This stage is where port tables start making sense.

### Stage 4: Model the Cluster Properly in Terraform

Learn:

- which resources are shared
- which resources are repeated
- how modules should map to the architecture

This is where many learners become intermediate Terraform users.

### Stage 5: Bootstrap Kubernetes

Learn:

- how to prepare the Linux hosts
- how to initialize the control plane
- how to join worker nodes
- how to confirm the nodes register correctly

### Stage 6: Install Cilium

Learn:

- what the CNI does
- why Kubernetes needs it
- how to validate pod networking

### Stage 7: Validate and Harden

Learn:

- how to confirm nodes and pods communicate correctly
- how to reduce unnecessary exposure
- how to narrow rules over time
- how to improve the architecture without losing clarity

That is how you move from beginner to expert: one conceptual layer at a time.

---

## A Practical Baseline Security Posture

A beginner guide should teach secure habits early without becoming overly complex.

For this project, that means:

- control plane may have a public IP for learning convenience
- workers should remain private
- SSH should be limited to your public IP
- API server exposure should be intentional
- node-to-node traffic should remain private inside the VNet
- public application exposure should be delayed until after the cluster works

This is a strong beginner baseline because it teaches:

- the difference between management access and cluster traffic
- the value of private internal communication
- the habit of reducing exposed surfaces

---

## Common Beginner Mistakes

If you are learning this for the first time, these are the mistakes to watch for.

### Mistake 1: Giving Every Node a Public IP

This makes the cluster easier to reach, but it also encourages the wrong mental model and increases exposed surface area.

### Mistake 2: Using Public IPs for Internal Cluster Communication

Cluster traffic should use private IPs. Public IPs are for external access, not for node-to-node communication.

### Mistake 3: Treating a Cluster as Three Copies of a Single VM

This leads to the wrong Terraform structure and the wrong network model.

### Mistake 4: Opening Too Many Ports Too Early

Beginners sometimes respond to connectivity issues by allowing broad access everywhere. That creates confusion and weakens security.

### Mistake 5: Introducing Too Many Tools at Once

If you try to learn:

- Azure
- Terraform
- Linux host prep
- Kubernetes
- kubeadm
- Cilium
- ingress
- storage
- observability

all at once, you will slow yourself down.

Focus first on the cluster foundation.

### Mistake 6: Comparing Many Cluster Types Before Understanding One

It is more useful to deeply understand one baseline path than to shallowly compare six cluster creation methods.

---

## How to Know the Cluster Is Working

A guide should never stop at "the commands ran successfully."

You need a validation checklist.

### Infrastructure Validation

Check that:

- the resource group exists
- the VNet and subnet exist
- the NSG is attached as intended
- each node has the expected private IP
- only the intended nodes have public IPs

### Node-Level Validation

Check that:

- the control-plane node is reachable by SSH
- workers can reach the control plane over private networking
- each node has the expected hostname and network configuration

### Kubernetes Validation

Check that:

- `kubeadm init` completed successfully
- worker nodes joined successfully
- `kubectl get nodes` shows all nodes
- the nodes become `Ready`

### CNI Validation

Check that:

- Cilium is installed correctly
- Cilium pods are healthy
- pods on different nodes can communicate

### Security Validation

Check that:

- SSH is not open broadly to the internet
- worker nodes are not unnecessarily public
- API server exposure is intentional and understood

A cluster is not "done" when resources exist. A cluster is working when connectivity, orchestration, and security posture all make sense.

---

**Note:** 
Important limitation:

  - with one subnet-level NSG only, you can achieve explicit internal cluster ports, but you still cannot fully isolate control-plane-only
    ports from worker nodes.
  - true least privilege comes later when you introduce node resources and can target separate subnets, NIC NSGs, or ASGs.

## What "Expert" Means in This Context

For this topic, becoming advanced does not mean memorizing every port number.

It means you can reason through the design.

An advanced learner should be able to explain:

- why the cluster uses one shared VNet
- why the control plane and workers have different exposure needs
- why CNI choice matters
- why Terraform should split shared and repeated resources
- which traffic should stay private
- which traffic must be reachable externally
- how to harden the baseline architecture without breaking the cluster

That is real infrastructure understanding.

---

## What Comes After This Guide

Once you understand the baseline cluster, you can grow into more advanced topics such as:

- private-only clusters
- bastion hosts
- NAT gateways
- separate subnets by node role
- multiple control planes for high availability
- ingress controllers
- external load balancers
- persistent storage
- observability stacks
- network policies
- production hardening

But those should come **after** the baseline cluster is conceptually solid.

---

## Final Takeaway

If you remember only one thing from this guide, remember this:

> Build the network first, understand the traffic second, model the infrastructure correctly in Terraform third, and only then think about Kubernetes bootstrap details.

That order matters.

Beginners often start from commands.
Experienced engineers start from architecture and communication paths.

This guide is designed to help you make that transition.

---

## References

- Kubernetes ports and protocols:
  https://kubernetes.io/docs/reference/networking/ports-and-protocols/
- Kubernetes `kubeadm` overview:
  https://kubernetes.io/docs/reference/setup-tools/kubeadm/
- Installing `kubeadm`:
  https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- Azure NSG overview and default security rules:
  https://learn.microsoft.com/en-us/azure/architecture/networking/guide/network-level-segmentation
- Cilium installation with `kubeadm`:
  https://docs.cilium.io/en/stable/installation/k8s-install-kubeadm.html
- Cilium system requirements:
  https://docs.cilium.io/en/stable/operations/system_requirements.html
