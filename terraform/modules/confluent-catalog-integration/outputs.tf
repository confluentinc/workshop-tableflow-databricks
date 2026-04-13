# ===============================
# Confluent Catalog Integration Module Outputs
# ===============================

output "integration_id" {
  description = "Catalog integration ID"
  value       = confluent_catalog_integration.unity.id
}

output "display_name" {
  description = "Catalog integration display name"
  value       = confluent_catalog_integration.unity.display_name
}
