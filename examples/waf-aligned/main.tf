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

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

module "test" {
  source = "../../"

  enable_telemetry    = var.enable_telemetry
  location            = azurerm_resource_group.this.location
  name                = "dac${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name

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
