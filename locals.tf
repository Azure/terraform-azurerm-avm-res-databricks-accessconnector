locals {
  managed_identity_type_list = compact([
    var.managed_identities.system_assigned ? "SystemAssigned" : null,
    length(var.managed_identities.user_assigned_resource_ids) > 0 ? "UserAssigned" : null,
  ])

  managed_identity = length(local.managed_identity_type_list) == 0 ? null : {
    # Azure's control plane normalizes and always returns this value with a
    # comma-space separator ("SystemAssigned, UserAssigned"), regardless of
    # what is submitted. Sending the value without the space (as the ARM
    # swagger enum literal appears) causes every subsequent plan to see drift
    # and propose a no-op update forever.
    type         = join(", ", local.managed_identity_type_list)
    identity_ids = length(var.managed_identities.user_assigned_resource_ids) > 0 ? sort(tolist(var.managed_identities.user_assigned_resource_ids)) : null
  }
}
