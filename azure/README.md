# Terraform for Azure 

This file provides a beginner guide to provisioning resources in azure using Terraform as an IaC tool. 

## prerequiste 

**install terrform and azure CLI**
```text
use this link to install terrafomr: https://developer.hashicorp.com/terraform/tutorials/azure-get-started/install-cli 

use this link to install azure CLI: https://developer.hashicorp.com/terraform/tutorials/azure-get-started/azure-build
```

**create your project directory**
```bash
mkdir terraform-azure-foundation
cd terraform-azure-foundation
```

## The beginner workflow
**The configuration file:** Create the simplest terraform configration file "main.tf"
```hcl
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
}
```
The terraform block defines Terraform settings, including:
- required Terraform CLI version
- required providers
- backend configuration
- determines which plugin is required.
- creates a ".terraform.lock.hcl" file, which terraform uses to enforce the same version accross every contributor's work environment.

The provider block configures it after download.

**Initialize terraform:**
```bash
terraform init
```

## Create First Azure Resource
We would start with the simplest azure resource possible. 
In Azure, every resource must live inside a logical container used for grouping related services together. A Resource Group 📦 acts as a logical folder where you deploy and manage Azure resources like virtual machines, databases, and web apps. Typically, you group items that share the same lifecycle (e.g., all the parts of a "Production Website") so you can delete or monitor them all at once.

However before you can start creatin resources on azure using terraform, you first have to authenticate. 

### Authenticating to Azure
The AzureRM provider supports several authentication methods.

Common ones:

1️⃣ Azure CLI authentication
2️⃣ Service Principal
3️⃣ Managed Identity

from the documentation, the documentation recommends using either a Service Principal or Managed Service Identity when running Terraform non-interactively (such as when running Terraform in a CI server) - and authenticating using the Azure CLI when running Terraform locally.

**Azure CLI authentication:**
Firstly, login to the Azure CLI using a User, Service Principal or Managed Identity. The "best" choice depends entirely on where you are running your Terraform commands.
For Terraform with local development (Your Machine), best Choice: User Account (via az login)
```bash
az login 
# If you are running this in a device without a browser e.g dev container, add "--use-device-code" flag, open the link provided by from the CLI response in the same browser where you have your azure account, then copy and pase the code in the form provide.
```

**See the list of account present:**
```bash
az account list # list the Subscriptions associated with the account via

# output
[
  {
    "cloudName": "AzureCloud",
    "homeTenantId": "8d1thfngio-ae21-4345-03b5-th1234567dgc",
    "id": "8d1thfngio-406e-49ec-9c4b-aa98b0232b74",
    "isDefault": true,
    "managedByTenants": [],
    "name": "Azure subscription 1",
    "state": "Enabled",
    "tenantDefaultDomain": "stevens0.onmicrosoft.com",
    "tenantDisplayName": "stevens.edu",
    "tenantId": "8d1thfngio-ae21--4345-03b5-th1234567dgc",
    "user": {
      "name": "user@example.com",
      "type": "user"
    }
  }
]
```

**Specify the subscription to use as indicated below**
```bash
az account set --subscription="SUBSCRIPTION_ID" # - with the id field being the subscription_id
```


### Creating an Azure resource group.
Terraform defines a general resource block structure:
```hcl
resource "<RESOURCE_TYPE>" "<LOCAL_NAME>" {
  argument = value
}
```
**Each provider defines:**
- Which resources exist
- What arguments they accept
- What attributes they export
Use this documentation link for azure provider https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs.

**Create a resource group:**
```hcl
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}
```

### Creating a VM in azure cloud

Before deploying your infrastructure as code project on azure I recommend that you first identify what region, zones, and resources are availbale for your subsription. Fo this, I recommend this article by Marko Nakic https://markonakic.xyz/posts/list-available-azure/. 

If you are new to azure platform, I recommend that you go through the Azure-README.md file.