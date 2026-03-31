# Network Primitives Reference

This file explains four Azure networking concepts that are easy to confuse when building a Kubernetes cluster on VMs:

- `Public IP`
- `NIC`
- `NSG`
- `ASG`

The goal is to build a reliable mental model for how they differ and how they work together.

## Short Version

Think of them like this:

- `Public IP`: gives traffic a public address to arrive at
- `NIC`: gives the VM a network attachment
- `NSG`: allows or denies network traffic
- `ASG`: groups NICs so NSG rules can target them cleanly

They do different jobs.

## The Main Question Each One Answers

| Primitive | Main Question It Answers |
|---|---|
| Public IP | "Is there a public address or entry point?" |
| NIC | "Which VM network attachment receives this traffic?" |
| NSG | "Is this traffic allowed or denied?" |
| ASG | "Which set of NICs should this NSG rule apply to?" |

## Detailed Comparison

| Primitive | What It Is | What It Does | What It Does Not Do | Typical Use In Your Cluster |
|---|---|---|---|---|
| Public IP | A public Azure IP resource | Gives a resource a public-facing address or frontend path | Does not by itself allow any ports or bypass filtering | Used only for the control plane if you want direct admin access |
| NIC | The VM's network interface | Connects the VM to a subnet and can carry private and optionally public addressing | Does not by itself decide which traffic is allowed | Each node needs its own NIC in the shared subnet |
| NSG | Azure network filtering policy | Allows or denies traffic by source, destination, port, and protocol | Does not create a route or public path | Used to control SSH, Kubernetes API, kubelet, and CNI-related traffic |
| ASG | A logical grouping of NICs | Lets NSG rules target a group of NICs without using raw IPs | Does not route traffic, expose nodes, or replace NSGs | Used to say "this rule is only for the control plane" |

## Relationship Model

The easiest way to think about them is:

- `Public IP` answers: "Can traffic come from the internet?"
- `NIC` answers: "Which VM does the traffic arrive at?"
- `NSG` answers: "Is that traffic permitted?"
- `ASG` answers: "Which NICs does this rule apply to?"

So the full thought process is:

1. Is there any path from the source to Azure?
2. Which public frontend or private route does it use?
3. Which NIC receives the traffic?
4. Do subnet and NIC filtering allow it?
5. Is the target VM actually meant to receive it?

## How They Work Together In SSH To The Control Plane

### Pattern 1: Public IP on the control plane

Path:

`Internet -> Public IP -> Control-plane NIC -> VM`

Meaning:

- `Public IP` gives the control plane a public address
- `NIC` is the control plane's network attachment
- `NSG` decides whether `22/TCP` is allowed
- `ASG` can help scope the SSH rule to only the control-plane NIC

### Pattern 2: Azure Bastion

Path:

`Internet -> Bastion -> Control-plane private IP -> Control-plane NIC -> VM`

Meaning:

- the node itself does not need a public IP
- the NIC is still the target network interface
- NSGs still matter
- ASG can still help scope admin traffic to control-plane nodes only

## What Each Primitive Cannot Replace

This is where most confusion comes from.

### Public IP cannot replace NSG

A public IP creates a possible public path.

It does not:

- allow SSH
- open a port
- override a deny rule

### NIC cannot replace NSG

A NIC connects the VM to the network.

It does not:

- define port access
- make traffic safe
- decide who may connect

### NSG cannot replace Public IP

An NSG may allow `22/TCP`, but if there is no public IP, NAT, Bastion, firewall DNAT, or VPN path, the internet still cannot reach the VM.

### ASG cannot replace NSG

An ASG is only a grouping label for NICs.

It does not:

- allow traffic
- deny traffic
- expose a VM
- route a connection

## Common Mistakes

| Mistake | Why It Is Wrong | Better Mental Model |
|---|---|---|
| "A public IP means the VM is open." | A public IP only creates a possible route | Public path plus filtering plus VM-side acceptance are all required |
| "An NSG allow means the VM is reachable from the internet." | Reachability also needs a route from the source to the VM | Policy and routing are separate concerns |
| "ASG secures the VM." | ASG only helps NSG rules target groups cleanly | ASG is a selector, not a firewall |
| "The NIC decides what traffic is allowed." | The NIC is an attachment point, not a policy engine | Filtering is controlled by NSGs and the guest OS |
| "If only the control plane should get SSH, a separate NSG is always the best way." | In Azure, subnet and NIC NSGs are evaluated together, which often complicates the design | A subnet NSG plus ASG-targeted rules is often cleaner |

## Best Use Of Each One In Your Kubernetes Guide

For the beginner baseline:

- `NIC`
  - one NIC per node
- `Public IP`
  - only on the control plane if direct SSH is desired
- `NSG`
  - one shared subnet NSG for cluster traffic
- `ASG`
  - optional, but useful for targeting rules only to the control plane

That aligns with this teaching model:

- shared network foundation in the root module
- repeated node resources per node
- private-first cluster communication
- minimal public exposure

## Good Control-Plane SSH Design Choices

### Simpler beginner design

- control plane has a public IP
- workers do not have public IPs
- shared subnet NSG allows `22/TCP` only from the admin IP

Tradeoff:

- simple to understand
- less precise if workers later gain a public path

### Cleaner scoped design

- control plane has a public IP
- workers do not have public IPs
- shared subnet NSG allows `22/TCP` only from the admin IP
- rule targets the control-plane ASG

Tradeoff:

- slightly more Azure concepts to explain
- better long-term scoping

### Safer private design

- no node public IPs
- Bastion or VPN provides the admin path
- NSG permits admin traffic only through the private path

Tradeoff:

- stronger security model
- more moving parts for a beginner

## Fast Decision Guide

Use this when choosing the role of each primitive.

| If You Need To Answer... | The Main Azure Primitive Is... |
|---|---|
| "How does the internet even find this node?" | Public IP or another public frontend |
| "Which VM connection point receives this traffic?" | NIC |
| "Should this packet be allowed?" | NSG |
| "How do I target only the control-plane NIC without hardcoding IPs?" | ASG |

## A Simple Memory Trick

Remember:

- `Public IP` = address
- `NIC` = attachment
- `NSG` = filter
- `ASG` = grouping label

Or even shorter:

- `Public IP` = "arrive here"
- `NIC` = "this VM"
- `NSG` = "allowed?"
- `ASG` = "which group?"

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
