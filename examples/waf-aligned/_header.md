# WAF-aligned example

This example shows the recommended baseline for a production-oriented access connector:

- system-assigned managed identity
- delete lock
- organizational tags

Because the resource has no scenario-specific configuration surface, WAF alignment for this module is mainly about safe defaults and protecting the identity resource from accidental deletion.
