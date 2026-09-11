# Large parameter set example

This example exercises the full supported module surface:

- explicit `location`
- connector-scope `role_assignments`
- `lock`
- system-assigned and user-assigned managed identities
- `tags`

It also demonstrates the **real** storage credential pattern by granting the connector's system-assigned identity `Storage Blob Data Contributor` on a storage account outside the module.
