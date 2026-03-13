# Terraform for Azure

This guide walks a beginner through provisioning Azure infrastructure using Terraform as an IaC tool.

**Read [azure-README.md](./azure-README.md) first** if you are new to Azure. It explains the core concepts (subscriptions, resource groups, regions, quotas) that you need to understand before writing any Terraform code.

---

## Prerequisites

**Install Terraform and Azure CLI**

```text
Terraform install guide: https://developer.hashicorp.com/terraform/install
Azure CLI install guide:  https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
```

**Create your project directory**

```bash
mkdir terraform-azure-foundation
cd terraform-azure-foundation
```

---

## File Structure

A well-organized Terraform project for Azure uses this layout:

```text
terraform-azure-foundation/
├── main.tf             # Resource definitions
├── variables.tf        # Variable declarations
├── outputs.tf          # Output value declarations
├── terraform.tfvars    # Variable values (do not commit secrets)
├── .terraform/         # Downloaded provider plugins (auto-generated, do not commit)
├── .terraform.lock.hcl # Provider version lock file (commit this)
└── README.md
```

---

## The Beginner Workflow

### 1. Create the configuration file

Create `main.tf` with the minimal provider configuration:

```hcl
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
}
```

**The `terraform` block** defines settings that apply to the whole configuration:
- `required_providers` — declares which provider plugins Terraform needs and pins their versions
- `version = "~> 4.0"` — allows any 4.x release but not 5.0+
- After `terraform init`, Terraform writes a `.terraform.lock.hcl` file that locks provider versions so every contributor uses the same one

**The `provider "azurerm"` block** configures the downloaded provider. The `features {}` block is required by the `azurerm` provider even when left empty — omitting it will cause `terraform plan` and `terraform apply` to fail. It controls optional provider-level behaviors that you can set later as you advance.

### 2. Initialize Terraform

```bash
terraform init
```

This downloads the `azurerm` provider plugin into `.terraform/` and writes the `.terraform.lock.hcl` lock file.

---

## Authenticate to Azure

Before creating any resources, Terraform needs credentials to communicate with Azure. The `azurerm` provider supports several authentication methods.

| Method | When to use |
|--------|-------------|
| Azure CLI (`az login`) | Local development on your machine |
| Service Principal | CI/CD pipelines and automated runs |
| Managed Identity | Code running inside Azure (e.g., a VM or GitHub Actions with Azure OIDC) |

### Azure CLI authentication (recommended for local development)

```bash
az login
# If you are in an environment without a browser (e.g., a dev container), use:
az login --use-device-code
# Open the URL printed in the terminal in a browser where your Azure account is logged in,
# then paste the code shown in the terminal into the form.
```

**Verify and select your subscription:**

```bash
az account list -o table   # list all subscriptions linked to your account
az account show -o table   # show the currently active subscription
```

Example output from `az account list`:

```json
[
  {
    "cloudName": "AzureCloud",
    "homeTenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "isDefault": true,
    "name": "Azure subscription 1",
    "state": "Enabled",
    "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "user": {
      "name": "user@example.com",
      "type": "user"
    }
  }
]
```

**Set the active subscription:**

```bash
az account set --subscription "SUBSCRIPTION_ID_OR_NAME"
```

---

## Create Your First Azure Resources

### How Terraform resource blocks work

Terraform uses a consistent resource block structure across all providers:

```hcl
resource "<RESOURCE_TYPE>" "<LOCAL_NAME>" {
  argument = value
}
```

- `RESOURCE_TYPE` — the Azure resource to create (e.g., `azurerm_resource_group`)
- `LOCAL_NAME` — a name you choose, used only inside your Terraform code to reference this resource

Each provider defines which resource types exist, what arguments they accept, and what attributes they export. The full Azure provider reference is at:
`https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs`

### Resource group

Every Azure resource must live inside a resource group — a logical container for grouping related services. Think of it as a project folder: everything for one application lives in one resource group so you can monitor, manage, and delete it all together.

```hcl
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "eastus"
}
```

### Creating a VM in Azure

Deploying a VM requires several supporting resources in this order:

1. Resource group (already created above)
2. Virtual network
3. Subnet
4. Network interface
5. Virtual machine

**Before deploying, identify what is available for your subscription and region.** See [azure-README.md](./azure-README.md) for the full pre-flight checklist and the article by Marko Nakic at `https://markonakic.xyz/posts/list-available-azure/`.

#### Virtual network and subnet

```hcl
resource "azurerm_virtual_network" "example" {
  name                = "example-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}
```

Notice `azurerm_resource_group.example.location` — this is how you reference an attribute from another resource. The format is `<RESOURCE_TYPE>.<LOCAL_NAME>.<ATTRIBUTE>`. Terraform automatically infers the dependency and creates the resource group before the network.

#### Network interface

```hcl
resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}
```

#### Linux virtual machine

```hcl
resource "azurerm_linux_virtual_machine" "example" {
  name                = "example-vm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"

  network_interface_ids = [azurerm_network_interface.example.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
```

**Key points:**
- Use SSH keys instead of passwords — it is the more secure and standard approach on Linux VMs
- `Standard_B1s` is one of the smallest and cheapest VM sizes, suitable for learning
- `22_04-lts` is Ubuntu 22.04 LTS (long-term support), currently maintained and widely available

**Check SKU availability and quota before applying:**

```bash
az vm list-skus -l eastus --resource-type virtualMachines -o table
az vm list-usage --location eastus -o table
```

### Deploy

```bash
terraform plan    # preview what will be created
terraform apply   # create the resources
terraform destroy # tear everything down when done
```

---

## Terraform Variables

Variables let you parameterize your configuration so it can be reused across different environments without changing the code itself.

A variable name identifies an input value to the Terraform configuration. A resource local name identifies a specific infrastructure object managed by Terraform. They are different things.

### 1. Defining variables

Declare variables in `variables.tf`. The format is:

```hcl
variable "<VARIABLE_NAME>" {
  description = "A brief description of the variable"
  type        = <TYPE>          # string, number, bool, list, map
  default     = <DEFAULT_VALUE> # optional
}
```

Example `variables.tf`:

```hcl
variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "my-resource-group"
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "eastus"
}

variable "vm_size" {
  description = "The size of the virtual machine"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "The admin username for the virtual machine"
  type        = string
  default     = "adminuser"
}

variable "vm_name" {
  description = "The name of the virtual machine"
  type        = string
  default     = "my-vm"
}
```

**For sensitive values, never set a default.** Mark them `sensitive = true` so Terraform masks the value in all output:

```hcl
variable "admin_password" {
  description = "The admin password for the virtual machine"
  type        = string
  sensitive   = true
}
```

### 2. Using variables

Reference variables in resource blocks using `var.<VARIABLE_NAME>`:

```hcl
resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = var.vm_name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  size                = var.vm_size
  admin_username      = var.admin_username
  # ...
}
```

### 3. Providing variable values

**Default values** — set in the variable block, used when nothing else is provided.

**Command line** — override at runtime using `-var`:

```bash
terraform apply -var="resource_group_name=my-custom-rg" -var="location=eastus"
```

**Variable file** — create `terraform.tfvars`:

```hcl
resource_group_name = "my-custom-rg"
location            = "eastus"
vm_size             = "Standard_DS2_v2"
admin_username      = "customadmin"
vm_name             = "custom-vm"
```

Terraform automatically loads `terraform.tfvars` when you run `terraform apply`. For sensitive variables with no default and no value in the file, Terraform prompts you interactively.

> **Security:** Never commit `terraform.tfvars` if it contains secrets. Add it to `.gitignore`.

### 4. Variable validation

Validation rules let you catch invalid values before Terraform contacts Azure:

```hcl
variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "eastus"

  validation {
    condition     = contains(["eastus", "westus", "westeurope", "uksouth"], var.location)
    error_message = "Location must be one of: eastus, westus, westeurope, uksouth."
  }
}
```

---

## Outputs

Outputs expose values from your Terraform state after a deployment — for example, to retrieve a VM's private IP or a resource group name for use in scripts.

Define outputs in `outputs.tf`:

```hcl
output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.example.name
}

output "vm_private_ip" {
  description = "The private IP address of the VM"
  value       = azurerm_network_interface.example.private_ip_address
}
```

After `terraform apply`, outputs are printed to the terminal. Query them at any time with:

```bash
terraform output
terraform output vm_private_ip
```
