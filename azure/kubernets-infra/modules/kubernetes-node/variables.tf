variable "node_name" {
  description = "The name of the Kubernetes node"
  type        = string
}

variable "vm_zone" {
  description = "The zone where the virtual machine will be deployed"
  type        = string
}

variable "vm_size" {
  description = "The size of the virtual machine"
  type        = string
}

variable "admin_username" {
  description = "The username for the admin user"
  type        = string
}

variable "public_key_path" {
  description = "The path to the public SSH key"
  type        = string
}

variable "os_disk_storage_account_type" {
  description = "The storage account type for the OS disk"
  type        = string
}

variable "image_publisher" {
  description = "The publisher of the source image"
  type        = string
}

variable "image_offer" {
  description = "The offer of the source image"
  type        = string
}

variable "image_sku" {
  description = "The SKU of the source image"
  type        = string
}

variable "image_version" {
  description = "The version of the source image"
  type        = string
}

variable "network_interface_ids" {
  description = "The IDs of the network interfaces to attach to the virtual machine"
  type        = list(string)
}

variable "location" {
  description = "The location for the resource"
  type = string
}

variable "rg_name" {
  description = "The name of the resource group where the resource belongs to"
  type = string
}