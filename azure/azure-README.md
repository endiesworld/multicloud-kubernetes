# The Azure Mental Model

Before writing any Terraform code for Azure, you need to understand how Azure organizes resources. This document explains the key concepts and how they map to AWS if you have that background.

Azure resources exist within a hierarchy:

```
Tenant → Management Group → Subscription → Resource Group → Resource
```

All of these concepts affect what Terraform can do and where it deploys.

---

## Azure Resource Manager (ARM)

Often called ARM, the Azure Resource Manager is the deployment and management layer for Azure. It is the control plane that handles all create, update, and delete operations on resources. When Terraform talks to Azure, it goes through ARM.

---

## Tenant

The tenant is the top-level identity boundary for your organization. In practice, it is tied to Microsoft Entra ID (formerly Azure Active Directory). Many subscriptions can exist under one tenant. Management groups live above subscriptions inside this hierarchy.

---

## Management Group

A management group is a container for subscriptions. It allows you to manage access, policies, and compliance across multiple subscriptions at once. You can have multiple management groups in a tenant, and they can be nested.

---

## Subscription

A subscription is the main boundary for:
- billing
- quotas
- permissions
- resource deployment context

When you run Azure CLI commands, many of them act against the currently active subscription.

**AWS equivalent:** The closest AWS equivalent is an AWS account. A useful first mapping is:

```
Azure Subscription ≈ AWS Account
```

That is not a perfect one-to-one match, but for Terraform and day-to-day work it is close enough.

**Why it matters for Terraform:** When Terraform deploys to Azure, it must know which subscription to target. That determines:
- what resources you are allowed to create
- which regions you can use
- your quotas
- your costs

So before `terraform apply`, one of the first things to confirm is: "Which subscription am I targeting?"

**Azure CLI commands:**

```bash
# Show the current subscription
az account show -o table

# List all subscriptions
az account list -o table

# Switch to a different subscription
az account set --subscription "Subscription Name or ID"
```

---

## Resource Group

A resource group is a logical container for Azure resources. When you create a resource in Azure, you must assign it to a resource group. Think of it as a project folder: a VM, its NIC, its public IP, and its disk may all live in one resource group, making it easy to manage and monitor them as a unit.

**AWS equivalent:** There is no perfect AWS equivalent. The closest combination is:
- AWS CloudFormation Stack (for grouping related resources together)
- AWS Resource Groups (for logical grouping and management)

> **Note:** AWS Resource Groups are a management overlay and do not affect how resources are created or billed. Azure Resource Groups are fundamental to resource organization — a resource cannot exist outside one.

**Why it matters for Terraform:** In Azure, most resources require a resource group, a subscription, and a region before they can be created. That is why Azure Terraform examples almost always start with a resource group.

A practical naming approach: if your app is called `myapp-dev`, you might create:
- Subscription: Dev Subscription
- Resource Group: `myapp-dev-rg`

Then put all related resources inside it:
- virtual network
- subnet
- network security group
- public IP
- VM

**Azure CLI example:**

```bash
az group create --name myapp-dev-rg --location eastus
```

---

## Azure Resource

A resource is the actual service or component you want to create, such as a virtual machine, storage account, or database. Resources are created inside resource groups and are the building blocks of your Azure infrastructure.

Each resource has a type, such as `Microsoft.Compute/virtualMachines` for a VM or `Microsoft.Storage/storageAccounts` for a storage account.

**AWS equivalent:** Azure Resource ≈ AWS Resource

```
Azure Virtual Machine    ↔  AWS EC2 Instance
Azure Storage Account    ↔  AWS S3 Bucket
Azure SQL Database       ↔  AWS RDS Instance
```

---

## Azure Region / Location

A region is the geographic area where you deploy a resource, such as `eastus`, `westus3`, or `uksouth`. In Azure CLI and Terraform you will often see the word `location` — for most beginner work, `location` and `region` mean the same thing.

**AWS equivalent:** Azure Region / Location ≈ AWS Region

```
Azure eastus   ↔  AWS us-east-1
Azure uksouth  ↔  AWS eu-west-2  (similar concept, not geographically identical)
```

**Why it matters for Terraform:** When Terraform creates a resource in Azure, most resources require a `location`. That determines:
- where the resource runs
- where latency comes from
- pricing and availability differences
- which VM sizes exist there
- whether availability zones are available there

A common beginner question before `terraform apply` is: "Which Azure region should I deploy into?"

**Azure CLI examples:**

```bash
# List available regions for your subscription
az account list-locations -o table

# Create a resource group in a specific region
az group create --name myapp-dev-rg --location eastus

# Create a resource group in a specific subscription and region
az group create --name demo-rg --subscription "Subscription Name or ID" --location eastus
```

> **Note:** Azure CLI commands support a `--subscription` flag to target a specific subscription for that command. If omitted, it uses the currently active subscription.

> **Note:** A resource group has a location, but resources inside it can sometimes be deployed in different regions. Azure stores resource-group metadata in that location, while individual resources can vary. Microsoft notes that resources in a resource group can be in different regions.

---

## Azure Availability Zone

An availability zone is a physically separate zone within an Azure region. Each zone has its own power, cooling, and networking. Deploying resources across multiple zones protects your applications from single-datacenter failures. Not all regions support availability zones.

**AWS equivalent:** Azure Availability Zone ≈ AWS Availability Zone

```
Azure eastus   →  zones 1, 2, 3
AWS us-east-1  →  zones a, b, c, d, e, f
```

---

## Azure SKU

A SKU (Stock Keeping Unit) identifies a specific size, tier, or edition of a resource — not the resource itself. When creating resources in Azure, you specify the SKU to determine the performance, capacity, and features of that resource.

**AWS equivalent:** Azure SKU ≈ AWS Instance Type / Storage Class

```
Azure Standard_D2s_v3  ↔  AWS t3.medium
Azure Premium_LRS      ↔  AWS gp2
```

---

## Azure Resource Provider

A resource provider is a service that offers a set of resources in Azure. Each provider has a namespace, such as `Microsoft.Compute` for virtual machines or `Microsoft.Storage` for storage accounts. When you create a resource, Azure routes the API request to the correct resource provider.

**AWS equivalent:** Azure Resource Provider ≈ AWS Service family

```
Azure Microsoft.Compute  ↔  AWS EC2 service family
Azure Microsoft.Storage  ↔  AWS S3 service family
Azure Microsoft.Sql      ↔  AWS RDS service family
Azure Microsoft.Network  ↔  AWS VPC service family
```

**Why it matters for Terraform:** Azure resources are described by provider and type:
- `Microsoft.Compute/virtualMachines`
- `Microsoft.Network/virtualNetworks`

Terraform uses these internally when communicating with the ARM API.

---

## Provider Registration

Even if Azure knows about a provider like `Microsoft.Network` or `Microsoft.Compute`, your subscription may need to be registered for that provider before you can use it. This is called provider registration.

- **Resource Provider** = the Azure service family
- **Provider Registration** = enabling your subscription to use that service family

**AWS equivalent:** There is no strong direct equivalent. AWS generally hides this from you — when you create a resource, it automatically uses the appropriate service without requiring you to register anything at the account level.

**Azure CLI examples:**

```bash
# List all registered providers
az provider list --query "[?registrationState=='Registered'].{Provider:namespace}" -o table

# Register a provider
az provider register --namespace Microsoft.Compute

# Check a provider's registration state
az provider show --namespace Microsoft.Compute --query "registrationState" -o tsv
```

---

## Azure Policy

Azure Policy is a service that lets you create, assign, and manage rules that enforce configurations on your Azure resources. It helps ensure your resources comply with organizational standards.

Examples of what policies can enforce:
- only allow certain regions
- require specific tags on all resources
- deny public IPs
- audit non-compliant resources

**AWS equivalent:** There is no single perfect equivalent. The closest mental model is:
- Azure Policy ≈ AWS Config rules (for checking compliance)
- Azure Policy ≈ AWS Organizations SCPs (for guardrails that restrict what can be done)

**Why it matters for Terraform:** Terraform may be syntactically correct and your credentials may be valid, but Azure Policy can still block the deployment.

Example:
- your Terraform tries to create a VM in `westus`
- an Azure Policy says only `eastus` is allowed
- the deployment is denied

When you hit unexpected deployment errors, check whether an Azure Policy is blocking you.

**Key terms:**
- **Policy definition** — the rule itself (conditions and the effect to apply)
- **Assignment** — attaching that rule to a scope so Azure evaluates resources against it
- **Scope** — where the policy applies: management group, subscription, resource group, or resource. Child resources inherit policies from parent scopes.

**Azure CLI examples:**

```bash
# List policy definitions
az policy definition list -o table

# List policy assignments
az policy assignment list -o table

# Create a policy assignment
az policy assignment create \
  --name "EnforceTag" \
  --policy "PolicyDefinitionNameOrID" \
  --scope "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}"
```

---

## Azure Quota

Azure quotas are limits on the number or size of resources you can create in your subscription. Each service has its own quotas, which can vary by region. For example, there may be a quota on the number of VMs you can create in a region or the total number of vCPUs you can use.

**AWS equivalent:** Azure Quota ≈ AWS Service Quotas

**Why it matters for Terraform:** You can have all of these be correct:
- right subscription
- right resource group
- right region
- right resource type
- right SKU

...and Azure can still reject the deployment because your quota is exhausted. For VMs, Azure blocks deployment if either the VM family quota or the total regional vCPU quota would be exceeded.

Quota means: "Am I still within my allowed limit for this resource in this region?"

**Azure CLI example:**

```bash
az vm list-usage --location eastus -o table
```

---

## Pre-flight Checklist Before `terraform apply`

Run through this checklist before deploying an Azure VM with Terraform. You do not need to do all of these every time, but knowing how to check them saves debugging time.

```
1. Confirm the active subscription
2. Identify or create the target resource group
3. Choose the deployment location (region)
4. Confirm the required resource providers are registered
5. Verify the desired SKU is available in that location
6. Check zone availability if using availability zones
7. Check quota to ensure you are within limits
```

**Azure CLI quick reference:**

```bash
# 1. Check active subscription
az account show -o table

# Switch subscription if needed
az account set --subscription "Subscription Name or ID"

# 2. List resource groups
az group list -o table

# Create a resource group
az group create --name myapp-dev-rg --location eastus

# 3. List available locations
az account list-locations -o table

# 4. Check provider registration
az provider list --query "[?registrationState=='Registered'].{Provider:namespace}" -o table

# Register a provider if needed
az provider register --namespace Microsoft.Compute

# 5. Check SKU availability in a region
az vm list-skus -l eastus --resource-type virtualMachines -o table

# 6. Check zone availability
az vm list-skus -l eastus --resource-type virtualMachines \
  --query "[?zones!=null].{Name:name, Zones:zones}" -o table

# 7. Check quota
az vm list-usage --location eastus -o table
```

> **Note:** In practice you may skip some of these checks on familiar subscriptions. Automate them in scripts or CI pipelines for repeated deployments.

> **Note:** Terraform will surface an error if any of these conditions are not met, but checking proactively avoids a round-trip to Azure just to get an error message back.
