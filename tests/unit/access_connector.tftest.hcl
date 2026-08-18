mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      client_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000001"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
    }
  }

  # A well-formed resource ID is required here: azurerm_role_assignment.this.scope and
  # azurerm_management_lock.this.scope both reference this resource's id, and the
  # azurerm provider validates scope as a real Azure resource ID even under `command
  # = apply` with mocked providers. Without this default, Terraform generates a
  # placeholder id (e.g. "zh7tbu01") that fails that validation.
  mock_resource "azurerm_databricks_access_connector" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Databricks/accessConnectors/dac-test"
    }
  }
}

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
# doesn't supply one. azurerm_role_assignment.name must be a real UUID, so an explicit
# default is required here (the auto-generated mock value is a placeholder string,
# not UUID-formatted).
mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "11111111-2222-3333-4444-555555555555"
    }
  }
}

run "defaults_plan" {
  command = apply

  variables {
    enable_telemetry    = false
    location            = "westeurope"
    name                = "dacdefault001"
    resource_group_name = "rg-test"
  }

  assert {
    condition     = output.name == "dacdefault001"
    error_message = "The name output should match the planned connector name."
  }

  assert {
    condition     = output.location == "westeurope"
    error_message = "The explicit location should flow through the plan."
  }
}

run "role_assignments_plan" {
  command = apply

  variables {
    enable_telemetry    = false
    location            = "northeurope"
    name                = "dacroles001"
    resource_group_name = "rg-test"
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
    condition     = output.location == "northeurope"
    error_message = "The explicit location should flow through the plan."
  }
}

run "invalid_name_fails" {
  # Kept as `plan` (not `apply`): this is a pure input-validation test. Terraform's
  # test framework marks apply-based runs as failed when the expected failure occurs
  # during the plan phase (a documented limitation, not specific to this module) --
  # command = plan is the correct choice here even though other run blocks in this
  # file use apply per AVM convention.
  command = plan

  variables {
    enable_telemetry    = false
    location            = "westeurope"
    name                = "ab"
    resource_group_name = "rg-test"
  }

  expect_failures = [var.name]
}

run "invalid_lock_kind_fails" {
  # See the comment on invalid_name_fails above: pure input-validation tests must
  # stay on `command = plan`.
  command = plan

  variables {
    enable_telemetry    = false
    location            = "westeurope"
    name                = "dacvalid001"
    resource_group_name = "rg-test"
    lock = {
      kind = "Delete"
    }
  }

  expect_failures = [var.lock]
}
