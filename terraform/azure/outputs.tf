# ===============================
# Workshop Outputs
# ===============================

# ===============================
# Azure Resources
# ===============================

output "resource_group_name" {
  description = "Azure Resource Group name"
  value       = local.effective_resource_group_name
}

output "storage_account_name" {
  description = "ADLS Gen2 Storage Account name"
  value       = local.effective_storage_account_name
}

output "storage_container_name" {
  description = "ADLS Gen2 container name"
  value       = local.effective_storage_container_name
}

output "storage_abfss_url" {
  description = "ADLS Gen2 abfss:// URL"
  value       = local.effective_abfss_url
}

output "postgres_fqdn" {
  description = "PostgreSQL hostname (Flexible Server FQDN or shared VM IP)"
  value       = local.effective_postgres_host
}

# ===============================
# Databricks
# ===============================

output "databricks_workspace_url" {
  description = "Databricks workspace URL"
  value       = local.databricks_workspace_url
}

output "databricks_catalog_name" {
  description = "Databricks Unity Catalog name"
  value       = local.use_shared ? var.dbx_catalog_name : databricks_catalog.main[0].name
}

output "databricks_external_location" {
  description = "Databricks external location name"
  value       = local.use_shared ? "shared (azure-shared)" : databricks_external_location.main[0].name
}

output "databricks_storage_credential" {
  description = "Databricks storage credential name"
  value       = module.databricks.storage_credential_name
}

# ===============================
# Confluent Cloud
# ===============================

output "confluent_environment_id" {
  description = "Confluent Cloud environment ID"
  value       = module.confluent_platform.environment_id
}

output "confluent_kafka_cluster_id" {
  description = "Confluent Cloud Kafka cluster ID"
  value       = module.confluent_platform.kafka_cluster_id
}

output "confluent_bootstrap_endpoint" {
  description = "Kafka bootstrap endpoint"
  value       = module.confluent_platform.bootstrap_endpoint_url
}

output "confluent_schema_registry_endpoint" {
  description = "Schema Registry endpoint"
  value       = module.confluent_platform.schema_registry_endpoint
}

# ===============================
# Workshop Summary
# ===============================

output "workshop_summary" {
  description = "Summary of deployed resources"
  value       = <<-EOT

    ==========================================
    Workshop Deployment Complete (Azure)
    ==========================================

    Azure Resources:
      Resource Group:     ${local.effective_resource_group_name}
      Storage Account:    ${local.effective_storage_account_name}
      PostgreSQL:         ${local.effective_postgres_host}

    Databricks:
      Workspace URL:      ${local.databricks_workspace_url}

    Confluent Cloud:
      Environment:        ${module.confluent_platform.environment_id}
      Kafka Cluster:      ${module.confluent_platform.kafka_cluster_id}
      Bootstrap:          ${module.confluent_platform.bootstrap_endpoint_url}

    ==========================================
  EOT
}

# ===============================
# WSA Outputs
# ===============================

output "cc_environment_url" {
  description = "WSA: Confluent Cloud console URL for this environment"
  value       = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}"
}

output "dbx_workspace_url" {
  description = "WSA: Databricks workspace URL"
  value       = var.dbx_workspace_url != "" ? var.dbx_workspace_url : local.databricks_workspace_url
}

output "dbx_sp_client_id" {
  description = "WSA: Databricks SP client ID (for Tableflow Unity Catalog integration)"
  value       = var.shared_dbx_sp_client_id != "" ? var.shared_dbx_sp_client_id : var.databricks_service_principal_client_id
}

output "dbx_sp_client_secret" {
  description = "WSA: Databricks SP secret (for Tableflow Unity Catalog integration)"
  value       = var.shared_dbx_sp_client_secret != "" ? var.shared_dbx_sp_client_secret : var.databricks_service_principal_client_secret
  sensitive   = true
}

output "dbx_catalog_name" {
  description = "WSA: Databricks Unity Catalog name"
  value       = local.use_shared ? var.dbx_catalog_name : databricks_catalog.main[0].name
}

output "dbx_schema_name" {
  description = "WSA: Databricks schema name (Kafka cluster ID used as schema in Unity Catalog)"
  value       = module.databricks.databricks_schema_name
}
