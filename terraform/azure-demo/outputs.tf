# ===============================
# Root Outputs — Azure Demo Mode
# ===============================

# ===============================
# Workshop Summary
# ===============================

output "workshop_summary" {
  description = "Complete workshop environment summary"
  value = {
    postgres_host                = local.effective_postgres_host
    postgres_connection          = "postgresql://${var.postgres_db_username}:***@${local.effective_postgres_host}:5432/${var.postgres_db_name}"
    environment_id               = module.confluent_platform.environment_id
    kafka_cluster_id             = module.confluent_platform.kafka_cluster_id
    flink_compute_pool           = module.flink.compute_pool_id
    schema_registry_url          = module.confluent_platform.schema_registry_endpoint
    databricks_catalog           = databricks_catalog.main.name
    databricks_external_location = local.use_shared ? "shared (azure-shared)" : databricks_external_location.main[0].name
    storage_account              = local.effective_storage_account_name
    storage_container            = local.effective_storage_container_name
    confluent_console            = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}"
    connector_url                = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/clusters/${module.confluent_platform.kafka_cluster_id}/connectors"
  }
}

# ===============================
# Demo Status
# ===============================

output "demo_status" {
  description = "Demo mode resource summary with direct links"
  value = {
    mode                = "demo"
    catalog_integration = module.catalog_integration.display_name
    flink_materialized_tables = {
      denormalized_hotel_bookings = module.flink_ctas.denormalized_hotel_bookings_table_name
    }
    tableflow_topics = {
      clickstream                 = module.tableflow_topics.clickstream_tableflow_id
      denormalized_hotel_bookings = module.tableflow_topics.denormalized_hotel_bookings_tableflow_id
    }
    notebook_path = databricks_notebook.marketing_agent.path
    notes         = "reviews_with_sentiment Tableflow skipped — AI_SENTIMENT is AWS-only (https://docs.confluent.io/cloud/current/release-notes/index.html#march-19-2026)"
    links = {
      confluent_tableflow = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/clusters/${module.confluent_platform.kafka_cluster_id}/tableflow"
      confluent_flink     = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/flink/compute-pools/${module.flink.compute_pool_id}"
      databricks_catalog  = "${local.databricks_workspace_url}#/catalog/${databricks_catalog.main.name}"
    }
  }
}

# ===============================
# Azure Outputs
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
# Confluent Outputs
# ===============================

output "confluent_environment" {
  description = "Confluent environment details"
  value = {
    environment_id   = module.confluent_platform.environment_id
    environment_name = module.confluent_platform.environment_name
  }
}

output "confluent_kafka" {
  description = "Kafka cluster details"
  value = {
    cluster_id         = module.confluent_platform.kafka_cluster_id
    bootstrap_endpoint = module.confluent_platform.kafka_bootstrap_endpoint
    rest_endpoint      = module.confluent_platform.kafka_rest_endpoint
  }
}

output "confluent_flink" {
  description = "Flink compute pool details"
  value = {
    compute_pool_id   = module.flink.compute_pool_id
    compute_pool_name = module.flink.compute_pool_name
  }
}

output "confluent_tableflow" {
  description = "Tableflow provider integration details"
  value = {
    integration_id = module.tableflow.integration_id
  }
}

output "confluent_connector" {
  description = "PostgreSQL CDC connector details"
  value = {
    connector_id   = module.connectors.connector_id
    connector_name = module.connectors.connector_name
    topics         = module.connectors.topics
  }
}

output "confluent_credentials" {
  description = "Confluent API credentials (sensitive)"
  value = {
    service_account_id         = module.confluent_platform.service_account_id
    kafka_api_key              = module.confluent_platform.kafka_api_key
    kafka_api_secret           = module.confluent_platform.kafka_api_secret
    schema_registry_api_key    = module.confluent_platform.schema_registry_api_key
    schema_registry_api_secret = module.confluent_platform.schema_registry_api_secret
    flink_api_key              = module.flink.flink_api_key
    flink_api_secret           = module.flink.flink_api_secret
  }
  sensitive = true
}

# ===============================
# Databricks Outputs
# ===============================

output "databricks_workspace_url" {
  description = "Databricks workspace URL"
  value       = local.databricks_workspace_url
}

output "databricks_catalog_name" {
  description = "Databricks Unity Catalog name"
  value       = databricks_catalog.main.name
}

output "databricks_integration" {
  description = "Databricks Unity Catalog integration details"
  value = {
    storage_account_name   = local.effective_storage_account_name
    storage_container_name = local.effective_storage_container_name
    catalog_name           = databricks_catalog.main.name
    databricks_schema_name = module.databricks.databricks_schema_name
    sql_warehouse_id       = module.databricks.sql_warehouse_id
  }
}

# ===============================
# Next Steps
# ===============================

output "next_steps" {
  description = "Workshop next steps"
  value       = <<-EOT
    Azure Demo Mode Deployment Complete!

    Next Steps:
    1. Wait 10-15 minutes for Tableflow to sync data to Delta Lake
    2. Verify tables in Databricks: ${local.databricks_workspace_url}#/catalog/${databricks_catalog.main.name}
    3. Explore denormalized_hotel_bookings and clickstream (reviews_with_sentiment skipped — AI_SENTIMENT is AWS-only; see Confluent Cloud release notes 2026-03-19)
    4. Explore with Genie and run the pre-imported notebook at: /Shared/workshop/river_hotel_marketing_agent
    5. When done: terraform destroy -auto-approve
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
  value       = databricks_catalog.main.name
}

output "dbx_schema_name" {
  description = "WSA: Databricks schema name (Kafka cluster ID used as schema in Unity Catalog)"
  value       = module.databricks.databricks_schema_name
}

output "dbx_sql_warehouse_id" {
  description = "WSA: SQL Warehouse ID for notebook queries"
  value       = module.databricks.sql_warehouse_id
}
