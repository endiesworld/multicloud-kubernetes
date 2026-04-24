terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Create a VPC
resource "aws_vpc" "vpc_resource" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.vpc_resource.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.vpc_resource.id
  cidr_block        = var.public_subnet_cidr_block
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.vpc_resource.id
  cidr_block        = var.private_subnet_cidr_block_1
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.vpc_resource.id
  cidr_block        = var.private_subnet_cidr_block_2
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "${var.project_name}-private-subnet-2"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  subnet_id     = aws_subnet.public_subnet.id
  allocation_id = aws_eip.nat_eip.id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.internet_gw]
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc_resource.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc_resource.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}


resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_route_table_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_route_table_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# =========================
# SECURITY GROUPS
# =========================

resource "aws_security_group" "cp_security_group" {
  name        = "${var.project_name}-cp-sg"
  description = "Security group for Kubernetes control plane"
  vpc_id      = aws_vpc.vpc_resource.id

  tags = {
    Name = "${var.project_name}-cp-sg"
  }
}

resource "aws_security_group" "worker_security_group" {
  name        = "${var.project_name}-worker-sg"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = aws_vpc.vpc_resource.id

  tags = {
    Name = "${var.project_name}-worker-sg"
  }
}


# =========================
# CONTROL PLANE INGRESS
# =========================

# Admin SSH -> control plane
resource "aws_vpc_security_group_ingress_rule" "cp_ingress_ssh_from_admin" {
  security_group_id = aws_security_group.cp_security_group.id
  cidr_ipv4         = var.admin_ssh_cidr_block
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "Allow SSH from admin CIDR to control plane"
}

# Workers -> control plane API server
resource "aws_vpc_security_group_ingress_rule" "cp_ingress_apiserver_from_workers" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
  description                  = "Allow workers to reach Kubernetes API server"
}

# Workers -> Control Plane (NFS Server)
resource "aws_vpc_security_group_ingress_rule" "cp_ingress_nfs_from_workers" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
  description                  = "Allow NFS traffic from workers to control plane"
}

# Allow Workers to reach RPC Bind (Required for showmount)
resource "aws_vpc_security_group_ingress_rule" "cp_nfs_rpc" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 111
  to_port                      = 111
  ip_protocol                  = "tcp" # Add a second rule for "udp" if needed
  description                  = "RPC Bind for NFS"
}

# Control plane self -> kubelet on control plane
resource "aws_vpc_security_group_ingress_rule" "cp_ingress_kubelet_self" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Allow control plane self-access to kubelet"
}

# Control plane self -> scheduler
resource "aws_vpc_security_group_ingress_rule" "cp_ingress_scheduler_self" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 10259
  to_port                      = 10259
  ip_protocol                  = "tcp"
  description                  = "Allow control plane self-access to kube-scheduler"
}

# Control plane self -> controller manager
resource "aws_vpc_security_group_ingress_rule" "cp_ingress_controller_manager_self" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 10257
  to_port                      = 10257
  ip_protocol                  = "tcp"
  description                  = "Allow control plane self-access to kube-controller-manager"
}

# Control plane self -> etcd
resource "aws_vpc_security_group_ingress_rule" "cp_ingress_etcd_self" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 2379
  to_port                      = 2380
  ip_protocol                  = "tcp"
  description                  = "Allow control plane self-access to etcd"
}

# Workers -> control plane for Cilium health
resource "aws_vpc_security_group_ingress_rule" "cp_ingress_cilium_health_from_workers" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 4240
  to_port                      = 4240
  ip_protocol                  = "tcp"
  description                  = "Allow Cilium health traffic from workers to control plane"
}

# Workers -> control plane for Cilium VXLAN
resource "aws_vpc_security_group_ingress_rule" "cp_ingress_cilium_vxlan_from_workers" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  description                  = "Allow Cilium VXLAN traffic from workers to control plane"
}


# =========================
# CONTROL PLANE EGRESS
# =========================

# Control plane -> workers SSH
resource "aws_vpc_security_group_egress_rule" "cp_egress_ssh_to_workers" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  description                  = "Allow SSH from control plane to workers"
}

# Control plane -> workers kubelet API
resource "aws_vpc_security_group_egress_rule" "cp_egress_kubelet_to_workers" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Allow control plane to reach worker kubelets"
}

# Control plane -> workers for Cilium health
resource "aws_vpc_security_group_egress_rule" "cp_egress_cilium_health_to_workers" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 4240
  to_port                      = 4240
  ip_protocol                  = "tcp"
  description                  = "Allow Cilium health traffic from control plane to workers"
}

# Control plane -> workers for Cilium VXLAN
resource "aws_vpc_security_group_egress_rule" "cp_egress_cilium_vxlan_to_workers" {
  security_group_id            = aws_security_group.cp_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  description                  = "Allow Cilium VXLAN traffic from control plane to workers"
}

# Control plane -> internet HTTPS
resource "aws_vpc_security_group_egress_rule" "cp_egress_https_internet" {
  security_group_id = aws_security_group.cp_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow control plane outbound HTTPS"
}

# Control plane -> internet HTTP
resource "aws_vpc_security_group_egress_rule" "cp_egress_http_internet" {
  security_group_id = aws_security_group.cp_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow control plane outbound HTTP"
}

# Optional: control plane -> internet ICMP
resource "aws_vpc_security_group_egress_rule" "cp_egress_icmp_internet" {
  security_group_id = aws_security_group.cp_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  description       = "Allow control plane outbound ICMP for diagnostics"
}


# =========================
# WORKER INGRESS
# =========================

# Control plane -> workers SSH
resource "aws_vpc_security_group_ingress_rule" "worker_ingress_ssh_from_cp" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  description                  = "Allow SSH from control plane to workers"
}

# Control plane -> workers kubelet API
resource "aws_vpc_security_group_ingress_rule" "worker_ingress_kubelet_from_cp" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Allow control plane to reach worker kubelets"
}

# Control plane -> workers for Cilium health
resource "aws_vpc_security_group_ingress_rule" "worker_ingress_cilium_health_from_cp" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 4240
  to_port                      = 4240
  ip_protocol                  = "tcp"
  description                  = "Allow Cilium health traffic from control plane to workers"
}

# Control plane -> workers for Cilium VXLAN
resource "aws_vpc_security_group_ingress_rule" "worker_ingress_cilium_vxlan_from_cp" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  description                  = "Allow Cilium VXLAN traffic from control plane to workers"
}

# Worker -> worker for Cilium health
resource "aws_vpc_security_group_ingress_rule" "worker_ingress_cilium_health_from_workers" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 4240
  to_port                      = 4240
  ip_protocol                  = "tcp"
  description                  = "Allow Cilium health traffic between workers"
}

# Worker -> worker for Cilium VXLAN
resource "aws_vpc_security_group_ingress_rule" "worker_ingress_cilium_vxlan_from_workers" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  description                  = "Allow Cilium VXLAN traffic between workers"
}


# =========================
# WORKER EGRESS
# =========================

# Workers -> control plane API server
resource "aws_vpc_security_group_egress_rule" "worker_egress_apiserver_to_cp" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
  description                  = "Allow workers to reach Kubernetes API server"
}

# Workers -> control plane for Cilium health
resource "aws_vpc_security_group_egress_rule" "worker_egress_cilium_health_to_cp" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 4240
  to_port                      = 4240
  ip_protocol                  = "tcp"
  description                  = "Allow Cilium health traffic from workers to control plane"
}

# Workers -> control plane for Cilium VXLAN
resource "aws_vpc_security_group_egress_rule" "worker_egress_cilium_vxlan_to_cp" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  description                  = "Allow Cilium VXLAN traffic from workers to control plane"
}

# Worker -> worker for Cilium health
resource "aws_vpc_security_group_egress_rule" "worker_egress_cilium_health_to_workers" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 4240
  to_port                      = 4240
  ip_protocol                  = "tcp"
  description                  = "Allow Cilium health traffic between workers"
}

# Worker -> worker for Cilium VXLAN
resource "aws_vpc_security_group_egress_rule" "worker_egress_cilium_vxlan_to_workers" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.worker_security_group.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  description                  = "Allow Cilium VXLAN traffic between workers"
}

# Workers -> internet HTTPS via NAT
resource "aws_vpc_security_group_egress_rule" "worker_egress_https_internet" {
  security_group_id = aws_security_group.worker_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow workers outbound HTTPS"
}

# Workers -> internet HTTP via NAT
resource "aws_vpc_security_group_egress_rule" "worker_egress_http_internet" {
  security_group_id = aws_security_group.worker_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow workers outbound HTTP"
}

# Optional: workers -> internet ICMP
resource "aws_vpc_security_group_egress_rule" "worker_egress_icmp_internet" {
  security_group_id = aws_security_group.worker_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  description       = "Allow workers outbound ICMP for diagnostics"
}

# Workers -> Control Plane (NFS Server)
resource "aws_vpc_security_group_egress_rule" "worker_egress_nfs_to_cp" {
  security_group_id            = aws_security_group.worker_security_group.id
  referenced_security_group_id = aws_security_group.cp_security_group.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
  description                  = "Allow workers to reach NFS server on control plane"
}

resource "aws_key_pair" "cp_key_pair" {
  key_name   = "${var.project_name}-cp-key"
  public_key = file(var.admin_ssh_key)

}

data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "cp_instance" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.cp_security_group.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.cp_key_pair.key_name

  tags = {
    Name = "${var.project_name}-cp"
  }

  root_block_device {
    volume_size           = 32
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #cloud-config
    preserve_hostname: true
    hostname: ${var.project_name}-cp
    fqdn: ${var.project_name}-cp.local
  EOF
}

resource "aws_instance" "worker_instance_1" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.private_subnet_1.id
  vpc_security_group_ids      = [aws_security_group.worker_security_group.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.cp_key_pair.key_name

  tags = {
    Name = "${var.project_name}-worker-1"
  }

  root_block_device {
    volume_size           = 32
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #cloud-config
    preserve_hostname: true
    hostname: ${var.project_name}-worker-1
    fqdn: ${var.project_name}-worker-1.local
  EOF
}

resource "aws_instance" "worker_instance_2" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.private_subnet_2.id
  vpc_security_group_ids      = [aws_security_group.worker_security_group.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.cp_key_pair.key_name

  tags = {
    Name = "${var.project_name}-worker-2"
  }

  root_block_device {
    volume_size           = 32
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #cloud-config
    preserve_hostname: true
    hostname: ${var.project_name}-worker-2
    fqdn: ${var.project_name}-worker-2.local
  EOF
}

