# The Azure mental model
Think of Azure as a hierarchy:

Tenant → Management Group → Subscription → Resource Group → Resource

### Azure Resource Manager
Often called ARM, is the deployment and management layer for Azure. It is the control plane that creates, updates, and deletes resources.

## Tenant

This is the top-level identity boundary for your organization. In practice, it is tied to Microsoft Entra ID. Many subscriptions can exist under one tenant. Management groups live above subscriptions inside this hierarchy.

## Management Group
This is a container for subscriptions. It allows you to manage access, policies, and compliance across multiple subscriptions. You can have multiple management groups in a tenant, and they can be nested.

## Subscription
A subscription is the main boundary for:
- billing
- quotas
- permissions
- resource deployment context

When you run Azure CLI commands, many of them act against the current subscription.

**AWS equivalent**
The closest AWS equivalent is an AWS account. So a good first mental mapping is:
- Azure Subscription ≈ AWS Account
That is not a perfect one-to-one match, but for Terraform and day-to-day work, it is close enough.

Why it matters for Terraform, When Terraform deploys to Azure, it must know which subscription to deploy into.
**That affects:**
- what resources you are allowed to create
- which regions you can use
- your quotas
- your costs

So before terraform apply, one of the first things you should always confirm is:
- “Which subscription am I targeting?”

**Azure CLI commands**
These two are the most important beginner commands:
- Show the current subscription:
```bash
az account show -o table
```
- List all subscriptions:
```bash
az account list -o table
```
- Switch to a different subscription:
```bash
az account set --subscription "Subscription Name or ID"
```

## Resource Group
A resource group is a logical container for Azure resources. It provides a way to manage and organize related resources together. When you create a resource in Azure, you must specify a resource group for it to belong to. You can think of a resource group as a folder that holds related resources, making it easier to manage and monitor them as a unit. For example, a VM, its NIC, its public IP, and its disk may all live in one resource group.

There is no perfect AWS equivalent. The closest is a combination of:
- AWS CloudFormation Stack (for grouping related resources together)
- AWS Resource Groups (for logical grouping and management)
**Note:** AWS Resource Groups are more of a management tool and do not affect how resources are created or billed, while Azure Resource Groups are fundamental to resource organization and management in Azure.

### Why it matters for Terraform
In Azure, many resources are created inside a resource group. So before Terraform creates a VM, VNet, public IP, or storage account, it usually needs to know:
- which subscription
- which resource group
- which region

That is why Azure Terraform examples often start with a resource group first. Very practical way to think about it
If your app is called myapp-dev, you might create:
- Subscription: Dev Subscription
- Resource Group: myapp-dev-rg
Then put related Azure resources there:
- virtual network
- subnet
- network security group
- public IP
- VM

**Azure CLI example**
```bash
az group create --name myapp-dev-rg --location eastus # creates a resource group named "myapp-dev-rg" in the "eastus" region
```

## Azure Resource
This is the actual service or component you want to create, such as a virtual machine, storage account, or database. Resources are created inside resource groups and are the building blocks of your Azure infrastructure. Each resource has a type, such as Microsoft.Compute/virtualMachines for a VM or Microsoft.Storage/storageAccounts for a storage account. When you create a resource, you specify its properties, such as its name, location, and configuration settings. Resources can also have dependencies on other resources, which Terraform can manage for you.

**AWS equivalent, Azure Resource ≈ AWS Resource**
Examples:
Azure Virtual Machine ↔ AWS EC2 Instance
Azure Storage Account ↔ AWS S3 Bucket
Azure SQL Database ↔ AWS RDS Instance


## Azure Region / Location
What it means in Azure
A region is the geographic area where you deploy a resource, such as eastus, westus3, or uksouth.
In Azure CLI and Terraform, you will very often see the word location. In practice, for most beginner work:
- location = region
Microsoft’s Azure CLI uses az account list-locations to list locations available to your subscription.
- AWS equivalent, Azure Region / Location ≈ AWS Region
Examples:
Azure eastus ↔ AWS us-east-1
Azure uksouth ↔ AWS eu-west-2 is not exact geographically, but similar idea: a named deployment region

**Why it matters for Terraform**
When Terraform creates a resource in Azure, many resources need a location.
That decides:
- where the resource runs
- where latency comes from
- where some pricing and availability differ
- which VM sizes may exist there
- whether zones are available there

So a common beginner question before terraform apply is:
“Which Azure region should I deploy into?”

**Azure CLI examples**
List available regions for your subscription:
```bash
az account list-locations -o table
```
Create a resource group in a specific region:
```bash
az group create --name myapp-dev-rg --location eastus
```
**Create a resource group named demo-rg in subscription X and location eastus.**
```bash
az group create --name demo-rg --subscription "Subscription Name or ID" --location eastus
```
**Note:** Azure CLI commands often have a --subscription flag that allows you to specify which subscription to target for that command. If you do not specify it, it will use the currently active subscription.
**Note:** A resource group itself has a location, but that does not mean every resource inside it must be in that same location. Azure stores resource-group metadata in that location, while resources can sometimes be deployed elsewhere depending on the resource type. Microsoft notes that resources in a resource group can be in different regions.

## Azure Availability Zone
An availability zone is a physically separate zone within an Azure region. Each zone has its own power, cooling, and networking. By deploying resources across multiple zones, you can protect your applications and data from datacenter failures. Not all regions have availability zones, but for those that do, it is a best practice to use them for high availability.
**AWS equivalent, Azure Availability Zone ≈ AWS Availability Zone**
Examples:
Azure eastus has zones 1, 2, and 3
AWS us-east-1 has zones a, b, c, d, e, f

## Azure SKU
A SKU (Stock Keeping Unit) is a unique identifier for a specific version of a product or service. In Azure, SKUs are used to identify different configurations or tiers of a resource, such as different VM sizes or storage account types. When creating resources in Azure, you specify the SKU to determine the performance, capacity, and features of the resource.
A SKU is the size, tier, or edition of a resource. It is not the resource itself. It is the specific version/shape of the resource you choose.

**AWS equivalent, Azure SKU ≈ AWS Instance Type**
Examples:
Azure Standard_D2s_v3 ↔ AWS t3.medium
Azure Premium_LRS ↔ AWS gp2

## Azure Resource Provider
A resource provider is a service that offers a set of resources in Azure. Each resource provider has a namespace, such as Microsoft.Compute for virtual machines or Microsoft.Storage for storage accounts. When you create a resource in Azure, you specify the resource provider and the type of resource you want to create. Resource providers are responsible for handling the API requests for creating, updating, and deleting resources.
**AWS equivalent, Azure Resource Provider ≈ AWS Service**
Examples:
Azure Microsoft.Compute ↔ AWS EC2 service family
Azure Microsoft.Storage ↔ AWS S3 service family
Azure Microsoft.Sql ↔ AWS RDS service family
Azure Microsoft.Network ↔ AWS VPC service family

**Why it matters** for Terraform
When you use Terraform to create resources in Azure, Terraform needs to know which resource provider to use for each resource. This is because different resource providers have different APIs and capabilities. For example, if you want to create a virtual machine, Terraform needs to use the Microsoft.Compute resource provider. If you want to create a storage account, Terraform needs to use the Microsoft.Storage resource provider. So when you write your Terraform configuration, you will specify the resource provider and type for each resource you want to create.

Because Azure resources are usually described like this
- provider + type

Example:
- Microsoft.Compute/virtualMachines
- Microsoft.Network/virtualNetworks

## Provider Registration
Before you can create resources in Azure using Terraform, you need to ensure that the necessary resource providers are registered in your Azure subscription. This is because Terraform relies on these providers to create and manage resources. If a provider is not registered, you may encounter errors when trying to deploy resources that depend on it.

Even if Azure knows about a provider like Microsoft.Network or Microsoft.Compute, your subscription may need to be registered for that provider before you can use it fully.
So:
- Resource Provider = the Azure service family
- Provider Registration = enabling your subscription to use that service family
- Microsoft describes provider registration as configuring the subscription to work with a resource provider.
**AWS equivalent**
There is no strong direct AWS equivalent that you usually manage this way. AWS generally hides this more from you. In AWS, when you create a resource, it automatically uses the appropriate service without needing to register anything at the account level, because AWS generally hides this more from you.

**Azure CLI examples**
List registered providers:
```bash
az provider list --query "[?registrationState=='Registered'].{Provider:namespace}" -o table
```
Register a provider:
```bash
az provider register --namespace Microsoft.Compute
```
Check provider registration state:
```bash
az provider show --namespace Microsoft.Compute --query "registrationState" -o tsv
```

## Azure Policy
Azure Policy is a service that allows you to create, assign, and manage policies that enforce rules and effects on your Azure resources. It helps you ensure that your resources comply with your organizational standards and service level agreements. With Azure Policy, you can define policies that restrict the types of resources that can be created, enforce specific configurations, or require certain tags on resources. This is a powerful tool for governance and compliance in Azure.
It checks whether your resources match rules your organization wants to enforce, such as:
- only allow certain regions,
- require specific tags,
-  deny public IPs,

audit non-compliant resources. Azure Policy is designed to create, assign, and manage policy definitions in your Azure environment, and it can enforce or audit rules on resources.

**AWS equivalent**
There is no single perfect AWS equivalent.
The closest mental model is:
- Azure Policy ≈ AWS Config rules for checking compliance
- and sometimes also ≈ AWS Organizations SCPs for guardrails that restrict what can be done. AWS Config rules evaluate whether resources comply with desired configuration, while SCPs set maximum available permissions and can enforce organization-wide guardrails.

**Why it matters for Terraform**
Terraform may be syntactically correct, but Azure Policy can still block the deployment.
Example:
- your Terraform tries to create a VM in westus
- Azure Policy says only eastus is allowed
- the deployment is denied
So when you encounter deployment errors, it is worth checking if there are any Azure Policies that might be blocking your deployment.
**So policy is one of the things that answers:**
- “Am I allowed to create this resource this way?”

**The key pieces**
You only need three terms for now:
- Policy definition = the rule itself. Azure says the definition contains the conditions and the effect to apply when the conditions are met.
- Assignment = attaching that rule to a scope so Azure can evaluate resources against it. Azure documents assignments as relating policy definitions and parameters to resources for evaluation.
- Scope = where the policy applies, such as a management group, subscription, resource group, or resource. Azure Policy applies at a scope and child resources inherit from parent scopes
**Azure CLI examples**
List policy definitions:
```bash
az policy definition list -o table
```
List policy assignments:
```bash
az policy assignment list -o table
```
Create a policy assignment:
```bash
az policy assignment create --name "EnforceTag" --policy "PolicyDefinitionNameOrID" --scope "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}"
```

## Azure Quota
Azure quotas are limits on the number of resources or the amount of resources you can create in your Azure subscription. These quotas are in place to prevent abuse and to ensure that resources are available for all customers. Each Azure service has its own set of quotas, which can vary by region and subscription. For example, there may be a quota on the number of virtual machines you can create in a region or the number of public IP addresses you can have in a subscription. It is important to be aware of these quotas when planning your infrastructure, as hitting a quota limit can prevent you from creating new resources until you either delete existing resources or request a quota increase from Microsoft.

**AWS equivalent, Azure Quota ≈ AWS Service Limits**
The closest AWS equivalent is Service Quotas. AWS documents service quotas as the maximum number of service resources or operations for your account, and unless noted otherwise, many are Region-specific.
Why it matters for Terraform
You can have all of these be correct:
- right subscription,
- right resource group,
- right region,
- right resource,
- right SKU,

and Azure can still reject the deployment because your quota is too low. For VMs, Azure says deployment is blocked if either the VM family quota or the total regional vCPU quota would be exceeded.
Quota means: “am I still within my allowed limit for using this resource in this region?”
**Azure CLI examples**
List quotas for a region:
```bash
az vm list-usage --location eastus -o table
```

## Simple Azure Workflow
Practical precheck flow for one Azure VM in this order:
- confirm the active subscription
- pick the resource group
- choose the location
- confirm the resource provider is registered
- check the SKU in that location
- check zone availability
- check quota
- then map that into what Terraform needs

**Note:* In practice, you may not do all of these checks every time, but it is good to be aware of them and know how to check them when needed.
**Note:* Terraform will give you an error if any of these are wrong, but it is good to know how to check them proactively to save time and avoid frustration.
**Note:* Some of these checks can be automated in scripts or CI pipelines to ensure that your Terraform deployments have a higher chance of success without manual intervention.
**Note:* Azure CLI can be a helpful tool for doing these checks and understanding the Azure environment before running Terraform.
**Note:* Azure documentation often has links to CLI commands for checking these things, so it is worth getting familiar with the Azure CLI as well.
**Azure CLI examples**
Check active subscription:
```bash
az account show -o table
```
Select a subscription:
```bash
az account set --subscription "Subscription Name or ID"
```
Check resource group:
```bash
az group list -o table
```
Check location:
```bash
az account list-locations -o table
```
Pick or create a resource group:
```bash
az group create --name myapp-dev-rg --location eastus
```
Check provider registration:
```bash
az provider list --query "[?registrationState=='Registered'].{Provider:namespace}" -o table
```
Register a provider if needed:
```bash
az provider register --namespace Microsoft.Compute
```
Check SKU availability:
```bash
az vm list-skus -l eastus --resource-type virtualMachines -o table
```
Check zone availability:
```bash
az vm list-skus -l eastus --resource-type virtualMachines --query "[?zones!=null].{Name:name, Zones:zones}" -o table
```
Check quota:
```bash
az vm list-usage --location eastus -o table
```

