# ===============================
# Root Outputs — Demo Mode
# ===============================

# ===============================
# Workshop Summary
# ===============================

output "workshop_summary" {
  description = "Complete workshop environment summary"
  value = {
    postgres_public_dns = module.postgres.public_dns
    postgres_connection = "postgresql://postgres:***@${module.postgres.public_dns}:5432/${var.postgres_db_name}"
    environment_id      = module.confluent_platform.environment_id
    kafka_cluster_id    = module.confluent_platform.kafka_cluster_id
    flink_compute_pool  = module.flink.compute_pool_id
    schema_registry_url = module.confluent_platform.schema_registry_endpoint
    databricks_catalog           = databricks_catalog.main.name
    databricks_external_location = databricks_external_location.main.name
    s3_bucket           = module.s3.bucket_name
    confluent_console   = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}"
    connector_url       = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/clusters/${module.confluent_platform.kafka_cluster_id}/connectors"
  }
}

# ===============================
# Demo Status
# ===============================

output "demo_status" {
  description = "Demo mode resource summary with direct links"
  value = {
    mode = "demo"
    catalog_integration = module.catalog_integration.display_name
    flink_ctas_statements = {
      denormalized_hotel_bookings = module.flink_ctas.denormalized_hotel_bookings_statement_name
      reviews_with_sentiment      = module.flink_ctas.reviews_with_sentiment_statement_name
    }
    tableflow_topics = {
      clickstream                 = module.tableflow_topics.clickstream_tableflow_id
      denormalized_hotel_bookings = module.tableflow_topics.denormalized_hotel_bookings_tableflow_id
      reviews_with_sentiment      = module.tableflow_topics.reviews_with_sentiment_tableflow_id
    }
    notebook_path = databricks_notebook.marketing_agent.path
    links = {
      confluent_tableflow = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/clusters/${module.confluent_platform.kafka_cluster_id}/tableflow"
      confluent_flink     = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/flink/compute-pools/${module.flink.compute_pool_id}"
      databricks_catalog  = "${var.databricks_host}#/catalog/${databricks_catalog.main.name}"
    }
  }
}

# ===============================
# AWS Outputs
# ===============================

output "aws_networking" {
  description = "AWS networking resources"
  value = {
    vpc_id           = module.networking.vpc_id
    public_subnet_id = module.networking.public_subnet_id
    aws_account_id   = module.networking.aws_account_id
  }
}

output "aws_postgres" {
  description = "PostgreSQL instance details"
  value = {
    public_ip  = module.postgres.public_ip
    public_dns = module.postgres.public_dns
    connection = "postgresql://postgres:***@${module.postgres.public_dns}:5432/${var.postgres_db_name}"
  }
}

output "aws_s3" {
  description = "S3 bucket details"
  value = {
    bucket_name = module.s3.bucket_name
    bucket_arn  = module.s3.bucket_arn
    bucket_url  = module.s3.bucket_url
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
    s3_bucket_name         = module.s3.bucket_name
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
    Demo Mode Deployment Complete!

    Next Steps:
    1. Wait 10-15 minutes for Tableflow to sync data to Delta Lake
    2. Verify tables in Databricks: ${var.databricks_host}#/catalog/${databricks_catalog.main.name}
    3. Verify the hotel_performance view: SELECT * FROM hotel_performance LIMIT 10
    4. Explore with Genie and run the pre-imported notebook at: /Shared/workshop/river_hotel_marketing_agent
    5. When done: terraform destroy -auto-approve
  EOT
}

output "databricks_manual_step" {
  description = "Manual step required for Databricks external data access"
  value       = <<-EOT
    MANUAL STEP REQUIRED

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
