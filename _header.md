# terraform-azurerm-avm-res-databricks-accessconnector

Azure Verified Module resource module for Azure Databricks Access Connector.

## Overview

This module deploys a **general-purpose** Azure Databricks Access Connector by using the AzAPI provider against `Microsoft.Databricks/accessConnectors`.

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
- `resource_types`, `retry`, `timeouts`, `ignore_body_changes` (AzAPI control interfaces)

## Intentionally omitted interfaces

The following template interfaces are intentionally omitted because the access connector resource does not expose corresponding functionality, and the authoritative AVM Bicep module omits them as well:

- `diagnostic_settings`
- `private_endpoints`
- `customer_managed_key`

For real storage access, grant the connector's managed identity RBAC on the destination storage resource outside this module. The `examples/large-parameter-set` scenario demonstrates that pattern with `Storage Blob Data Contributor` on a storage account.
