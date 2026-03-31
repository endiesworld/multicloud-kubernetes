# SSH Access Patterns For The Control Plane

This file is meant to build a clear mental model for how SSH access to the Kubernetes control-plane VM works in Azure, and how different network designs change security and exposure.

## Core Mental Model

SSH from the internet works only when **all** of these are true:

1. There is a public entry path.
2. That path leads to the control-plane NIC.
3. Azure network filtering allows the traffic.
4. The VM guest OS allows the traffic.
5. `sshd` is listening on the VM.

For direct access to a VM, the path is:

`Internet -> public entry point -> NIC -> VM guest OS`

The public entry point might be:

- a public IP attached to the control-plane NIC
- a public load balancer with inbound NAT
- Azure Bastion
- a jumpbox
- a firewall doing DNAT
- a VPN/private enterprise path

## Important Distinctions

### Public IP does not automatically mean "open"

A public IP only creates a possible route.

It does **not** by itself mean:

- all ports are open
- SSH is allowed
- the VM is reachable

Traffic still depends on:

- NSG rules
- guest OS firewall rules
- whether a service is listening on the port

### NSG allow does not automatically mean "publicly reachable"

An NSG rule can allow `22/TCP`, but a VM is still not reachable from the internet unless there is also a public or externally routed path to it.

So these are different questions:

- "Does policy allow SSH?"
- "Is there any network path from the internet to this node?"

Both must be true for internet SSH to work.

## SSH Configuration Patterns

Use the table below to answer four questions:

- What is exposed to the internet?
- How does SSH actually reach the control plane?
- Are workers directly reachable from the internet?
- What accidental change could expose more nodes later?

| Pattern | What Is Internet-Facing | How SSH Reaches The Control Plane | Are Workers Directly Internet-Reachable? | Main Security Implication |
|---|---|---|---|---|
| Control-plane public IP + subnet NSG SSH allow | Control-plane public IP | `Internet -> control-plane public IP -> control-plane NIC -> VM`, and the subnet NSG allows `22/TCP` from your admin IP | No, unless a worker later gets its own public entry path | Simple, but a broad subnet SSH rule can become risky later if a worker is later given a public IP, NAT rule, or other external path |
| Control-plane public IP + ASG-targeted subnet NSG SSH allow | Control-plane public IP | Same path, but the subnet NSG rule targets only the control-plane ASG | No, unless a worker is added to that ASG or gets a separate public path | Better scoping; this is the safer direct-public-IP pattern when SSH must be limited to the control plane |
| Control-plane public IP + NIC NSG allow only | Control-plane public IP | Works only if subnet-level filtering also allows it, or there is no subnet NSG blocking it | No, unless workers get their own public path | Easy to misconfigure because Azure evaluates subnet and NIC filtering together |
| Public load balancer + inbound NAT to control plane | Load balancer public IP | `Internet -> load balancer public IP -> NAT rule -> control-plane private IP/NIC -> VM` | No, by default | Good when you do not want a public IP directly on the VM, but NAT rules must be tightly scoped |
| Azure Bastion | Bastion public IP | `Internet -> Bastion -> control-plane private IP` | No direct public access to workers | Stronger access model because nodes stay private; access control moves to Bastion and Azure RBAC |
| Jumpbox / bastion VM | Jumpbox public IP | `Internet -> jumpbox -> control-plane private IP` | No direct public access to workers | The jumpbox becomes the exposed asset and the pivot point |
| VPN / ExpressRoute | VPN gateway or private enterprise edge | `Laptop joins private network -> control-plane private IP` | No direct internet exposure | Best private model, but any node allowed by NSG from the VPN CIDR becomes reachable from that private network |
| Azure Firewall / NVA DNAT | Firewall or NVA public IP | `Internet -> firewall public IP -> DNAT -> control-plane private IP` | No, by default | Centralized control, but bad DNAT rules can widen access to other nodes |
| No public path at all | Nothing | SSH from the public internet does not work | No | Most private option, but you need Bastion, VPN, or an internal jump path |

## How To Read "Worker Exposure"

Readers often mix up these two ideas:

- a worker is **allowed** by policy
- a worker is **reachable** from outside

They are not the same.

A worker becomes internet-reachable only when **both** of these are true:

1. A route exists from outside to that worker.
2. Security rules allow the SSH traffic.

Examples of a route existing:

- the worker gets its own public IP
- the worker is added behind a load balancer NAT rule
- a firewall DNAT rule forwards traffic to it
- a VPN or private enterprise network can reach it

So a subnet-level SSH allow rule does **not** expose workers by itself. It becomes dangerous when a public or routed path is later added.

## Recommended Beginner Pattern

For a beginner guide, the simplest useful pattern is:

- only the control plane gets a public IP
- SSH is restricted to the admin IP or admin CIDR
- workers have no public IP
- workers use private IP communication only

This is easy to reason about because:

- there is one obvious admin entry point
- worker nodes remain private
- cluster traffic stays on the private network

## Recommended Safer Pattern

If the goal is stronger security and a clearer separation between administration and node exposure, use:

- Azure Bastion
- no public IPs on any node

This reduces direct internet exposure of the cluster nodes.

## Practical Rule Of Thumb

Ask these questions in order:

1. What is the public entry point?
2. Which NIC or private IP does that entry point lead to?
3. Do subnet and NIC policies allow the traffic?
4. Does the VM itself allow SSH?
5. Could a future change accidentally give another node the same external path?

If you can answer those five clearly, your SSH design is probably understandable and defensible.

## Useful Azure Documentation

- NSG behavior and rule evaluation:
  https://learn.microsoft.com/en-us/azure/architecture/networking/guide/network-level-segmentation
- How NSGs apply to subnets and NICs:
  https://learn.microsoft.com/en-us/azure/virtual-network/network-security-group-how-it-works
- Azure public IP addresses:
  https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/public-ip-addresses
- NIC IP configuration and public IP association:
  https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/virtual-network-network-interface-addresses
- Application Security Groups:
  https://learn.microsoft.com/en-us/azure/virtual-network/application-security-groups
