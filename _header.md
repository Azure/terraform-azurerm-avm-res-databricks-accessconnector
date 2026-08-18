# terraform-azurerm-avm-res-databricks-accessconnector

Azure Verified Module resource module for Azure Databricks Access Connector.

## Overview

This module deploys a **general-purpose** Azure Databricks Access Connector by using `azurerm_databricks_access_connector`.

`Microsoft.Databricks/accessConnectors` is intentionally simple: the ARM schema is only `identity`, `location`, `name`, `tags`, and an always-empty `properties = {}` object. The connector is therefore a reusable managed-identity building block for any Unity Catalog or Databricks storage-access scenario. The scenario is determined by **RBAC on the target storage resource**, not by anything configured on the connector itself.

Typical scenarios include:

- ADLS Gen2 external locations
- Azure Blob Storage external locations
- OneLake / Microsoft Fabric federation
- Databricks workspace default-storage-firewall access
- Any other managed-identity-based Unity Catalog storage credential pattern

## Supported AVM interfaces

This module keeps only the AVM interfaces that the access connector resource itself can meaningfully support:

- `managed_identities`
- `role_assignments`
- `lock`
- `tags`
- `enable_telemetry`

## Intentionally omitted interfaces

The following template interfaces are intentionally omitted because the access connector resource does not expose corresponding functionality, and the authoritative AVM Bicep module omits them as well:

- `diagnostic_settings`
- `private_endpoints`
- `customer_managed_key`
- AzAPI-specific retry / timeout plumbing

For real storage access, grant the connector's managed identity RBAC on the destination storage resource outside this module. The `examples/large-parameter-set` scenario demonstrates that pattern with `Storage Blob Data Contributor` on a storage account.

## AzureRM provider note

This module intentionally uses the native AzureRM resource `azurerm_databricks_access_connector` for the primary resource. Its effective surface area aligns with the latest stable ARM schema for `Microsoft.Databricks/accessConnectors` (`2026-01-01`): there are no scenario-specific properties beyond identity and tags.
