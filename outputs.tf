output "identity" {
  description = "Full managed identity object returned by Azure for the access connector (`type`, `principalId`, `tenantId`, `userAssignedIdentities`), or `null` when no identity is attached."
  value       = try(azapi_resource.this.output.identity, null)
}

output "name" {
  description = "Name of the deployed Azure Databricks access connector."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the deployed Azure Databricks access connector."
  value       = azapi_resource.this.id
}

output "system_assigned_mi_principal_id" {
  description = "Principal ID of the system-assigned managed identity, if enabled."
  value       = try(azapi_resource.this.output.identity.principalId, null)
}
