# ===============================
# Databricks Module Outputs
# ===============================
# Note: This module only creates the storage credential.
# External location and catalog are created in root main.tf
# after the IAM trust policy is updated.

output "storage_credential_name" {
  description = "Storage credential name"
  value       = databricks_storage_credential.main.name
}

output "storage_credential_id" {
  description = "Storage credential ID"
  value       = databricks_storage_credential.main.id
}

output "storage_credential_external_id" {
  description = "Storage credential external ID for IAM trust policy"
  value       = databricks_storage_credential.main.aws_iam_role[0].external_id
}

output "expected_schema_name" {
  description = "Expected schema name (Kafka cluster ID)"
  value       = var.kafka_cluster_id
}

output "sql_warehouse_id" {
  description = "SQL Warehouse ID"
  value       = data.databricks_sql_warehouse.main.id
}
