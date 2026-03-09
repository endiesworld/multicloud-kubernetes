terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}

  subscription_id = "98456b7d-49ec-406e-9c4b-aa98b0232b74"
}