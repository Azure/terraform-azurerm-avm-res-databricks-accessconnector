terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.21"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "~> 0.1"
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
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
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_user_assigned_identity" "this" {
  location            = azurerm_resource_group.this.location
  name                = "uami-${random_string.connector_suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_storage_account" "this" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.this.location
  name                     = "st${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.this.name
}

module "test" {
  source = "../../"

  enable_telemetry    = var.enable_telemetry
  location            = azurerm_resource_group.this.location
  name                = "dac${random_string.connector_suffix.result}"
  resource_group_name = azurerm_resource_group.this.name

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
