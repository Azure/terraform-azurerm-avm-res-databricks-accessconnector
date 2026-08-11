mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      client_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000001"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_data "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
      location = "westeurope"
      name     = "rg-test"
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

mock_provider "random" {}

run "defaults_plan" {
  command = plan

  variables {
    enable_telemetry    = false
    name                = "dacdefault001"
    resource_group_name = "rg-test"
  }

  assert {
    condition     = output.name == "dacdefault001"
    error_message = "The name output should match the planned connector name."
  }

  assert {
    condition     = output.location == "westeurope"
    error_message = "The module should default location to the resource group's location when location is null."
  }
}

run "role_assignments_plan" {
  command = plan

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
  command = plan

  variables {
    enable_telemetry    = false
    name                = "ab"
    resource_group_name = "rg-test"
  }

  expect_failures = [var.name]
}

run "invalid_lock_kind_fails" {
  command = plan

  variables {
    enable_telemetry    = false
    name                = "dacvalid001"
    resource_group_name = "rg-test"
    lock = {
      kind = "Delete"
    }
  }

  expect_failures = [var.lock]
}
