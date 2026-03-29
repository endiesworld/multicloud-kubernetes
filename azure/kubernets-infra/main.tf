terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  rg_name             = "${var.project_name}-${var.environment}-rg"
  cluster_subnet_cidr = var.subnet_address_space_cidr[0]

  required_internal_rules = {
    allow_k8s_api = {
      priority                   = 110
      protocol                   = "Tcp"
      destination_port_ranges    = ["6443"]
      source_address_prefixes    = var.subnet_address_space_cidr
      destination_address_prefix = local.cluster_subnet_cidr
    }

    allow_kubelet = {
      priority                   = 120
      protocol                   = "Tcp"
      destination_port_ranges    = ["10250"]
      source_address_prefixes    = var.subnet_address_space_cidr
      destination_address_prefix = local.cluster_subnet_cidr
    }

    allow_etcd = {
      priority                   = 130
      protocol                   = "Tcp"
      destination_port_ranges    = ["2379-2380"]
      source_address_prefixes    = var.subnet_address_space_cidr
      destination_address_prefix = local.cluster_subnet_cidr
    }

    allow_control_plane_components = {
      priority                   = 140
      protocol                   = "Tcp"
      destination_port_ranges    = ["10257", "10259"]
      source_address_prefixes    = var.subnet_address_space_cidr
      destination_address_prefix = local.cluster_subnet_cidr
    }

    allow_kube_proxy = {
      priority                   = 150
      protocol                   = "Tcp"
      destination_port_ranges    = ["10256"]
      source_address_prefixes    = var.subnet_address_space_cidr
      destination_address_prefix = local.cluster_subnet_cidr
    }

    allow_cilium_health = {
      priority                   = 160
      protocol                   = "Tcp"
      destination_port_ranges    = ["4240"]
      source_address_prefixes    = var.subnet_address_space_cidr
      destination_address_prefix = local.cluster_subnet_cidr
    }

    allow_ssh = {
      priority                   = 170
      protocol                   = "Tcp"
      destination_port_ranges    = ["22"]
      source_address_prefixes    = [var.ssh_source_ip]
      destination_address_prefix = local.cluster_subnet_cidr
    }
  }

  optional_rules = merge(
    var.enable_cilium_vxlan ? {
      allow_cilium_vxlan = {
        priority                   = 180
        protocol                   = "Udp"
        destination_port_ranges    = ["8472"]
        source_address_prefixes    = var.subnet_address_space_cidr
        destination_address_prefix = local.cluster_subnet_cidr
      }
    } : {}
  )

  nsg_rules = merge(local.required_internal_rules, local.optional_rules)
}


resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space_cidr
}

resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.subnet_address_space_cidr
}

resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "inbound" {
  for_each = local.nsg_rules

  name                        = each.key
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = each.value.protocol
  source_port_range           = "*"
  destination_port_ranges     = each.value.destination_port_ranges
  source_address_prefixes     = each.value.source_address_prefixes
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "control_plane_pip" {
  name                = "${var.project_name}-control-plane-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic-control-plane" {
  name                = "${var.project_name}-control-plane-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.control_plane_pip.id
  }
}

resource "azurerm_network_interface" "nic-worker-plane-1" {
  name                = "${var.project_name}-worker-plane-nic-1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "nic-worker-plane-2" {
  name                = "${var.project_name}-worker-plane-nic-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

module "contol-plane" {
  source = "./modules/kubernetes-node"

  node_name                    = "${var.project_name}-control-plane"
  rg_name                      = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  vm_zone                      = "3"
  vm_size                      = "Standard_DC2s_v3"
  admin_username               = "azureuser"
  public_key_path              = "/home/endie/.ssh/azure/kubernetes.pub"
  os_disk_storage_account_type = "Standard_LRS"
  image_publisher              = "Canonical"
  image_offer                  = "0001-com-ubuntu-server-jammy"
  image_sku                    = "22_04-lts-gen2"
  image_version                = "latest"
  network_interface_ids        = [azurerm_network_interface.nic-control-plane.id]

}

module "worker-node-1" {
  source = "./modules/kubernetes-node"

  node_name                    = "${var.project_name}-worker-node-1"
  rg_name                      = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  vm_zone                      = "3"
  vm_size                      = "Standard_DC1s_v3"
  admin_username               = "azureuser"
  public_key_path              = "/home/endie/.ssh/azure/kubernetes.pub"
  os_disk_storage_account_type = "Standard_LRS"
  image_publisher              = "Canonical"
  image_offer                  = "0001-com-ubuntu-server-jammy"
  image_sku                    = "22_04-lts-gen2"
  image_version                = "latest"
  network_interface_ids        = [azurerm_network_interface.nic-worker-plane-1.id]

}

module "worker-node-2" {
  source = "./modules/kubernetes-node"

  node_name                    = "${var.project_name}-worker-node-2"
  rg_name                      = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  vm_zone                      = "3"
  vm_size                      = "Standard_DC1s_v3"
  admin_username               = "azureuser"
  public_key_path              = "/home/endie/.ssh/azure/kubernetes.pub"
  os_disk_storage_account_type = "Standard_LRS"
  image_publisher              = "Canonical"
  image_offer                  = "0001-com-ubuntu-server-jammy"
  image_sku                    = "22_04-lts-gen2"
  image_version                = "latest"
  network_interface_ids        = [azurerm_network_interface.nic-worker-plane-2.id]

}