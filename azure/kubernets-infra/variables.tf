variable "subscription_id" {
  description = "Azure account subscription id"
  type        = string
  default     = "98456b7d-49ec-406e-9c4b-aa98b0232b74"
}

variable "project_name" {
  description = "The name of the project to use this resources for"
  type        = string
}

variable "environment" {
  description = "Describes the infrastructure environment: test || stagin || production"
  type        = string
}

variable "location" {
  description = "The region where the resource group will be deployed to"
  type        = string
}

variable "vnet_name" {
  description = "The name of the virtual network to create."
  type        = string
}

variable "vnet_address_space_cidr" {
  description = "The address space in CIDR notation for the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_space_cidr" {
  description = "The address space in CIDR notation for the subnet."
  type        = list(string)
  default     = ["10.0.1.0/24"]
  validation {
    condition     = length(var.subnet_address_space_cidr) == 1
    error_message = "This shared-foundation stage expects exactly one subnet CIDR."
  }
}

variable "subnet_name" {
  description = "The name of the subnet to create."
  type        = string
}

variable "nsg_name" {
  description = "The name for the network security group"
  type        = string
}

variable "enable_cilium_vxlan" {
  description = "Whether to enable the NSG rule allowing Cilium VXLAN traffic"
  type        = bool
  default     = true
}

variable "ssh_source_ip" {
  description = "The public IP address of the administrator's machine for SSH access"
  type        = string
}