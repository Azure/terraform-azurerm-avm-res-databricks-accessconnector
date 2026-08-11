output "identity" {
  description = "Full managed identity object returned by the AzureRM provider for the access connector, or null when no identity is attached."
  value       = try(one(azurerm_databricks_access_connector.this.identity), null)
}

output "location" {
  description = "Azure region of the deployed access connector."
  value       = azurerm_databricks_access_connector.this.location
}

output "name" {
  description = "Name of the deployed Azure Databricks access connector."
  value       = azurerm_databricks_access_connector.this.name
}

output "resource_group_name" {
  description = "Name of the resource group containing the access connector."
  value       = azurerm_databricks_access_connector.this.resource_group_name
}

output "resource_id" {
  description = "Resource ID of the deployed Azure Databricks access connector."
  value       = azurerm_databricks_access_connector.this.id
}

output "system_assigned_mi_principal_id" {
  description = "Principal ID of the system-assigned managed identity, if enabled."
  value       = try(one(azurerm_databricks_access_connector.this.identity).principal_id, null)
}
