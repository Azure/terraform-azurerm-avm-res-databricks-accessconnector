terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.21"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# The Azure/naming module's provider requirements pull in azurerm even though this
# example does not declare any azurerm_* resources itself.
provider "azurerm" {
  features {}
}

data "azapi_client_config" "current" {}

# Microsoft.Databricks/accessConnectors is not available in every Azure region, so a
# single known-supported region is pinned rather than randomly selected (mirrors the
# approach used by Azure/terraform-azure-avm-res-fabric-capacity for the same reason).
# https://learn.microsoft.com/azure/templates/microsoft.databricks/accessconnectors
locals {
  location = "westeurope"

  # Stable, tenant-independent GUIDs for Azure's built-in RBAC roles. These are the
  # same well-known role-definition IDs the module's own tests assert against; they
  # never vary between tenants, so no lookup/data source is required to resolve them.
  role_definition_ids = {
    reader                        = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
    storage_blob_data_contributor = "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
  }
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

resource "random_string" "connector_suffix" {
  length  = 8
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "random_string" "storage_suffix" {
  length  = 10
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type                   = "Microsoft.Resources/resourceGroups@2021-04-01"
  name                   = module.naming.resource_group.name_unique
  location               = local.location
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  response_export_values = []
}

resource "azapi_resource" "user_assigned_identity" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = "uami-${random_string.connector_suffix.result}"
  location  = azapi_resource.resource_group.location
  parent_id = azapi_resource.resource_group.id
  response_export_values = [
    "properties.principalId",
  ]
}

resource "azapi_resource" "current_user_storage_blob_data_contributor" {
  type = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name = random_uuid.current_user_storage_blob_data_contributor.result
  # Scoped to the resource group (rather than the storage account, which does not
  # exist yet) so this role assignment can be created before, and does not depend
  # on, the storage account below. That gives Azure AD's RBAC propagation a head
  # start before AzAPI's post-create checks against the storage data plane.
  parent_id = azapi_resource.resource_group.id
  body = {
    properties = {
      principalId      = data.azapi_client_config.current.object_id
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/${local.role_definition_ids.storage_blob_data_contributor}"
      principalType    = "User"
    }
  }
  response_export_values = []
}

resource "random_uuid" "current_user_storage_blob_data_contributor" {}

resource "azapi_resource" "storage_account" {
  type      = "Microsoft.Storage/storageAccounts@2023-01-01"
  name      = "st${random_string.storage_suffix.result}"
  location  = azapi_resource.resource_group.location
  parent_id = azapi_resource.resource_group.id
  body = {
    sku = {
      name = "Standard_ZRS"
    }
    kind = "StorageV2"
    properties = {
      # The subscription used for e2e testing enforces a policy that forces these
      # two settings to false on all new storage accounts, regardless of what is
      # requested. Setting them explicitly (instead of relying on provider
      # defaults) keeps Terraform's desired state aligned with the
      # policy-enforced actual state, so a post-apply plan reports no drift.
      allowBlobPublicAccess = false
      allowSharedKeyAccess  = false
      # Stays "true" at create time so AzAPI's post-create data-plane checks can
      # reach the storage account over its public endpoint. The same subscription
      # policy that forces the two settings above then asynchronously flips this
      # one to "false" after creation, which would otherwise show up as permanent
      # drift on every subsequent plan.
      publicNetworkAccess = "Enabled"
    }
  }
  ignore_body_changes = [
    "properties.publicNetworkAccess",
  ]
  response_export_values = []

  depends_on = [azapi_resource.current_user_storage_blob_data_contributor]
}

module "test" {
  source = "../../"

  enable_telemetry = var.enable_telemetry
  location         = azapi_resource.resource_group.location
  name             = "dac${random_string.connector_suffix.result}"
  parent_id        = azapi_resource.resource_group.id

  lock = {
    kind = "CanNotDelete"
    name = "myCustomLockName"
  }

  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azapi_resource.user_assigned_identity.id]
  }

  role_assignments = {
    current_user_reader = {
      role_definition_id_or_name = "Reader"
      principal_id               = data.azapi_client_config.current.object_id
    }
  }

  tags = {
    Environment    = "Non-Prod"
    Role           = "StorageCredential"
    "hidden-title" = "Azure Databricks Access Connector"
  }
}

resource "azapi_resource" "storage_blob_data_contributor" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.storage_blob_data_contributor.result
  parent_id = azapi_resource.storage_account.id
  body = {
    properties = {
      principalId      = module.test.system_assigned_mi_principal_id
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/${local.role_definition_ids.storage_blob_data_contributor}"
      principalType    = "ServicePrincipal"
    }
  }
  response_export_values = []

  depends_on = [module.test]
}

resource "random_uuid" "storage_blob_data_contributor" {}

output "access_connector_id" {
  value = module.test.resource_id
}

output "storage_account_id" {
  value = azapi_resource.storage_account.id
}
