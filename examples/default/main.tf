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

resource "azurerm_resource_group" "this" {
  location = local.location
  name     = module.naming.resource_group.name_unique
}

module "test" {
  source = "../../"

  enable_telemetry = var.enable_telemetry
  location         = azurerm_resource_group.this.location
  name             = "dac${random_string.suffix.result}"
  parent_id        = azurerm_resource_group.this.id
}

output "access_connector_id" {
  value = module.test.resource_id
}
