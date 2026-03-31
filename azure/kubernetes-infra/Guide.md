# Beginers guide to setup and run Kubernetes Infra on Azure with Terraform

## Objectives

### 1- Define the target architecture
 what are all the possible architecture ? Recommendation for beginners ? Recommendation for expert ?
**Example**  
- cp-1: control plane VM
  - worker-1: worker VM
  - worker-2: worker VM
  - all 3 in the same subnet, private IPs
  - SSH allowed only from your public IP
  - Kubernetes API allowed only from:
      - your public IP, if you want to run kubectl from your machine
      - the worker nodes / VNet, so workers can join
  - no NodePort exposure yet unless you explicitly want it

  Security-wise, a better learning design is:

  - public IP on cp-1 only
  - no public IPs on workers
  - SSH to workers goes through the control plane or a bastion later

**Infratsructure Architecture**
- 1 shared resource group
  - 1 shared VNet
  - 1 shared subnet is enough for a first cluster
  - 1 NSG, usually attached at the subnet for simplicity
  - 3 NICs and 3 VMs inside that same subnet
  - optional public exposure only where needed

**Networking (CNI)-Calico, Flannel, Cilium**
- for this project we will use Cilium

**Types Clusters**
- kubeadm + containerd + Calico
  - kubeadm + containerd + Flannel
- kubeadm + containerd + Celium
  - k3s
- Rancher
- Minikube
- Kind

**Learning Order**
Learn this in order:

  1. Azure networking basics
     One VNet, one subnet, one NSG, three NICs, three VMs.
  2. Private vs public paths
     Node-to-node traffic should use private IPs, not public IPs.
  3. Kubernetes control-plane traffic
     Understand why workers need 6443 and why the control plane needs 10250 to nodes.
  4. CNI data plane
     Understand what extra traffic your pod network needs.
  5. Hardening
     Reduce public IPs, narrow source CIDRs, avoid broad internet exposure.

**Applicable NSG rules**
- list all options available/possible
- Adoption=> Best option for starter? example:
keep all nodes in one subnet and rely on Azure’s default VNet allow rules, your first-pass explicit rules can stay very small:

  - allow 22/TCP from your-public-ip/32
  - allow 6443/TCP to control plane from:
      - your public IP
      - the VNet/subnet
  - optionally do nothing else at first if the nodes share a subnet and you are not overriding the default VNet allow rules

  Then, once the cluster works, you can harden by replacing “implicit default VNet allow” with more explicit rules.

## 2. Translate that architecture into Terraform concepts
     Which resources belong once, and which belong per-node.
