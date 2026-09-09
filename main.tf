data "azapi_client_config" "current" {}

module "interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.6.0"

  enable_telemetry                 = var.enable_telemetry
  lock                             = var.lock
  role_assignment_definition_scope = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  role_assignments                 = var.role_assignments
}

resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.databricks_access_connectors
  body = {
    identity = local.managed_identity == null ? null : {
      type                   = local.managed_identity.type
      userAssignedIdentities = local.managed_identity.identity_ids == null ? null : { for id in local.managed_identity.identity_ids : id => {} }
    }
    properties = {}
  }
  ignore_body_changes = length(var.ignore_body_changes.databricks_access_connectors) > 0 ? var.ignore_body_changes.databricks_access_connectors : null
  response_export_values = [
    "identity",
  ]
  retry = var.retry
  tags  = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "role_assignments" {
  for_each = module.interfaces.role_assignments_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.this.id
  type                   = each.value.type
  body                   = each.value.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name                   = coalesce(module.interfaces.lock_azapi.name, "lock-${var.name}")
  parent_id              = azapi_resource.this.id
  type                   = module.interfaces.lock_azapi.type
  body                   = module.interfaces.lock_azapi.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  # A `CanNotDelete` lock on the connector also blocks deletes of anything scoped
  # to it, including its role assignments. Terraform destroys in reverse creation
  # order, so creating the lock *after* the role assignments makes it the first
  # thing destroyed. Without this, the lock, the role assignments, and the
  # connector delete concurrently and race, and every loser of that race comes
  # back as `409 ScopeLocked`.
  depends_on = [azapi_resource.role_assignments]
}
