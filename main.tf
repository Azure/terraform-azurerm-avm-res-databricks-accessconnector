data "azurerm_client_config" "current" {}

module "interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.6.0"

  enable_telemetry                 = var.enable_telemetry
  lock                             = var.lock
  role_assignment_definition_scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_assignments                 = var.role_assignments
}

resource "azurerm_databricks_access_connector" "this" {
  location            = var.location
  name                = var.name
  resource_group_name = var.resource_group_name
  tags                = var.tags

  dynamic "identity" {
    for_each = local.managed_identity == null ? [] : [local.managed_identity]
    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }
}

resource "azurerm_role_assignment" "this" {
  for_each = module.interfaces.role_assignments_azapi

  principal_id                           = each.value.body.properties.principalId
  scope                                  = azurerm_databricks_access_connector.this.id
  condition                              = each.value.body.properties.condition
  condition_version                      = each.value.body.properties.condition != null ? coalesce(each.value.body.properties.conditionVersion, "2.0") : null
  delegated_managed_identity_resource_id = each.value.body.properties.delegatedManagedIdentityResourceId
  description                            = each.value.body.properties.description
  name                                   = each.value.name
  principal_type                         = each.value.body.properties.principalType
  role_definition_id                     = each.value.body.properties.roleDefinitionId
  skip_service_principal_aad_check       = var.role_assignments[each.key].skip_service_principal_aad_check
}

resource "azurerm_management_lock" "this" {
  count = var.lock == null ? 0 : 1

  lock_level = module.interfaces.lock_azapi.body.properties.level
  name       = coalesce(module.interfaces.lock_azapi.name, "lock-${var.name}")
  scope      = azurerm_databricks_access_connector.this.id
  notes      = coalesce(var.lock.notes, var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources.")

  depends_on = [azurerm_role_assignment.this]
}
