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
    postgres_instance_id = module.postgres.instance_id
    postgres_public_dns  = module.postgres.public_dns
    postgres_connection  = "postgresql://postgres:***@${module.postgres.public_dns}:5432/${var.postgres_db_name}"

    # SSH Access
    ssh_command = "ssh -i ${module.keypair.private_key_path} ec2-user@${module.postgres.public_dns}"

    # Confluent Cloud
    environment_id      = module.confluent_platform.environment_id
    kafka_cluster_id    = module.confluent_platform.kafka_cluster_id
    flink_compute_pool  = module.flink.compute_pool_id
    schema_registry_url = module.confluent_platform.schema_registry_endpoint

    # Databricks
    databricks_catalog           = databricks_catalog.main.name
    databricks_external_location = databricks_external_location.main.name

    # S3
    s3_bucket = module.s3.bucket_name

    # Quick Links
    confluent_console = "https://confluent.cloud/environments/${module.confluent_platform.environment_id}"
    connector_url     = var.create_postgres_cdc_connector ? "https://confluent.cloud/environments/${module.confluent_platform.environment_id}/clusters/${module.confluent_platform.kafka_cluster_id}/connectors" : "N/A"
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
    instance_id         = module.postgres.instance_id
    public_ip           = module.postgres.public_ip
    public_dns          = module.postgres.public_dns
    connection_string   = "postgresql://postgres:***@${module.postgres.public_dns}:5432/${var.postgres_db_name}"
    ssh_command         = "ssh -i ${module.keypair.private_key_path} ec2-user@${module.postgres.public_dns}"
    docker_exec_command = "docker exec -it postgres-workshop psql -U postgres -d ${var.postgres_db_name}"
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
    enabled        = module.connectors.enabled
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
  value = (
    var.create_postgres_cdc_connector
    ? "🎉 Workshop Infrastructure Deployed!\n\n📋 Next Steps:\n1. Verify PostgreSQL: ${module.postgres.public_dns}:5432\n2. Check CDC Connector status in Confluent Console\n3. Run ShadowTraffic to generate data\n4. Proceed to LAB5 (Stream Processing)\n\n📚 Documentation: labs/README.md"
    : "🎉 Infrastructure Deployed!\n\n⚠️  CDC Connector not created (create_postgres_cdc_connector=false)\n\n📋 Next Steps:\n1. Verify PostgreSQL: ${module.postgres.public_dns}:5432\n2. Test database connection\n3. Enable connector: set create_postgres_cdc_connector=true\n4. Re-run: terraform apply"
  )
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
