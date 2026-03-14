# Tell Terraform which providers are required, where to get them from, 
#and optionally which Terraform CLI versions are allowed. Terraform uses that during initialization.

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# The provider block is where you configure the settings for the Azure provider, such as authentication details and 
# subscription information.
provider "azurerm" {
  # Configuration options
  features {}

  subscription_id = "98456b7d-49ec-406e-9c4b-aa98b0232b74"
}

# terraform init → download/install provider plugins and initialize the working directory

resource "azurerm_resource_group" "rg" {
  name     = "terraform-vm-rg"
  location = "East US"
}

# azurerm_resource_group.rg.location keeps the VNet in the same Azure region as the Resource Group
# azurerm_resource_group.rg.name attaches the VNet to the correct Resource Group
# creates an explicit reference, so Terraform can infer the dependency: the VNet depends on the Resource Group, so Terraform will create the Resource Group before the VNet.
resource "azurerm_virtual_network" "vnet" {
  name                = "terraform-vm-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# virtual_network_name → which VNet this subnet is carved from
# resource_group_name → which Resource Group contains that VNet
resource "azurerm_subnet" "subnet" {
  name                 = "terraform-vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}


# The public IP address is a resource that can be associated with the VM to allow it to be accessed from the internet.
# A Public IP in Azure is its own resource, so it can be:
# - created and managed independently
# - attached through the NIC
# - preserved or reattached more easily than if it were just an inline VM setting
resource "azurerm_public_ip" "pip" {
  name                = "terraform-vm-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NIC connects the VM to the network. It can be associated with a subnet and a public IP address, 
# allowing the VM to communicate within the VNet and with the internet.
# abstraction
# modularity
# transferability
resource "azurerm_network_interface" "nic" {
  name                = "terraform-vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# NSG is a resource that contains rules to allow or deny network traffic to and from the VM. 
# It can be associated with the subnet or the NIC, providing flexible security management.
resource "azurerm_network_security_group" "nsg" {
  name                = "terraform-vm-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# In Azure, NSG rules are evaluated by priority order. The rule with the lowest priority number is evaluated first. 
# If a rule matches the traffic, the specified action (allow or deny) is applied, and no further rules are evaluated. 
# If no rules match, the default action is to deny the traffic. Therefore, it's important to assign unique priority 
# numbers to each rule to ensure they are evaluated in the correct order. In this example, the SSH rule has a priority of 100,
# which means it will be evaluated before any rules with a higher priority number.
resource "azurerm_network_security_rule" "ssh_rule" {
  name                        = "Allow-SSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "108.35.175.17/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}