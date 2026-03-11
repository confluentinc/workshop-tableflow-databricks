output "metastore_id" {
  description = "Unity Catalog metastore ID (created or existing)"
  value       = local.metastore_id
}

output "sql_warehouse_id" {
  description = "SQL warehouse ID (if created)"
  value       = var.create_sql_warehouse ? databricks_sql_endpoint.unity[0].id : null
}
