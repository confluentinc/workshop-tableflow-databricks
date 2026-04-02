# ===============================
# Root Outputs
# ===============================
# Aggregated outputs from all modules

# ===============================
# Workshop Summary
# ===============================

output "workshop_summary" {
  description = "Complete workshop environment summary"
  value = {
    # PostgreSQL
    postgres_public_dns = local.effective_postgres_dns
    postgres_connection = "postgresql://postgres:***@${local.effective_postgres_dns}:5432/${var.postgres_db_name}"

    # Confluent Cloud
    environment_id      = module.confluent_platform.environment_id
    kafka_cluster_id    = module.confluent_platform.kafka_cluster_id
    flink_compute_pool  = module.flink.compute_pool_id
    schema_registry_url = module.confluent_platform.schema_registry_endpoint

    # Databricks
    databricks_catalog           = databricks_catalog.main.name
    databricks_external_location = local.use_shared ? "shared (aws-shared)" : databricks_external_location.main[0].name

    # S3
    s3_bucket = local.effective_s3_bucket_name

    # Quick Links
    confluent_console = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}"
    connector_url     = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/clusters/${module.confluent_platform.kafka_cluster_id}/connectors"
  }
}

# ===============================
# AWS Outputs
# ===============================

output "aws_networking" {
  description = "AWS networking resources"
  value = {
    vpc_id           = local.effective_vpc_id
    public_subnet_id = local.effective_subnet_id
    aws_account_id   = local.effective_aws_account
  }
}

output "aws_postgres" {
  description = "PostgreSQL instance details"
  value = {
    public_ip  = local.effective_postgres_ip
    public_dns = local.effective_postgres_dns
    connection = "postgresql://postgres:***@${local.effective_postgres_dns}:5432/${var.postgres_db_name}"
    mode       = local.use_shared ? "shared" : "per-account"
  }
}

output "aws_s3" {
  description = "S3 bucket details"
  value = {
    bucket_name = local.effective_s3_bucket_name
    bucket_arn  = local.effective_s3_bucket_arn
    bucket_url  = local.effective_s3_bucket_url
    mode        = local.use_shared ? "shared" : "per-account"
  }
}

output "aws_iam" {
  description = "IAM role details"
  value = {
    role_arn  = module.iam.role_arn
    role_name = module.iam.role_name
  }
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
    iam_role_arn   = module.tableflow.iam_role_arn
    external_id    = module.tableflow.external_id
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

output "databricks_integration" {
  description = "Databricks Unity Catalog integration details"
  value = {
    s3_bucket_name         = local.effective_s3_bucket_name
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
  value       = "🎉 Workshop Infrastructure Deployed!\n\n📋 Next Steps:\n1. Verify PostgreSQL: ${local.effective_postgres_dns}:5432\n2. Check CDC Connector status in Confluent Console\n3. Run ShadowTraffic to generate data\n4. Proceed to LAB3 (Stream Processing)\n\n📚 Documentation: labs/README.md"
}

output "databricks_manual_step" {
  description = "Manual step required for Databricks external data access"
  value       = <<-EOT
    ⚠️  MANUAL STEP REQUIRED ⚠️

    A metastore admin must enable "External data access" on your Unity Catalog metastore.

    Steps (requires metastore admin privileges):
    1. In Databricks workspace: ${var.databricks_host}
    2. Click "Catalog" in the left navigation
    3. Click the gear icon at the top of the Catalog pane
    4. Select "Metastore"
    5. On the "Details" tab, enable "External data access"

    Reference: https://docs.databricks.com/aws/en/external-access/admin
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
  value       = var.dbx_workspace_url != "" ? var.dbx_workspace_url : var.databricks_host
}

output "dbx_sp_client_id" {
  description = "WSA: Databricks SP client ID (for Tableflow Unity Catalog integration)"
  value       = var.shared_dbx_sp_client_id != "" ? var.shared_dbx_sp_client_id : var.databricks_service_principal_client_id
}

output "dbx_sp_client_secret" {
  description = "WSA: Databricks SP secret (ephemeral in workshop mode, original in self-service)"
  value       = var.shared_dbx_sp_client_secret != "" ? var.shared_dbx_sp_client_secret : var.databricks_service_principal_client_secret
  sensitive   = true
}

output "dbx_catalog_name" {
  description = "WSA: Databricks Unity Catalog name (always the Terraform-created catalog with proper storage credentials and grants)"
  value       = databricks_catalog.main.name
}

output "s3_bucket_name" {
  description = "WSA: S3 bucket name (for Tableflow storage)"
  value       = local.effective_s3_bucket_name
}

output "dbx_schema_name" {
  description = "WSA: Databricks schema name (Kafka cluster ID used as schema in Unity Catalog)"
  value       = module.databricks.databricks_schema_name
}

output "dbx_sql_warehouse_id" {
  description = "WSA: SQL Warehouse ID for notebook queries"
  value       = module.databricks.sql_warehouse_id
}
