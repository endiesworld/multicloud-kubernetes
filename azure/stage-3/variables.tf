variable "environment" {
  description = "Describes the infrastructure environment: test || stagin || production"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the resources."
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
}

variable "subnet_address_space_cidr" {
  description = "The address space in CIDR notation for the subnet."
  type        = list(string)
}

variable "subnet_name" {
  description = "The name of the subnet to create."
  type        = string
}

variable "public_ip_name" {
  description = "The name of the public IP address to create."
  type        = string
}

variable "nic_name" {
  description = "The name of the network interface to create."
  type        = string
}

variable "nsg_name" {
  description = "The name of the network security group to create."
  type        = string
}

variable "ssh_source_ip" {
  description = "The source IP address or CIDR block to allow SSH access from."
  type        = string
}

variable "vm_size" {
  description = "The size of the virtual machine to create."
  type        = string
  default     = "Standard_DC1s_v3" # This VM size has been confirmed to be available in the East US region and is suitable for a small Kubernetes node.
}

variable "admin_username" {
  description = "The admin username for the virtual machine."
  type        = string
  default     = "azureuser"
}

variable "vm_name" {
  description = "The name of the virtual machine to create."
  type        = string
  default     = "terraform-kubernetes-vm"
}

variable "vm_zone" {
  description = "The availability zone to deploy the virtual machine in."
  type        = string
  default     = "3" # Zone 3 has been confirmed to have capacity for the chosen VM size in the East US region.
}

variable "os_disk_storage_account_type" {
  description = "The storage account type for the OS disk."
  type        = string
  default     = "Standard_LRS" # Standard_LRS is a cost-effective option for the OS disk and is suitable for development and testing environments. For production workloads, consider using Premium_LRS for better performance.
}

variable "image_publisher" {
  description = "The publisher of the image to use for the virtual machine."
  type        = string
  default     = "Canonical" # Canonical is the publisher of the official Ubuntu images in Azure, and has been confirmed to have the desired Ubuntu 22.04 LTS image available in the East US region.
}

variable "image_offer" {
  description = "The offer of the image to use for the virtual machine."
  type        = string
  default     = "0001-com-ubuntu-server-jammy" # This offer corresponds to the Ubuntu Server 22.04 LTS image, which is suitable for a Kubernetes node.
}

variable "image_sku" {
  description = "The SKU of the image to use for the virtual machine."
  type        = string
  default     = "22_04-lts-gen2" # This SKU corresponds to the latest generation of the Ubuntu Server 22.04 LTS image, which is recommended for new deployments, and has been confirmed to be available in the East US region.
}

variable "image_version" {
  description = "The version of the image to use for the virtual machine."
  type        = string
  default     = "latest"
}

variable "public_key_path" {
  description = "The file path to the public SSH key to use for authentication."
  type        = string
  default     = "/home/endie/.ssh/azure/kubernetes.pub" # Update this path to point to your actual public SSH key file.
}