mock_provider "azapi" {
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            role_name = "Reader"
          },
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe"
            role_name = "Storage Blob Data Contributor"
          }
        ]
      }
    }
  }

  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "modtm" {}

# avm-utl-interfaces generates a role-assignment name via random_uuid when the caller
# doesn't supply one. The role-assignment resource name must be a real UUID, so an
# explicit default is required here (the auto-generated mock value is a placeholder
# string, not UUID-formatted).
mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "11111111-2222-3333-4444-555555555555"
    }
  }
}

variables {
  location  = "westeurope"
  name      = "dacdefault001"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
}

run "defaults_plan" {
  command = plan

  variables {
    enable_telemetry = false
  }

  assert {
    condition     = azapi_resource.this.name == "dacdefault001"
    error_message = "The connector must be created with the planned name."
  }

  assert {
    condition     = azapi_resource.this.location == "westeurope"
    error_message = "The explicit location must flow through to the connector."
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Databricks/accessConnectors@2026-01-01"
    error_message = "The connector must use the approved stable ARM API by default."
  }

  assert {
    condition     = azapi_resource.this.body.identity == null
    error_message = "No managed identity should be requested by default."
  }

  assert {
    condition     = length(azapi_resource.lock) == 0
    error_message = "No lock should be created by default."
  }
}

run "role_assignments_plan" {
  command = plan

  variables {
    enable_telemetry = false
    name             = "dacroles001"
    managed_identities = {
      system_assigned = true
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ua-001",
      ]
    }
    role_assignments = {
      storage_blob_data_contributor = {
        role_definition_id_or_name = "Storage Blob Data Contributor"
        principal_id               = "00000000-0000-0000-0000-000000000001"
        principal_type             = "ServicePrincipal"
      }
    }
    lock = {
      kind = "CanNotDelete"
    }
  }

  assert {
    condition     = azapi_resource.this.body.identity.type == "SystemAssigned,UserAssigned"
    error_message = "Both identity types must be requested when both are enabled."
  }

  assert {
    condition     = contains(keys(azapi_resource.this.body.identity.userAssignedIdentities), "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ua-001")
    error_message = "The requested user-assigned identity must be attached."
  }

  assert {
    condition     = azapi_resource.role_assignments["storage_blob_data_contributor"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    error_message = "The role assignment must resolve the requested built-in role name to its role definition ID."
  }

  assert {
    condition     = length(azapi_resource.lock) == 1
    error_message = "A requested lock must be created."
  }
}

run "invalid_name_fails" {
  command = plan

  variables {
    name = "ab"
  }

  expect_failures = [var.name]
}

run "invalid_lock_kind_fails" {
  command = plan

  variables {
    lock = {
      kind = "Delete"
    }
  }

  expect_failures = [var.lock]
}

run "invalid_parent_id_fails" {
  command = plan

  variables {
    parent_id = "not-a-resource-id"
  }

  expect_failures = [var.parent_id]
}
