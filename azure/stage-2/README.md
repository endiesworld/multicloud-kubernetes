# Terraform Variables on Azure

Stage 2 builds on Stage 1 by introducing **input variables** in Terraform.

In Stage 1, values such as names, locations, and VM settings could be written directly inside `main.tf`. That works for a first exercise, but it does not scale. As soon as you want to reuse the same configuration in a different region, for another environment, or with a different VM size, hard-coded values become friction.

Terraform variables solve that problem by separating:

- **configuration logic** from
- **environment-specific values**

This is one of the first steps from "Terraform that works once" to "Terraform that can be reused and maintained."

If you are still getting comfortable with Azure concepts such as subscriptions, resource groups, regions, and quotas, read [../stage-1/README.md](../stage-1/README.md) and [../stage-1/azure-README.md](../stage-1/azure-README.md) first.

---

## What This Stage Teaches

By the end of this stage, you should understand:

- what a Terraform variable is
- how to declare variables with `type`, `description`, and `default`
- how to supply variable values through `terraform.tfvars`
- how Terraform references variables with `var.<name>`
- why variables matter for reuse, consistency, and safer infrastructure changes

This stage deploys the same Azure resources as before, but now the configuration is parameterized.

---

## Project Files in This Stage

```text
azure/stage-2/
├── main.tf           # Azure resources that consume input variables
├── varable.tf        # Variable declarations for the configuration
├── terraform.tfvars  # Concrete values for this environment
├── tfplan            # Saved execution plan
├── destroy.tfplan    # Saved destroy plan
└── README.md
```

> **Note:** The conventional Terraform filename is `variables.tf`. In this stage, the file is named `varable.tf`. Terraform does not care about the filename as long as it ends in `.tf`, because it loads all `.tf` files in the working directory.

---

## Why Variables Matter

Without variables, you might write a resource like this:

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "terraform-kubernetes-rg"
  location = "East US"
}
```

That is valid Terraform, but it hard-codes deployment choices into the configuration itself.

With variables, the same resource becomes:

```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}
```

Now the resource definition stays stable, while the values can change per environment.

That gives you practical benefits:

- reuse the same configuration in `dev`, `test`, and `prod`
- change names and regions without rewriting resource blocks
- reduce copy-paste infrastructure code
- make the intent of the configuration clearer
- prepare the codebase for modules later

Variables are a core part of writing Terraform like an engineer rather than like a one-off script author.

---

## How Terraform Variables Work

A variable is declared with a `variable` block:

```hcl
variable "location" {
  description = "The region where the resource group will be deployed to"
  type        = string
}
```

This does **not** create any Azure resource. It tells Terraform:

- the variable name is `location`
- the expected type is `string`
- the variable has a human-readable description

You then reference the variable elsewhere using:

```hcl
var.location
```

The general pattern is:

```hcl
variable "name_of_variable" {
  description = "What this value is for"
  type        = string
  default     = "optional-default"
}
```

---

## Variable Declarations in This Stage

This stage declares variables for the main parts of the Azure build:

- resource group name and Azure location
- virtual network name and address space
- subnet name and subnet CIDR
- public IP, NIC, and NSG names
- SSH source IP restriction
- VM name, size, zone, and admin username
- OS disk type
- image publisher, offer, SKU, and version
- SSH public key path

Some variables have **no default**:

- `resource_group_name`
- `location`
- `vnet_name`
- `vnet_address_space_cidr`
- `subnet_name`
- `subnet_address_space_cidr`
- `public_ip_name`
- `nic_name`
- `nsg_name`
- `ssh_source_ip`

These are required inputs. Terraform will ask for them if you do not provide values elsewhere.

Other variables do have defaults, for example:

- `vm_size`
- `admin_username`
- `vm_name`
- `vm_zone`
- `os_disk_storage_account_type`
- image settings
- `public_key_path`

Defaults make sense when you want a sensible baseline but still want the option to override it later.

---

## Terraform Types in This Stage

The configuration uses Terraform's type system to constrain input values.

### `string`

Used for single text values such as:

- Azure region
- VM size
- usernames
- file paths

Example:

```hcl
variable "vm_name" {
  description = "The name of the virtual machine to create."
  type        = string
  default     = "terraform-kubernetes-vm"
}
```

### `list(string)`

Used when Terraform expects multiple string values in a list.

Example:

```hcl
variable "vnet_address_space_cidr" {
  description = "The address space in CIDR notation for the virtual network."
  type        = list(string)
}
```

That matches how Azure resources expect these arguments:

```hcl
address_space   = var.vnet_address_space_cidr
address_prefixes = var.subnet_address_space_cidr
```

Even if you currently pass only one CIDR block, the Azure resource schema still expects a list.

---

## Supplying Values with `terraform.tfvars`

In this stage, concrete values are stored in `terraform.tfvars`:

```hcl
resource_group_name       = "terraform-kubernetes-rg"
location                  = "East US"
vnet_name                 = "terraform-kubernetes-vnet"
vnet_address_space_cidr   = ["10.0.0.0/16"]
subnet_name               = "terraform-kubernetes-name"
subnet_address_space_cidr = ["10.0.1.0/24"]
public_ip_name            = "terraform-kubernetes-public-ip"
nic_name                  = "terraform-kubernetes-n-interface-card"
nsg_name                  = "terraform-kubernetes-nsg"
ssh_source_ip             = "108.35.175.17/32"
```

`terraform.tfvars` is automatically loaded by Terraform, so you usually do not need to pass each value on the command line.

This gives you a clean separation:

- `varable.tf` declares what inputs exist
- `terraform.tfvars` provides values for this environment
- `main.tf` uses those values to build Azure resources

---

## How the Variables Flow Through the Configuration

The flow in this stage is:

1. A variable is declared in `varable.tf`
2. A value is assigned in `terraform.tfvars` or a default is used
3. A resource in `main.tf` references that value using `var.<name>`
4. Terraform builds a dependency graph and plans the Azure deployment

Example:

```hcl
variable "public_ip_name" {
  description = "The name of the public IP address to create."
  type        = string
}
```

```hcl
public_ip_name = "terraform-kubernetes-public-ip"
```

```hcl
resource "azurerm_public_ip" "pip" {
  name                = var.public_ip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
```

That is the core Terraform workflow: declare, assign, consume.

---

## Running This Stage

From the `azure/stage-2` directory:

```bash
terraform init
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

To destroy the resources later:

```bash
terraform plan -destroy -out destroy.tfplan
terraform apply destroy.tfplan
```

Before planning or applying, make sure you are authenticated to Azure:

```bash
az login
az account show -o table
```

If needed, switch to the correct subscription:

```bash
az account set --subscription "SUBSCRIPTION_ID_OR_NAME"
```

---

## Important Observations About This Stage

This stage is about variables, but it also teaches some professional habits indirectly.

### 1. Resource definitions become easier to read

When values are moved out of resource blocks, `main.tf` reads more like infrastructure logic and less like a wall of hard-coded strings.

### 2. The same code can be reused

You can keep one Terraform configuration and swap in different values for:

- different Azure regions
- different naming conventions
- different VM sizes
- different SSH access ranges

### 3. Defaults should be intentional

Defaults are useful for stable baselines. They are risky when they hide environment-specific assumptions.

For example:

- `admin_username = "azureuser"` is a reasonable default
- `vm_size = "Standard_DC1s_v3"` is acceptable for a guided exercise
- `ssh_source_ip` should usually **not** have a default because it is security-sensitive

That design choice is visible in this stage.

---

## Variable Value Precedence

Terraform can receive variable values from several places. In practice, beginners should know the **highest-to-lowest** precedence order conceptually:

1. command-line flags such as `-var` and `-var-file`
2. automatically loaded variable definition files such as `terraform.tfvars`
3. environment variables such as `TF_VAR_location`
4. `default` values in the variable block

For this stage, `terraform.tfvars` is the main value source, while defaults handle the stable VM/image settings.

---

## Security and Maintainability Notes

This repository stage is educational, but it is worth calling out a few professional best practices early.

### Do not commit secrets into `terraform.tfvars`

`terraform.tfvars` often contains environment-specific values. It should not contain:

- passwords
- private keys
- client secrets
- tokens

This stage uses an SSH public key path, which is acceptable because the public key is not secret.

### Be careful with hard-coded subscription IDs

`main.tf` currently sets:

```hcl
subscription_id = "98456b7d-49ec-406e-9c4b-aa98b0232b74"
```

That works for a personal learning environment, but a more reusable pattern is to avoid hard-coding account-specific identifiers in the provider configuration unless there is a strong reason to pin them. Later, you may want to parameterize this as well.

### Restrict SSH access narrowly

This stage uses:

```hcl
source_address_prefix = var.ssh_source_ip
```

That is better than opening SSH to the world with `0.0.0.0/0`. The professional habit is to restrict SSH to your own public IP or a trusted bastion range.

---

## Common Beginner Mistakes with Variables

### Forgetting to provide required variables

If a variable has no default and no supplied value, Terraform will prompt for it or fail in automation.

### Using the wrong type

If Azure expects a list of strings and you provide a plain string, Terraform will reject the configuration during validation or planning.

### Confusing Terraform variable names with Azure resource names

This:

```hcl
variable "resource_group_name" { ... }
```

is a Terraform input variable.

This:

```hcl
resource "azurerm_resource_group" "rg" { ... }
```

is an Azure resource managed by Terraform.

They are related, but they are not the same thing.

### Storing machine-specific paths without thinking about portability

This stage uses a local path for the SSH public key:

```hcl
default = "/home/endie/.ssh/azure/kubernetes.pub"
```

That is fine for a single machine, but shared projects usually parameterize or document such paths carefully because another user may not have the same directory structure.

---

## From Beginner to Professional

At a beginner level, variables help you avoid rewriting the same values.

At a professional level, variables help you design Terraform interfaces.

That means asking:

- Which values should callers be allowed to change?
- Which values should have safe defaults?
- Which values should be required?
- Which values are environment-specific?
- Which values are security-sensitive?

Once you start thinking that way, you are no longer just writing Terraform files. You are designing maintainable infrastructure code.

---

## What Comes Next

The next stage introduces:

- **outputs** to expose useful values from your configuration
- **locals** to avoid repeating derived values
- **data sources** to read information from existing infrastructure
- **modules** to package Terraform code into reusable building blocks

Variables are the foundation for all of those. Modules, in particular, depend heavily on well-designed input variables and outputs.

---

## Summary

Stage 2 teaches one of the most important Terraform habits: parameterize your infrastructure.

Instead of embedding every deployment decision directly into resource blocks, you define inputs, provide values, and let Terraform build from those inputs. That makes your Azure code easier to reuse, easier to read, and easier to evolve as the project grows from a learning exercise into a more professional codebase.
