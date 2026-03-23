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
  subscription_id = "98456b7d-49ec-406e-9c4b-aa98b0232b74"
}

module "terraform-vm" {
  source                    = "./modules/vm-infrastructure"
  project_name              = "terraform-vm"
  environment               = "dev"
  location                  = "East US"
  vnet_name                 = "terraform-kubernetes-vnet"
  vnet_address_space_cidr   = ["10.0.0.0/16"]
  subnet_name               = "terraform-kubernetes-name"
  subnet_address_space_cidr = ["10.0.1.0/24"]
  public_ip_name            = "terraform-kubernetes-public-ip"
  nic_name                  = "terraform-kubernetes-n-interface-card"
  nsg_name                  = "terraform-kubernetes-nsg"
  ssh_source_ip             = "108.35.175.17/32"
  public_key_path           = "/home/endie/.ssh/azure/kubernetes.pub"

}


module "second-terraform-vm" {
  source                    = "./modules/vm-infrastructure"
  project_name              = "second-terraform-vm"
  environment               = "dev"
  location                  = "East US"
  vnet_name                 = "terraform-kubernetes-vnet"
  vnet_address_space_cidr   = ["10.0.0.0/16"]
  subnet_name               = "terraform-kubernetes-name"
  subnet_address_space_cidr = ["10.0.1.0/24"]
  public_ip_name            = "terraform-kubernetes-public-ip"
  nic_name                  = "terraform-kubernetes-n-interface-card"
  nsg_name                  = "terraform-kubernetes-nsg"
  ssh_source_ip             = "108.35.175.17/32"
  public_key_path           = "/home/endie/.ssh/azure/kubernetes.pub"

}