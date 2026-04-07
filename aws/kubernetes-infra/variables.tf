variable "project_name" {
    description = "The name of the project, used for tagging resources."
    type        = string
    default     = "kubernetes-infra"
  
}

variable "aws_region" {
    description = "The AWS region to deploy the infrastructure in."
    type        = string
    default     = "us-east-2"
  
}

variable "vpc_cidr_block" {
    description = "The CIDR block for the VPC."
    type        = string
    default     = "172.16.0.0/16"
  
}

variable "public_subnet_cidr_block" {
    description = "The CIDR block for the public subnet."
    type        = string
    default     = "172.16.1.0/24"
  
}

variable "private_subnet_cidr_block_1" {
    description = "The CIDR block for the private subnet 1."
    type        = string
    default     = "172.16.2.0/24"
  
}


variable "private_subnet_cidr_block_2" {
    description = "The CIDR block for the private subnet 2."
    type        = string
    default     = "172.16.3.0/24"
  
}

variable "admin_ssh_cidr_block" {
    description = "The CIDR block for the admin SSH access."
    type        = string
    default     = "108.35.175.17/32"
}

variable "admin_ssh_key" {
    description = "The public SSH key for admin access to the instances."
    type        = string
    default     = "/home/endie/.ssh/id_ed25519.pub"
  
}