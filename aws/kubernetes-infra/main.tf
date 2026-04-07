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
  vpc_id     = aws_vpc.vpc_resource.id
  cidr_block = var.public_subnet_cidr_block
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.vpc_resource.id
  cidr_block = var.private_subnet_cidr_block_1
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.vpc_resource.id
  cidr_block = var.private_subnet_cidr_block_2
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "${var.project_name}-private-subnet-2"
  }
}

resource "aws_eip" "nat_eip" {
  domain   = "vpc"

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
    cidr_block =  "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc_resource.id

  route{
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
  description = "Allow all inbound and outbound traffic for worker nodes"
  vpc_id      = aws_vpc.vpc_resource.id

  tags = {
    Name = "${var.project_name}-worker-sg"
  }
}

resource "aws_security_group_rule" "cp_ssh_from_admin" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.cp_security_group.id
  cidr_blocks       = [var.admin_ssh_cidr_block]
}

resource "aws_security_group_rule" "cp_api_from_workers" {
    type                     = "ingress"
    from_port                = 6443
    to_port                  = 6443
    protocol                 = "tcp"
    security_group_id        = aws_security_group.cp_security_group.id
    source_security_group_id = aws_security_group.worker_security_group.id
  }

resource "aws_security_group_rule" "cp_kubelet_from_workers" {
  type              = "ingress"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  source_security_group_id = aws_security_group.worker_security_group.id
  security_group_id = aws_security_group.cp_security_group.id
}

resource "aws_security_group_rule" "cp_kube_proxy_from_workers" {
  type              = "ingress"
  from_port         = 10256
  to_port           = 10256
  protocol          = "tcp"
  source_security_group_id = aws_security_group.worker_security_group.id
  security_group_id = aws_security_group.cp_security_group.id
}


resource "aws_security_group_rule" "cp_controller_manager" {
  type              = "ingress"
  from_port         = 10257
  to_port           = 10257
  protocol          = "tcp"
  security_group_id = aws_security_group.cp_security_group.id
  source_security_group_id =  aws_security_group.cp_security_group.id
}

resource "aws_security_group_rule" "cp_scheduler" {
  type              = "ingress"
  from_port         = 10259
  to_port           = 10259
  protocol          = "tcp"
  security_group_id = aws_security_group.cp_security_group.id
  source_security_group_id =  aws_security_group.cp_security_group.id
}

resource "aws_security_group_rule" "cp_etcd" {
  type              = "ingress"
  from_port         = 2379
  to_port           = 2380
  protocol          = "tcp"
  # cidr_blocks       = [aws_vpc.vpc_resource.cidr_block] # This is for etcd communication, which is only between control plane nodes, so we can use the control plane security group itself as the source.
  source_security_group_id = aws_security_group.cp_security_group.id
  security_group_id = aws_security_group.cp_security_group.id

}

resource "aws_security_group_rule" "cp_cilium_health_from_workers" {
  type              = "ingress"
  from_port         = 4240
  to_port           = 4240
  protocol          = "tcp"
  # cidr_blocks       = [aws_vpc.vpc_resource.cidr_block] # This is for cilium communication, which is only between control plane nodes, so we can use the control plane security group itself as the source.
  source_security_group_id = aws_security_group.worker_security_group.id
  security_group_id = aws_security_group.cp_security_group.id
}

resource "aws_security_group_rule" "cp_cilium_vxlan_from_workers" {
  type              = "ingress"
  from_port         = 8472
  to_port           = 8472
  protocol          = "udp"
  # cidr_blocks       = [aws_vpc.vpc_resource.cidr_block] # This is for cilium communication, which is only between control plane nodes, so we can use the control plane security group itself as the source.
  source_security_group_id = aws_security_group.worker_security_group.id
  security_group_id = aws_security_group.cp_security_group.id
}

resource "aws_key_pair" "cp_key_pair" {
  key_name   = "${var.project_name}-cp-key"
  public_key = file(var.admin_ssh_key)
  
}

data "aws_ami" "amzn-linux-2023-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["2023.10.20260330.0.*-x86_64"]
  }
}

resource "aws_instance" "cp_instance" {
  ami                         = data.aws_ami.amzn-linux-2023-ami.id
    instance_type               = "t3.large"
    subnet_id                   = aws_subnet.public_subnet.id
    vpc_security_group_ids      = [aws_security_group.cp_security_group.id]
    associate_public_ip_address = true
    key_name                    = aws_key_pair.cp_key_pair.key_name
}



