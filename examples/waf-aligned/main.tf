terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

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

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azapi_resource" "this" {
  type                   = "Microsoft.Resources/resourceGroups@2021-04-01"
  name                   = module.naming.resource_group.name_unique
  location               = local.location
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  response_export_values = []
}

data "azapi_client_config" "current" {}

module "test" {
  source = "../../"

  enable_telemetry = var.enable_telemetry
  location         = azapi_resource.this.location
  name             = "dac${random_string.suffix.result}"
  parent_id        = azapi_resource.this.id

  lock = {
    kind = "CanNotDelete"
    name = "myCustomLockName"
  }

  tags = {
    Environment    = "Non-Prod"
    Role           = "DeploymentValidation"
    "hidden-title" = "Azure Databricks Access Connector"
  }
}

output "access_connector_id" {
  value = module.test.resource_id
}
