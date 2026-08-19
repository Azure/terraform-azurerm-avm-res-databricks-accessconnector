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

variable "parent_id" {
  type        = string
  description = "Resource ID of the resource group in which to create the Databricks access connector."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a valid resource-group resource ID."
  }
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

variable "ignore_body_changes" {
  type = object({
    databricks_access_connectors   = optional(list(string), [])
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative paths to ignore for each AzAPI resource this module manages. Paths use dot notation (for example `"tags"`). Changes take effect only after apply; ignored configuration is not sent to Azure until the path is removed.

- `databricks_access_connectors` - (Optional) Paths ignored on the access connector resource body.
- `authorization_locks` - (Optional) Paths ignored on the management lock resource body.
- `authorization_role_assignments` - (Optional) Paths ignored on role assignment resource bodies.
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

variable "resource_types" {
  type = object({
    databricks_access_connectors   = optional(string, "Microsoft.Databricks/accessConnectors@2026-01-01")
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions used by this module. Override only when validating a supported API migration.

- `databricks_access_connectors` - (Optional) The resource type and API version for the access connector. Defaults to `"Microsoft.Databricks/accessConnectors@2026-01-01"`.
- `authorization_locks` - (Optional) The resource type and API version used for the optional management lock. Defaults to `"Microsoft.Authorization/locks@2020-05-01"`.
- `authorization_role_assignments` - (Optional) The resource type and API version used for role assignments on the access connector. Defaults to `"Microsoft.Authorization/roleAssignments@2022-04-01"`.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to every AzAPI resource managed by this module. Defaults to `null` (no custom retry).

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds`     - (Optional) Initial interval between retries, in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries, in seconds.
See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry>.
DESCRIPTION
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

variable "timeouts" {
  type = object({
    create = optional(string)
    delete = optional(string)
    read   = optional(string)
    update = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Timeout overrides for AzAPI operations on the access connector, lock, and role assignments. Defaults to `null` (provider defaults). Each value is a Go duration string, for example `"30m"`.

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
