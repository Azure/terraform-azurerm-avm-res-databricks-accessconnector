locals {
  managed_identity_type_list = compact([
    var.managed_identities.system_assigned ? "SystemAssigned" : null,
    length(var.managed_identities.user_assigned_resource_ids) > 0 ? "UserAssigned" : null,
  ])

  managed_identity = length(local.managed_identity_type_list) == 0 ? null : {
    type         = join(",", local.managed_identity_type_list)
    identity_ids = length(var.managed_identities.user_assigned_resource_ids) > 0 ? sort(tolist(var.managed_identities.user_assigned_resource_ids)) : null
  }
}
