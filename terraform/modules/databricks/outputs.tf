# ===============================
# Databricks Module Outputs
# ===============================

output "storage_credential_name" {
  description = "Storage credential name"
  value       = databricks_storage_credential.main.name
}

output "storage_credential_id" {
  description = "Storage credential ID"
  value       = databricks_storage_credential.main.id
}

output "storage_credential_external_id" {
  description = "Storage credential external ID for IAM trust policy (AWS only)"
  value       = var.cloud_provider == "aws" ? databricks_storage_credential.main.aws_iam_role[0].external_id : null
}

output "databricks_schema_name" {
  description = "Expected schema name (Kafka cluster ID)"
  value       = var.kafka_cluster_id
}

output "sql_warehouse_id" {
  description = "SQL Warehouse ID"
  value       = var.lookup_sql_warehouse ? data.databricks_sql_warehouse.main[0].id : null
}
