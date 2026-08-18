variable "location" {
  type        = string
  description = "Azure region where the access connector should be deployed."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the Azure Databricks access connector. The value must be between 3 and 64 characters."
  nullable    = false

  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 64
    error_message = "The name must be between 3 and 64 characters long."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the Databricks access connector."
  nullable    = false
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "lock" {
  type = object({
    kind  = string
    name  = optional(string, null)
    notes = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the resource lock configuration for the access connector. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `CanNotDelete` and `ReadOnly`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the connector name. Changing this forces the creation of a new resource.
- `notes` - (Optional) Notes about the lock. Maximum of 512 characters.
DESCRIPTION

  validation {
    condition     = var.lock == null ? true : contains(["CanNotDelete", "ReadOnly"], var.lock.kind)
    error_message = "Lock kind must be either `CanNotDelete` or `ReadOnly`."
  }
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Controls the managed identity configuration for the access connector. The access connector itself has no scenario-specific properties; the managed identity is the point of the resource.

- `system_assigned` - (Optional) Specifies if the system-assigned managed identity should be enabled. Defaults to `false` per the AVM interface specification.
- `user_assigned_resource_ids` - (Optional) Set of user-assigned managed identity resource IDs to attach to the connector.
DESCRIPTION
  nullable    = false
}

variable "role_assignments" {
  type = map(object({
    name                                   = optional(string, null)
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of Azure RBAC role assignments to create at the access-connector scope. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

This interface is for RBAC on the connector resource itself. For real Unity Catalog storage credential scenarios, grant the connector's managed identity RBAC on the target storage resource outside this module by using the module outputs.

- `name` - (Optional) GUID name for the role assignment. If omitted, the AVM interfaces utility module generates one.
- `role_definition_id_or_name` - The role definition ID or built-in role name to assign.
- `principal_id` - The object ID of the principal receiving the role assignment.
- `description` - (Optional) Description for the role assignment.
- `skip_service_principal_aad_check` - (Optional) Whether to skip the Microsoft Entra lookup for service principals. Defaults to `false`.
- `condition` - (Optional) ABAC condition for the role assignment.
- `condition_version` - (Optional) ABAC condition version. When `condition` is set and this value is omitted, the module uses `2.0`.
- `delegated_managed_identity_resource_id` - (Optional) Delegated managed identity resource ID for cross-tenant scenarios.
- `principal_type` - (Optional) Principal type such as `User`, `Group`, or `ServicePrincipal`.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) :
      assignment.name == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", assignment.name))
    ])
    error_message = "Each supplied role assignment name must be a lowercase GUID."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Optional map of tags to assign to the access connector."
}
