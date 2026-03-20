# Terraform Outputs, Locals, Data Sources, and Modules on Azure

Stage 3 moves beyond "parameterized Terraform" and into "structured Terraform."

In Stage 2, the main improvement was introducing input variables so the Azure configuration could be reused with different values. That is an important step, but professional Terraform requires more than inputs. You also need:

- **outputs** to expose useful results
- **locals** to reduce repetition and centralize derived values
- **data sources** to read information that already exists
- **modules** to package infrastructure into reusable building blocks

This stage is where a Terraform project starts to feel like an actual system rather than a single configuration file.

If you have not worked through the earlier Azure stages yet, start with:

- [../stage-1/README.md](../stage-1/README.md)
- [../stage-1/azure-README.md](../stage-1/azure-README.md)
- [../stage-2/README.md](../stage-2/README.md)

---

## What This Stage Teaches

By the end of this stage, you should understand:

- when to use an output and what it exposes
- when a local value is better than repeating literals or expressions
- how a data source differs from a managed resource
- how Terraform modules create reusable interfaces around infrastructure
- how these four concepts work together in a real Azure codebase

The mental shift here is important:

- **variables** are inputs into your Terraform configuration
- **locals** are computed values inside your configuration
- **data sources** read information from outside your configuration
- **outputs** expose information from your configuration
- **modules** package all of that into reusable units

---

## Where Stage 3 Fits in the Learning Path

The progression across the Azure directory is now:

1. Stage 1: Azure fundamentals and the first Terraform configuration
2. Stage 2: input variables and `terraform.tfvars`
3. Stage 3: structure, reuse, and information flow in Terraform

That progression mirrors how many engineers learn Terraform in practice:

1. make it work
2. make it configurable
3. make it maintainable

---

## Outputs

An **output** exposes a value from Terraform after the plan is applied.

Outputs are useful when you want to:

- print important infrastructure values in the CLI
- pass values from one module to another
- expose resource IDs, IP addresses, names, or connection details
- make the result of a deployment easier to inspect

Example:

```hcl
output "public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.pip.ip_address
}
```

This output says:

- after the resources exist
- read the `ip_address` attribute from `azurerm_public_ip.pip`
- expose it as `public_ip`

You can inspect outputs with:

```bash
terraform output
terraform output public_ip
```

### When outputs are useful in Azure

Common Azure examples include:

- VM public IP addresses
- resource group names
- subnet IDs
- virtual network IDs
- network security group IDs
- managed identity principal IDs

### Professional guidance for outputs

Outputs should expose information that is genuinely useful to a human, another module, or downstream automation. They should not dump every attribute from every resource.

Good outputs are:

- intentional
- well named
- documented
- stable

---

## Locals

A **local value** lets you define a named expression inside the configuration.

Locals are useful when you want to:

- avoid repeating the same string or expression in many places
- compute derived values once and reuse them
- centralize naming conventions
- simplify resource blocks

Example:

```hcl
locals {
  name_prefix = "terraform-kubernetes"
  common_tags = {
    environment = "learning"
    managed_by  = "terraform"
    cloud       = "azure"
  }
}
```

You then reference them with:

```hcl
local.name_prefix
local.common_tags
```

### Why locals matter

Suppose you repeat the same naming prefix across your configuration:

```hcl
name = "terraform-kubernetes-rg"
name = "terraform-kubernetes-vnet"
name = "terraform-kubernetes-nsg"
```

That works, but it creates duplication. A local allows you to derive names more cleanly:

```hcl
locals {
  name_prefix = "terraform-kubernetes"
}
```

```hcl
name = "${local.name_prefix}-rg"
name = "${local.name_prefix}-vnet"
name = "${local.name_prefix}-nsg"
```

### Locals vs variables

This distinction matters:

- use a **variable** when the caller should be able to set the value
- use a **local** when the value is derived or internal to the configuration

Example:

- `location` is a good candidate for a variable
- a standardized name prefix derived from a project name is often a good candidate for a local

### Professional guidance for locals

Locals are not just for convenience. They are part of interface design.

A good Terraform codebase pushes external decisions to variables and keeps internal composition in locals.

---

## Data Sources

A **data source** reads information from infrastructure that already exists.

This is different from a `resource` block:

- a `resource` block tells Terraform to create, update, or delete something
- a `data` block tells Terraform to look something up and read it

**Basic Syntax**:

```hcl
data "<PROVIDER_RESOURCE_TYPE>" "<LOCAL_NAME>" {
  # arguments used to look up the existing object
}
```
***Note***: The arguments in a data source are not defining new infrastructure. They are criteria for finding existing infrastructure.
**Example:**

```hcl
data "azurerm_resource_group" "existing_rg" {
  name = "my-existing-rg"
}
```

***Then you can reference it like this:***
```hcl
data.azurerm_resource_group.existing_rg.location
data.azurerm_resource_group.existing_rg.id
```

### Common Azure data source use cases

You use data sources when some infrastructure already exists and Terraform should reference it rather than create it again.
***Common Cases:***
- an existing resource group
- an existing virtual network
- an existing subnet
- the current Azure client configuration
- an existing image or Key Vault

***Example:***
Suppose a resource group already exists in Azure, and you want to create a VNet inside it.

You do not want Terraform to create the resource group again.

You can do this:

```hcl
data "azurerm_resource_group" "rg" {
  name = "shared-network-rg"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "dev-vnet"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}
```
***Note***: For the above example, the resource group `shared-network-rg` must already exist in Azure before you run `terraform apply`. Terraform will read its location and name but will not create it. i.e, 
- `shared-network-rg` is a resource that exists outside of this Terraform configuration
- `shared-network-rg` must be readable/accessible by the credentials Terraform is using

That pattern is common in larger organizations where platform teams create shared resources and application teams consume them.

### Why data sources matter professionally

Real infrastructure is often a mix of:

- resources Terraform manages in the current configuration
- resources managed elsewhere
- resources created by another team or module

Data sources let your Terraform code participate in that reality without pretending it owns everything.

---

## Modules

A **module** is a container for Terraform configuration.

Every Terraform configuration has a **root module**, which is the directory where you run `terraform plan` and `terraform apply`.

Any module you call from that root module is a **child module**.

Modules are useful when you want to:

- reuse the same infrastructure pattern multiple times
- separate concerns
- reduce copy-paste
- define clear inputs and outputs

### A practical Azure example

Your stage-2 configuration already has natural boundaries:

- networking
- security
- compute

That can evolve into modules such as:

```text
azure/stage-3/
├── main.tf
├── variables.tf
├── outputs.tf
├── locals.tf
├── data.tf
├── modules/
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── linux-vm/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── README.md
```

The root module might call a network module like this:

```hcl
module "network" {
  source                    = "./modules/network"
  resource_group_name       = var.resource_group_name
  location                  = var.location
  vnet_name                 = var.vnet_name
  vnet_address_space_cidr   = var.vnet_address_space_cidr
  subnet_name               = var.subnet_name
  subnet_address_space_cidr = var.subnet_address_space_cidr
}
```

Then a VM module could consume outputs from the network module:

```hcl
module "linux_vm" {
  source                    = "./modules/linux-vm"
  resource_group_name       = var.resource_group_name
  location                  = var.location
  nic_name                  = var.nic_name
  subnet_id                 = module.network.subnet_id
  public_ip_name            = var.public_ip_name
  nsg_name                  = var.nsg_name
  ssh_source_ip             = var.ssh_source_ip
  vm_name                   = var.vm_name
  vm_size                   = var.vm_size
  admin_username            = var.admin_username
  public_key_path           = var.public_key_path
  os_disk_storage_account_type = var.os_disk_storage_account_type
  image_publisher           = var.image_publisher
  image_offer               = var.image_offer
  image_sku                 = var.image_sku
  image_version             = var.image_version
}
```

That is where the earlier concepts come together:

- variables define module inputs
- resources create Azure infrastructure
- outputs expose values to callers
- locals simplify repeated internal logic
- data sources let modules consume existing infrastructure when needed

---

## Module Design Principles

A module should not just be a folder full of Terraform. It should have a clear responsibility.

Good module design usually means:

- one module, one main concern
- explicit inputs
- explicit outputs
- minimal hidden assumptions
- no unnecessary leakage of internal details

For this Azure project, natural module boundaries might be:

- `network`
- `security`
- `linux-vm`
- later, `aks`, `load-balancer`, or `monitoring`

### What not to do

Avoid modules that are:

- too tiny to be useful
- too large to understand
- tightly coupled to one caller's naming quirks
- full of environment-specific literals

The goal is not "use modules everywhere." The goal is "use modules when they create a meaningful reusable interface."

---

## How These Concepts Work Together

A mature Terraform flow often looks like this:

1. variables receive external input
2. locals derive internal values
3. data sources read existing state from Azure
4. resources create or modify infrastructure
5. outputs expose useful results
6. modules package the entire pattern for reuse

This is the information flow you should start seeing in your head as you read a Terraform codebase.

---

## Example Refactor Path from Stage 2

If you were evolving the current Azure VM configuration into Stage 3, a sensible path would be:

1. Move the existing `output "public_ip"` into a dedicated `outputs.tf`
2. Introduce `locals.tf` for common naming patterns and tags
3. Introduce `data.tf` for values you want to read instead of hard-code
4. Split networking and VM creation into child modules
5. Keep the root module focused on orchestration rather than low-level resource detail

That is a realistic progression from a learning configuration to a reusable infrastructure layout.

---

## Azure-Specific Examples You Are Likely to Use

### Output example

```hcl
output "vm_id" {
  description = "The resource ID of the Linux VM"
  value       = azurerm_linux_virtual_machine.vm.id
}
```

### Local example

```hcl
locals {
  common_tags = {
    project     = "multicloud-kubernetes"
    environment = "learning"
    provider    = "azure"
  }
}
```

### Data source example

```hcl
data "azurerm_client_config" "current" {}
```

### Module call example

```hcl
module "network" {
  source              = "./modules/network"
  resource_group_name = var.resource_group_name
  location            = var.location
}
```

These are not advanced tricks. They are core Terraform patterns you will see in serious production repositories.

---

## Common Beginner Mistakes in Stage 3

### Treating outputs like logs

Outputs should expose useful interface values, not everything Terraform knows.

### Using locals for user input

If a value should be configurable by the caller, it belongs in a variable, not in `locals`.

### Confusing data sources with resources

A data source reads existing Azure information. It does not create infrastructure.

### Over-modularizing too early

Not every three lines of Terraform deserve their own module. Start with clear boundaries and expand only where reuse or readability improves.

### Building modules with weak interfaces

If a module has vague variable names, undocumented behavior, or missing outputs, it becomes harder to reuse than plain root-module Terraform.

---

## From Beginner to Professional

A beginner learns:

- how to write Terraform blocks
- how to pass variables
- how to create resources

A more advanced practitioner learns:

- how information flows through Terraform
- how to design stable module interfaces
- how to mix managed resources with existing infrastructure
- how to make infrastructure code readable by other engineers

That second level is what Stage 3 is about.

---

## Suggested End State for This Stage

By the time you finish implementing Stage 3, your Azure directory should ideally show these characteristics:

- resource names and tags are centralized with locals where appropriate
- important values are exposed with outputs
- account or platform context is read with data sources when useful
- reusable infrastructure chunks are moved into modules
- the root module reads more like orchestration than raw implementation detail

That is a strong foundation for later work such as:

- turning the VM into a Kubernetes bootstrap node
- introducing multiple nodes
- migrating patterns into reusable multicloud module design
- eventually comparing Azure, AWS, and GCP implementations

---

## Summary

Stage 3 is about Terraform structure.

Outputs, locals, data sources, and modules are not isolated features. Together, they define how a Terraform codebase communicates, avoids duplication, reads existing infrastructure, and scales beyond a single file.

Once you understand these concepts in Azure, you will be in a much stronger position to build reusable multicloud Terraform patterns rather than provider-specific one-offs.
