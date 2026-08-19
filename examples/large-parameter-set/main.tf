terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
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

provider "azurerm" {
  features {}

  # The subscription used for e2e testing enforces a policy that disables shared-key
  # (storage account key) authentication on new storage accounts. Instruct the
  # provider to use Azure AD for storage data-plane operations (e.g. its post-create
  # blob service availability check) instead of falling back to shared-key auth.
  storage_use_azuread = true
}

data "azurerm_client_config" "current" {}

# Microsoft.Databricks/accessConnectors is not available in every Azure region, so a
# single known-supported region is pinned rather than randomly selected (mirrors the
# approach used by Azure/terraform-azure-avm-res-fabric-capacity for the same reason).
# https://learn.microsoft.com/azure/templates/microsoft.databricks/accessconnectors
locals {
  location = "westeurope"
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

resource "azurerm_resource_group" "this" {
  location = local.location
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_user_assigned_identity" "this" {
  location            = azurerm_resource_group.this.location
  name                = "uami-${random_string.connector_suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_role_assignment" "current_user_storage_blob_data_contributor" {
  # Scoped to the resource group (rather than the storage account, which does not
  # exist yet) so this role assignment can be created before, and does not depend
  # on, the storage account below. That gives Azure AD's RBAC propagation a head
  # start before the AzureRM provider polls the storage account's data plane
  # (blob service) right after creation -- see the storage_use_azuread comment above.
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = azurerm_resource_group.this.id
}

resource "azurerm_storage_account" "this" {
  account_replication_type = "ZRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.this.location
  name                     = "st${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.this.name

  # The subscription used for e2e testing enforces a policy that forces these two
  # settings to false on all new storage accounts, regardless of what is requested.
  # Setting them explicitly (instead of relying on the provider defaults of true)
  # keeps Terraform's desired state aligned with the policy-enforced actual state,
  # so a post-apply plan reports no drift.
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  lifecycle {
    # public_network_access_enabled must stay "true" (the provider default) at
    # create time so the AzureRM provider's post-create data-plane availability
    # check can reach the storage account over its public endpoint. The same
    # subscription policy that forces the two settings above then asynchronously
    # flips this one to "false" after creation, which would otherwise show up as
    # permanent drift on every subsequent plan.
    ignore_changes = [public_network_access_enabled]
  }

  depends_on = [azurerm_role_assignment.current_user_storage_blob_data_contributor]
}

module "test" {
  source = "../../"

  enable_telemetry = var.enable_telemetry
  location         = azurerm_resource_group.this.location
  name             = "dac${random_string.connector_suffix.result}"
  parent_id        = azurerm_resource_group.this.id

  lock = {
    kind = "CanNotDelete"
    name = "myCustomLockName"
  }

  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.this.id]
  }

  role_assignments = {
    current_user_reader = {
      role_definition_id_or_name = "Reader"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }

  tags = {
    Environment    = "Non-Prod"
    Role           = "StorageCredential"
    "hidden-title" = "Azure Databricks Access Connector"
  }
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  principal_id         = module.test.system_assigned_mi_principal_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = azurerm_storage_account.this.id

  depends_on = [module.test]
}

output "access_connector_id" {
  value = module.test.resource_id
}

output "storage_account_id" {
  value = azurerm_storage_account.this.id
}
