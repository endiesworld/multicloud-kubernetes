# Kubernetes infrastructure on AWS

## Core Principles/Design

- AWS networking layer: VPC, subnets, route tables, internet gateway, NAT gateway, and security groups.
- AWS compute layers: 3 EC2 instances (1 master, 2 workers).
- Kubernetes bootstraap layer: kubeadm init for control plane, kubeadm join for worker nodes.
- Kubernetes networking layer: Cilium CNI for pod networking.
- Kubernetes storage layer: EBS volumes for persistent storage.

## Some notes:

### AWS VPC (Spans all availability zones in a region)
- VPC: A virtual network dedicated to your AWS account. It provides isolation and control over your network resources.
For this project, A VPC is the private AWS network boundary that all three EC2 nodes will live in. It provides isolation and control over the network resources for the Kubernetes cluster. AWS route tables automatically include a local route for the VPC CIDR so that all subnets inside the VPC can talk to each other using private IP addresses. 
**Example**: If the VPC CIDR is `172.16.0.0/16`, then every subnet you create must be carved out of that space, like:
- Subnet 1: `172.16.1.0/24`
- Subnet 2: `172.16.2.0/24`
- Subnet 3: `172.16.3.0/24`

**VPC defines the network boundary and address space.**

### AWS Subnets (Spans one availability zone)
- Subnet: A range of IP addresses in your VPC, each subnet belongd to one availability zone. Subnets can be public (with internet access) or private (without direct internet access). Also, if you want workers split across two AZs, they cannot be in the same subnet.
A subnet is called:
    - public if its route table sends internet traffic to an Internet Gateway
    - private if its route table does not send internet traffic directly to an Internet Gateway, but instead sends it to a NAT Gateway or NAT instance in a public subnet.

### AWS Route Tables (Spans all availability zones in a region)
- Route Table: This is the VPC's traffic controller. It contains rules that determine where traffic from your subnets is directed. Each subnet must be associated with a route table, which controls the routing for that subnet. A route table can be associated with multiple subnets, but each subnet can only be associated with one route table. The main route table is automatically created when you create a VPC and is associated with all subnets by default. You can create additional route tables and associate them with specific subnets to control traffic flow.
**Note**: The main route table automatically includes a local route for the VPC CIDR, allowing all subnets within the VPC to communicate with each other using private IP addresses. This means that even if you have multiple subnets, they can still talk to each other without needing additional routing rules, as long as they are within the same VPC.
- For this project, there are three routes we care about:
    - Local route: This is automatically created for the VPC CIDR and allows all subnets within the VPC to communicate with each other using private IP addresses. i.e:
        - worker 1 talk to control plane over private IP
        - worker 2 talk to control plane over private IP
        - node-to-node traffic stay inside the VPC
    - Internet route for public subnets: This route sends all traffic destined for the internet (0.0.0.0/0) to the Internet Gateway. This is necessary for public subnets to have internet access.
    - Outbound route for private subnets: This route sends all traffic destined for the internet (0.0.0.0/0) to the NAT Gateway. This is necessary for private subnets to have internet access.

**the route table answers “where does this packet go next?”**

### AWS Internet Gateway (Spans all availability zones in a region)
- Internet Gateway: A horizontally scaled, redundant, and highly available VPC component that allows communication between instances in your VPC and the internet. It serves two purposes: to provide a target in your VPC route tables for internet-routable traffic, and to perform network address translation (NAT) for instances that have been assigned public IPv4 addresses. For this project, the Internet Gateway is attached to the VPC and allows instances in the public subnet (like the control plane) to communicate with the internet. It also allows instances in the private subnets (like the worker nodes) to access the internet through the NAT Gateway.
But the IGW alone is not enough. For an instance to be internet-reachable, you need all three:
1. The subnet route table has a route to the IGW
2. The instance has a public IP or Elastic IP
3. The security group allows the traffic you want

### AWS NAT Gateway (Spans all availability zones in a region)
- NAT Gateway: A managed service that provides network address translation (NAT) for instances in private subnets. It allows instances in private subnets to connect to the internet or other AWS services, but prevents the internet from initiating connections with those instances. For this project, the NAT Gateway is deployed in a public subnet and is used by instances in private subnets (like the worker nodes) to access the internet for updates, package downloads, etc., while still keeping them secure from inbound internet traffic.

**NAT gives private instances outbound internet without making them publicly reachable.**

### AWS Security Groups (Spans all availability zones in a region)
- Security Group: A virtual firewall that controls inbound and outbound traffic for your instances. It operates at the instance level and allows you to specify rules that permit or deny traffic based on protocols, ports, and source/destination IP addresses. For this project, security groups are used to control access to the control plane and worker nodes. For example, you might have a security group for the control plane that allows inbound traffic on port 6443 (Kubernetes API server) from the worker nodes, and a security group for the worker nodes that allows inbound traffic on port 10250 (Kubelet API) from the control plane.
security groups are stateful, meaning return traffic for an allowed connection is automatically permitted.

That means:
- route table says where traffic should go
- security group says whether it may pass

For example: A worker may have a route to the control plane, but if the control-plane SG blocks port 6443, the worker still cannot join the cluster.

Or:

a control plane in a public subnet may have a public IP
but if its SG blocks port 22, you still cannot SSH to it