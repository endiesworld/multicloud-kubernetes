# Terraform Outputs, Locals, and Modules on Azure

Stage 3 moves beyond basic variables and starts teaching how Terraform configurations become easier to read, easier to reuse, and easier to consume.

This stage is implemented in two parts:

- `a` shows **locals** and **outputs** in a single root module
- `b` refactors that same infrastructure into a reusable **module** and then exposes module outputs from the root module

That progression matters. Before splitting code into modules, it helps to understand how Terraform values flow inside one configuration. After that, modules become much easier to reason about.

If you have not completed the earlier Azure stages yet, start with:

- [../stage-1/README.md](../stage-1/README.md)
- [../stage-1/azure-README.md](../stage-1/azure-README.md)
- [../stage-2/README.md](../stage-2/README.md)

---

## What This Stage Teaches

By the end of this stage, you should understand:

- how `locals` reduce repetition in Terraform
- how `output` blocks expose useful infrastructure values
- what a Terraform data source is and when you would use one
- how a root module differs from a child module
- how to call the same module multiple times with different inputs
- why child-module outputs must be re-exposed at the root if you want `terraform output` to show them

This stage does **not** yet include a concrete Azure data source example in `a` or `b`. The practical implementation focus here is locals, outputs, and modules, while the data source section below is included for conceptual grounding.

---

## Directory Layout

```text
azure/stage-3/
├── README.md
├── a/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
└── b/
    ├── main.tf
    ├── outputs.tf
    └── modules/
        └── vm-infrastructure/
            ├── main.tf
            ├── variables.tf
            └── outputs.tf
```

Think of the two subdirectories like this:

- `a` = learn the concepts in one place
- `b` = package the same idea into a reusable module

---

## Part A: Locals and Outputs in a Single Configuration

The `a` directory keeps everything in one root module.

It creates:

- a resource group
- a virtual network
- a subnet
- a public IP
- a network security group
- a network interface
- a Linux VM

The important Stage 3 addition is not the Azure resource list. It is the introduction of **locals** and **outputs**.

### Locals in `a`

In [main.tf](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/a/main.tf#L15), the configuration defines local values such as:

- `resource_prefix`
- `rg_name`
- `vnet_name`
- `subnet_name`
- `ip_name`
- `nsg_name`
- `nic_name`
- `vm_name`

Example:

```hcl
locals {
  resource_prefix = "${var.environment}-demo"
  rg_name         = "${local.resource_prefix}-rg"
  vnet_name       = "${local.resource_prefix}-vnet"
  subnet_name     = "${local.resource_prefix}-subnet"
}
```

This teaches an important Terraform habit:

- accept external inputs with variables
- derive internal naming and repeated expressions with locals

Instead of writing resource names manually in every resource block, the configuration builds names once and reuses them everywhere.

### Why this is better than hard-coded names

Without locals, your resource blocks fill up with repeated strings. With locals:

- naming becomes consistent
- changing a naming pattern is easier
- the resource blocks become easier to read
- the configuration starts to look like infrastructure logic rather than string repetition

### Outputs in `a`

In [outputs.tf](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/a/outputs.tf#L1), the configuration exposes the VM public IP:

```hcl
output "public_ip" {
  description = "The public IP address of the virtual machine."
  value       = azurerm_public_ip.pip.ip_address
}
```

That output lets you retrieve the public IP after apply:

```bash
terraform output
terraform output public_ip
```

This is the first place where Stage 3 starts teaching Terraform information flow:

- resources create infrastructure
- outputs expose useful results from that infrastructure

### Variables still matter in `a`

The values in [variables.tf](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/a/variables.tf) and [terraform.tfvars](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/a/terraform.tfvars) still provide the external inputs, such as:

- `environment`
- `location`
- network CIDR ranges
- VM size
- SSH key path

So `a` teaches a full chain:

1. variables receive input
2. locals derive internal names
3. resources create Azure infrastructure
4. outputs expose useful values

That is the right foundation before introducing modules.

---

## Data Sources

A **data source** reads information about infrastructure that already exists.

This is different from a `resource` block:

- a `resource` block creates, updates, or deletes infrastructure
- a `data` block looks up infrastructure and reads its attributes

Basic example:

```hcl
data "azurerm_resource_group" "existing" {
  name = "shared-network-rg"
}
```

You can then reference that existing object like this:

```hcl
data.azurerm_resource_group.existing.name
data.azurerm_resource_group.existing.location
data.azurerm_resource_group.existing.id
```

### Why data sources matter

Real Terraform projects often need to work with infrastructure that is not created by the current configuration.

Common examples include:

- an existing resource group
- an existing virtual network
- an existing subnet
- the currently authenticated Azure account context
- a shared Key Vault or image

That is where data sources become important. They allow your Terraform code to consume existing Azure information without trying to recreate it.

### Azure example

Suppose a networking team already created a resource group and you want your Terraform configuration to create resources inside it:

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

In that case:

- Terraform reads the existing resource group
- Terraform does not create the resource group
- Terraform uses the existing group's attributes to place new resources correctly

### Important note for this stage

The `a` and `b` examples in this stage do not yet implement a live Azure data source. They are included here for information and for the mental model you will need as your Terraform project becomes more realistic.

---

## Part B: Turning the VM Stack into a Reusable Module

The `b` directory takes the same basic infrastructure pattern and packages it into a child module:

- [main.tf](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/b/modules/vm-infrastructure/main.tf)
- [variables.tf](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/b/modules/vm-infrastructure/variables.tf)
- [outputs.tf](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/b/modules/vm-infrastructure/outputs.tf)

This is the point where Terraform starts looking more like reusable engineering and less like a single folder of resources.

### Root module vs child module

In `b`, the directory itself is the **root module**. That is where you run:

- `terraform init`
- `terraform plan`
- `terraform apply`

Inside `b/modules/vm-infrastructure/` is the **child module**.

The child module contains the actual Azure resources. The root module calls it.

### Calling the module

In [main.tf](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/b/main.tf#L15), the root module calls the child module once:

```hcl
module "terraform-vm" {
  source       = "./modules/vm-infrastructure"
  project_name = "terraform-vm"
  environment  = "dev"
  location     = "East US"
  ...
}
```

Then it calls the same module again in [main.tf](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/b/main.tf#L33):

```hcl
module "second-terraform-vm" {
  source       = "./modules/vm-infrastructure"
  project_name = "second-terraform-vm"
  environment  = "dev"
  location     = "East US"
  ...
}
```

This is one of the most important Terraform ideas:

- one module defines a reusable infrastructure pattern
- many module blocks can instantiate that pattern with different inputs

In this case, changing `project_name` changes the naming prefix, which allows a second independent VM stack to be created.

### Locals still exist inside the module

The child module in [main.tf](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/b/modules/vm-infrastructure/main.tf#L2) still uses locals to derive names:

```hcl
locals {
  az_project_name = var.project_name
  resource_prefix = "${local.az_project_name}-${var.environment}"
  rg_name         = "${local.resource_prefix}-rg"
  vnet_name       = "${local.resource_prefix}-vnet"
  subnet_name     = "${local.resource_prefix}-subnet"
}
```

That shows an important design pattern:

- variables define the module interface
- locals define the module's internal composition

The caller decides the high-level input values. The module decides how to turn those inputs into internal resource names and resource relationships.

### Module outputs

The child module exposes its public IP in [outputs.tf](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/b/modules/vm-infrastructure/outputs.tf#L1):

```hcl
output "public_ip" {
  description = "The public IP address of the virtual machine."
  value       = azurerm_public_ip.pip.ip_address
}
```

That means each module instance produces a `public_ip` value.

Conceptually, the root module can access them as:

- `module.terraform-vm.public_ip`
- `module.second-terraform-vm.public_ip`

---

## Why the Root `outputs.tf` in `b` Matters

One of the easiest mistakes when first learning modules is expecting Terraform to print child-module outputs automatically.

It does not.

`terraform output` shows only **root module outputs**.

That is why `b` includes [outputs.tf](/home/endie/Projects/Kubernetes/Multicloud-kubernetes/azure/stage-3/b/outputs.tf#L1):

```hcl
output "terraform_vm_public_ip" {
  description = "The public IP address of the first VM module."
  value       = module.terraform-vm.public_ip
}

output "second_terraform_vm_public_ip" {
  description = "The public IP address of the second VM module."
  value       = module.second-terraform-vm.public_ip
}
```

This file re-exposes child-module outputs at the root level.

That is why, after a successful apply, these commands work from `azure/stage-3/b`:

```bash
terraform output
terraform output terraform_vm_public_ip
terraform output second_terraform_vm_public_ip
```

This is a critical professional concept:

- child modules can produce outputs for their callers
- root modules decide which of those values should be exposed to operators or downstream tooling

---

## The Main Learning Progression from A to B

The movement from `a` to `b` is the real lesson of Stage 3.

### In `a`

You learn how to organize one Terraform configuration with:

- variables for external inputs
- locals for internal naming
- outputs for useful results

### In `b`

You learn how to package that pattern into a reusable module and instantiate it more than once.

That is how Terraform evolves in real projects:

1. write one working configuration
2. reduce repetition with locals
3. expose useful values with outputs
4. package the pattern into a module
5. call the module multiple times from a root module

That sequence is much easier to understand than jumping straight into modules on day one.

---

## How to Run Part A

From `azure/stage-3/a`:

```bash
terraform init
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

Then inspect the output:

```bash
terraform output
terraform output public_ip
```

To destroy the infrastructure:

```bash
terraform plan -destroy -out destroy.tfplan
terraform apply destroy.tfplan
```

---

## How to Run Part B

From `azure/stage-3/b`:

```bash
terraform init
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

Then inspect the root outputs:

```bash
terraform output
terraform output terraform_vm_public_ip
terraform output second_terraform_vm_public_ip
```

To destroy the infrastructure:

```bash
terraform plan -destroy -out destroy.tfplan
terraform apply destroy.tfplan
```

---

## Beginner to Professional Takeaways

At a beginner level, Stage 3 teaches:

- how to use locals instead of repeating strings
- how to read output values after apply
- how a module call works

At a more professional level, Stage 3 teaches interface design:

- variables are the module inputs
- locals are the module's internal wiring
- outputs are the module's public results
- the root module is responsible for orchestration and for deciding what to expose

That is the real value of this stage. You are no longer only writing Terraform resources. You are starting to design Terraform structure.

---

## Summary

Stage 3 is about making Terraform easier to reason about and easier to reuse.

Part `a` shows how locals and outputs improve a single Azure VM configuration.

Part `b` takes that same pattern and turns it into a reusable module that can be instantiated multiple times, while teaching the important distinction between child-module outputs and root-module outputs.

Once this stage feels natural, you are in a much stronger position to build larger Azure layouts and eventually repeat the same design ideas across AWS and GCP in a true multicloud Terraform project.
