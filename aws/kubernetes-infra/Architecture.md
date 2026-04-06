# AWS-Native VM Kubernetes Architecture

## Purpose

This document captures the refined project architecture for reproducing the Azure VM-based Kubernetes learning environment on AWS using native AWS infrastructure primitives.

The goal is not to build a managed Kubernetes service. The goal is to preserve the same learning methodology:

- provision raw virtual machines
- build a private-first Kubernetes topology
- expose only the control plane for administration
- keep worker nodes private
- express infrastructure intent clearly before implementation

## Scope

This architecture describes infrastructure only.

It does not define:

- kubeadm bootstrap steps
- operating system hardening
- Kubernetes installation scripts
- application deployment

## Architecture Type

This design is an AWS-native equivalent of the Azure VM-based learning cluster.

It is not a strict one-to-one network reproduction of the Azure version because the AWS design intentionally uses public and private subnet separation with NAT-based outbound access for private worker nodes.

## Target Topology

```text
AWS Region
|
`-- VPC
    |
    |-- Internet Gateway
    |
    |-- Public Subnet (Availability Zone 1)
    |   |
    |   |-- Control Plane EC2 Instance
    |   |   |-- Public IP
    |   |   `-- Control Plane Security Group
    |   |
    |   `-- NAT Gateway
    |
    |-- Private Subnet (Availability Zone 1)
    |   |
    |   `-- Worker Node 1 EC2 Instance
    |       `-- Worker Security Group
    |
    `-- Private Subnet (Availability Zone 2)
        |
        `-- Worker Node 2 EC2 Instance
            `-- Worker Security Group
```

## Core Design Intent

- The control plane is the only public administration entry point.
- Worker nodes do not receive public IP addresses.
- Worker nodes are reachable only through private network paths.
- Cluster communication remains inside the VPC.
- Worker outbound internet access uses a NAT path rather than direct public exposure.
- The design separates public reachability, private reachability, routing, and traffic policy.

## Reachability Model

### Control Plane

The control plane is internet-reachable only because all of the following are true:

- it is placed in a public subnet
- it has a public IP
- its subnet has a default route to the Internet Gateway
- its security group explicitly allows the traffic

This means the control plane is the public administrative entry point for the cluster.

### Worker Nodes

The worker nodes are not internet-reachable because:

- they are placed in private subnets
- they do not have public IP addresses
- their subnets do not expose them directly to the internet

The workers may still initiate outbound traffic through a NAT Gateway, but NAT-based egress does not make them publicly reachable for inbound administration.

### Administrative Access Pattern

Administrative access follows this model:

- laptop to control plane over public SSH
- control plane to worker nodes over private SSH

This keeps workers private while preserving manageability.

## Routing Model

### Public Subnet Routing

The public subnet contains resources that require internet-facing reachability.

Expected route behavior:

- default route to the Internet Gateway for internet ingress and egress

### Private Subnet Routing

The private subnets contain worker nodes that should remain private.

Expected route behavior:

- default route from each private subnet to the NAT Gateway for outbound internet access

### VPC-Internal Traffic

Traffic between cluster nodes remains inside the VPC. This internal communication should be understood as private cluster traffic, not as public routing behavior.

The important custom routing concern in this architecture is default-route behavior for public and private subnet classes.

## Security Model

### Why Role-Based Thinking Is Stronger Than CIDR-Based Thinking

A CIDR-based model says:

- anything inside a permitted IP range may connect

A role-based model says:

- only the systems with the intended function may connect

For this project, role-based thinking is the stronger mental model because it maps access rules to node purpose:

- admin laptop
- control plane
- worker nodes
- cluster-internal node traffic

This is preferable to broadly allowing traffic from the entire VPC CIDR when the real intent is narrower.

### Security Group Intent

The security group model should reflect node roles rather than treating all nodes as identical.

#### Control Plane Security Group

Intended inbound sources:

- SSH from the administrator's public IP
- Kubernetes API access from worker nodes and cluster-private sources
- cluster-internal node traffic required for Kubernetes control-plane and CNI behavior

Representative inbound traffic intent:

- `22/TCP` from administrator public IP
- `6443/TCP` from worker-node role or other approved cluster-private sources
- `10250/TCP` from cluster-private sources
- `10256/TCP` from cluster-private sources when needed
- `10257/TCP` and `10259/TCP` for control-plane component communication
- `2379-2380/TCP` for etcd-related control-plane traffic
- `4240/TCP` and `8472/UDP` for Cilium-related node traffic when that data plane is used

#### Worker Security Group

Intended inbound sources:

- SSH from the control-plane role for private administration
- cluster-internal traffic from cluster node roles

Representative inbound traffic intent:

- `22/TCP` from control-plane role
- `10250/TCP` from cluster-private sources
- `10256/TCP` from cluster-private sources when needed
- `4240/TCP` and `8472/UDP` from cluster-private sources for Cilium-related node traffic when required

Worker nodes should not expose public administration paths.

## Role Relationships

The architecture should be reasoned about in terms of who is supposed to communicate with whom:

- administrator laptop to control plane
- control plane to worker nodes
- worker nodes to control-plane API
- cluster nodes to cluster nodes for internal Kubernetes and CNI traffic

This is the key refinement over a broad CIDR-only mental model.

## Design Notes

- This architecture improves on the original Azure network shape by using separate public and private subnet classes.
- The worker placement across two Availability Zones improves worker resilience, but the design still has a single control plane and therefore retains a control-plane single point of failure.
- NAT-based egress for workers supports package retrieval and similar outbound needs without assigning workers public IP addresses.
- A broad VPC CIDR rule may work during early learning, but the intended long-term model should remain role-based and least-privileged.

## Summary

This project architecture should be understood as:

- a VM-based Kubernetes learning environment
- a private-first cluster design
- one public control-plane entry point
- private worker nodes in separate private subnets
- routing that distinguishes public ingress from private outbound egress
- security intent expressed by node role, not only by IP range
