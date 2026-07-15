# ===============================
# Root Terraform Configuration — Demo Mode
# ===============================
# Orchestrates all modules for the Tableflow Databricks Workshop in demo mode.
# Provisions everything that self-service mode requires PLUS:
#   - Unity Catalog integration (confluent_catalog_integration)
#   - Flink Materialized Tables (denormalized_hotel_bookings, reviews_with_sentiment)
#   - Tableflow topic enablement (clickstream, denormalized_hotel_bookings, reviews_with_sentiment)
#   - Databricks notebook import (marketing agent)
#
# Supports two modes:
#   Self-service: all resources created per-account (shared_* vars empty)
#   WSA mode:     shared infra provided via shared_* vars (networking, S3,
#                 keypair, and PostgreSQL modules are skipped)
#
# Users run `terraform apply` once and get the entire pipeline.

# ===============================
# Random ID for Resource Naming
# ===============================

resource "random_id" "env_display_id" {
  byte_length = 4
}

# ===============================
# Local Variables
# ===============================

locals {
  prefix          = "${var.prefix}-${var.project_name}"
  resource_suffix = random_id.env_display_id.hex

  # WSA: use per-account email when provided, fall back to self-service email
  effective_email = var.account_email != "" ? var.account_email : var.confluent_cloud_email

  # When shared_* vars are set, use them; otherwise use per-account module outputs.
  use_shared = var.shared_vpc_id != ""

  effective_vpc_id                     = local.use_shared ? var.shared_vpc_id : module.networking[0].vpc_id
  effective_subnet_id                  = local.use_shared ? var.shared_subnet_id : module.networking[0].public_subnet_id
  effective_aws_account                = local.use_shared ? data.aws_caller_identity.current[0].account_id : module.networking[0].aws_account_id
  effective_s3_bucket_name             = local.use_shared ? var.shared_s3_bucket_name : module.s3[0].bucket_name
  effective_s3_bucket_arn              = local.use_shared ? var.shared_s3_bucket_arn : module.s3[0].bucket_arn
  effective_s3_bucket_url              = local.use_shared ? var.shared_s3_bucket_url : module.s3[0].bucket_url
  effective_key_name                   = local.use_shared ? var.shared_key_name : module.keypair[0].key_name
  effective_postgres_dns               = local.use_shared ? var.shared_postgres_hostname : module.postgres[0].public_dns
  effective_postgres_ip                = local.use_shared ? var.shared_postgres_public_ip : module.postgres[0].public_ip
  effective_postgres_db_password       = local.use_shared && var.shared_postgres_db_password != "" ? var.shared_postgres_db_password : var.postgres_db_password
  effective_postgres_debezium_password = local.use_shared && var.shared_postgres_debezium_password != "" ? var.shared_postgres_debezium_password : var.postgres_debezium_password

  common_tags = merge(
    {
      Project     = "Hospitality AI Agent"
      Environment = var.environment
      Created_by  = "Terraform"
      owner_email = local.effective_email
      mode        = "demo"
    },
    var.aws_account_tag != "" ? { workshop_account = var.aws_account_tag } : {}
  )

  iam_role_name = "${local.prefix}-unified-role-${local.resource_suffix}"

  # Topic names: WSA/shared uses CDC-prefixed topics; standalone demo uses plain names
  clickstream_topic = local.use_shared ? "riverhotel.cdc.clickstream" : "clickstream"
  bookings_topic    = local.use_shared ? "riverhotel.cdc.bookings" : "bookings"
  reviews_topic     = local.use_shared ? "riverhotel.cdc.reviews" : "reviews"
  customer_topic    = "riverhotel.cdc.customer"
  hotel_topic       = "riverhotel.cdc.hotel"
}

# AWS account ID lookup (only needed in shared mode where networking module is skipped)
data "aws_caller_identity" "current" {
  count = local.use_shared ? 1 : 0
}

# ===============================
# AWS Networking
# ===============================

module "networking" {
  count  = local.use_shared ? 0 : 1
  source = "../aws/modules/aws-networking"

  prefix      = local.prefix
  common_tags = local.common_tags
}

# ===============================
# AWS SSH Key Pair
# ===============================

module "keypair" {
  count  = local.use_shared ? 0 : 1
  source = "../aws/modules/aws-keypair"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  output_path     = path.module
  common_tags     = local.common_tags
}

# ===============================
# AWS S3 Bucket
# ===============================

module "s3" {
  count  = local.use_shared ? 0 : 1
  source = "../aws/modules/aws-s3"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  common_tags     = local.common_tags
}

# ===============================
# Confluent Platform
# ===============================

module "confluent_platform" {
  source = "../modules/confluent-platform"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  cloud           = "AWS"
  cloud_region    = var.cloud_region
  environment_id  = var.cc_environment_id
  user_email      = local.effective_email
}

# ===============================
# Confluent Tableflow Provider Integration
# ===============================

module "tableflow" {
  source = "../modules/confluent-tableflow"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  environment_id  = module.confluent_platform.environment_id
  cloud_provider  = "aws"

  customer_iam_role_arn = "arn:aws:iam::${local.effective_aws_account}:role/${local.iam_role_name}"

  depends_on = [module.confluent_platform]
}

# ===============================
# Confluent Flink
# ===============================

module "flink" {
  source = "../modules/confluent-flink"

  prefix                      = local.prefix
  resource_suffix             = local.resource_suffix
  cloud                       = "AWS"
  cloud_region                = var.cloud_region
  environment_id              = module.confluent_platform.environment_id
  service_account_id          = module.confluent_platform.service_account_id
  service_account_api_version = module.confluent_platform.service_account_api_version
  service_account_kind        = module.confluent_platform.service_account_kind

  depends_on = [module.confluent_platform]
}

# ===============================
# AWS PostgreSQL
# ===============================

module "postgres" {
  count  = local.use_shared ? 0 : 1
  source = "../aws/modules/aws-postgres"

  prefix              = local.prefix
  vpc_id              = local.effective_vpc_id
  subnet_id           = local.effective_subnet_id
  key_name            = local.effective_key_name
  instance_type       = var.postgres_instance_type
  allowed_cidr_blocks = var.allowed_cidr_blocks
  db_name             = var.postgres_db_name
  db_username         = var.postgres_db_username
  db_password         = local.effective_postgres_db_password
  debezium_password   = local.effective_postgres_debezium_password
  common_tags         = local.common_tags

  depends_on = [module.networking, module.keypair]
}

# ===============================
# AWS IAM (Phase 1: Create role with initial trust policy)
# ===============================

module "iam" {
  source = "../aws/modules/aws-iam"

  prefix                                    = local.prefix
  resource_suffix                           = local.resource_suffix
  aws_account_id                            = local.effective_aws_account
  s3_bucket_arn                             = local.effective_s3_bucket_arn
  s3_bucket_id                              = local.effective_s3_bucket_name
  confluent_iam_role_arn                    = module.tableflow.iam_role_arn
  confluent_external_id                     = module.tableflow.external_id
  databricks_account_id                     = var.databricks_account_id
  databricks_storage_credential_external_id = ""
  common_tags                               = local.common_tags

  depends_on = [module.s3, module.tableflow]
}

# ===============================
# Databricks Integration (Storage Credential Only)
# ===============================

module "databricks" {
  source = "../modules/databricks"

  providers = {
    databricks.workspace = databricks.workspace
  }

  prefix                      = local.prefix
  resource_suffix             = local.resource_suffix
  cloud_provider              = "aws"
  iam_role_arn                = module.iam.role_arn
  s3_bucket_url               = local.effective_s3_bucket_url
  user_email                  = var.databricks_user_email
  sso_email                   = var.databricks_sso_email
  service_principal_client_id = var.databricks_service_principal_client_id
  kafka_cluster_id            = module.confluent_platform.kafka_cluster_id
  sql_warehouse_name          = var.databricks_sql_warehouse_name

  # WSA mode (shared infra): create users via SCIM and skip admins membership.
  lookup_existing_users = !local.use_shared
  add_user_to_admins    = !local.use_shared

  depends_on = [module.iam, module.s3, module.tableflow]
}

# ===============================
# AWS IAM Trust Policy Update - PHASE 1 (self-service only)
# ===============================

resource "null_resource" "update_iam_trust_policy_phase1" {
  count = local.use_shared ? 0 : 1

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo "Phase 1: Updating IAM trust policy with Databricks external ID..."
      aws iam update-assume-role-policy \
        --role-name ${module.iam.role_name} \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": {
                "AWS": "arn:aws:iam::414351767826:root"
              },
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": "${module.databricks.storage_credential_external_id}"
                }
              }
            },
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": {
                "AWS": "arn:aws:iam::${local.effective_aws_account}:root"
              }
            }
          ]
        }'
      echo "Phase 1 complete!"
    EOT
  }

  triggers = {
    storage_credential_id = module.databricks.storage_credential_id
    role_arn              = module.iam.role_arn
  }

  depends_on = [module.databricks, module.iam]
}

# ===============================
# Wait for Phase 1 Trust Policy Propagation
# ===============================

resource "null_resource" "wait_for_trust_policy_phase1" {
  count = local.use_shared ? 0 : 1

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "Waiting 60 seconds for Phase 1 IAM propagation..."
      sleep 60
      echo "Phase 1 propagation wait complete!"
    EOT
  }

  depends_on = [null_resource.update_iam_trust_policy_phase1]
}

# ===============================
# AWS IAM Trust Policy Update - PHASE 2
# ===============================

resource "null_resource" "update_iam_trust_policy_phase2" {
  count = local.use_shared ? 0 : 1

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo "Phase 2: Updating IAM trust policy with complete policy..."
      aws iam update-assume-role-policy \
        --role-name ${module.iam.role_name} \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "AWS": "${module.tableflow.iam_role_arn}"
              },
              "Action": "sts:AssumeRole",
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": "${module.tableflow.external_id}"
                }
              }
            },
            {
              "Effect": "Allow",
              "Principal": {
                "AWS": "${module.tableflow.iam_role_arn}"
              },
              "Action": "sts:TagSession"
            },
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": {
                "AWS": "arn:aws:iam::414351767826:root"
              },
              "Condition": {
                "StringEquals": {
                  "sts:ExternalId": "${module.databricks.storage_credential_external_id}"
                }
              }
            },
            {
              "Effect": "Allow",
              "Action": "sts:AssumeRole",
              "Principal": {
                "AWS": "${module.iam.role_arn}"
              }
            }
          ]
        }'
      echo "Phase 2 complete!"
    EOT
  }

  triggers = {
    storage_credential_id = module.databricks.storage_credential_id
    role_arn              = module.iam.role_arn
    phase                 = "final_specific_role_arn"
  }

  depends_on = [
    null_resource.wait_for_trust_policy_phase1,
    module.tableflow,
    module.databricks
  ]
}

# ===============================
# Wait for Phase 2 Trust Policy Propagation
# ===============================

resource "null_resource" "wait_for_trust_policy_phase2" {
  count = local.use_shared ? 0 : 1

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "Waiting 30 seconds for Phase 2 IAM propagation..."
      sleep 30
      echo "Phase 2 propagation wait complete!"
    EOT
  }

  depends_on = [null_resource.update_iam_trust_policy_phase2]
}

# ===============================
# Databricks External Location
# ===============================

resource "databricks_external_location" "main" {
  count    = local.use_shared ? 0 : 1
  provider = databricks.workspace

  name            = "${local.prefix}-external-location-${local.resource_suffix}"
  url             = local.effective_s3_bucket_url
  credential_name = module.databricks.storage_credential_name
  comment         = "External location for Unity Catalog and Tableflow S3 access"
  force_destroy   = true
  skip_validation = true

  depends_on = [null_resource.wait_for_trust_policy_phase2]
}

# ===============================
# Databricks External Location Grants
# ===============================

resource "databricks_grants" "external_location" {
  count    = local.use_shared ? 0 : 1
  provider = databricks.workspace

  external_location = databricks_external_location.main[0].name

  grant {
    principal = var.databricks_user_email
    privileges = [
      "ALL_PRIVILEGES",
      "MANAGE",
      "CREATE_EXTERNAL_TABLE",
      "CREATE_EXTERNAL_VOLUME",
      "READ_FILES",
      "WRITE_FILES",
      "CREATE_MANAGED_STORAGE",
      "EXTERNAL_USE_LOCATION"
    ]
  }

  grant {
    principal = var.databricks_service_principal_client_id
    privileges = [
      "ALL_PRIVILEGES",
      "MANAGE",
      "CREATE_EXTERNAL_TABLE",
      "CREATE_EXTERNAL_VOLUME",
      "READ_FILES",
      "WRITE_FILES",
      "CREATE_MANAGED_STORAGE",
      "EXTERNAL_USE_LOCATION"
    ]
  }

  depends_on = [module.databricks]
}

# ===============================
# Databricks Catalog
# ===============================

resource "databricks_catalog" "main" {
  provider = databricks.workspace

  name          = "${local.prefix}-${local.resource_suffix}"
  comment       = "Dedicated catalog for Confluent Tableflow integration"
  storage_root  = "${local.effective_s3_bucket_url}${local.prefix}/catalog/"
  force_destroy = true

  depends_on = [module.databricks, databricks_external_location.main]
}

# ===============================
# Databricks Catalog Grants
# ===============================

resource "databricks_grants" "catalog" {
  provider = databricks.workspace

  catalog = databricks_catalog.main.name

  grant {
    principal = var.databricks_user_email
    privileges = [
      "ALL_PRIVILEGES",
      "USE_CATALOG",
      "CREATE_SCHEMA",
      "USE_SCHEMA",
      "EXTERNAL_USE_SCHEMA"
    ]
  }

  grant {
    principal = var.databricks_service_principal_client_id
    privileges = [
      "ALL_PRIVILEGES",
      "USE_CATALOG",
      "CREATE_SCHEMA",
      "USE_SCHEMA",
      "EXTERNAL_USE_SCHEMA",
      "CREATE_TABLE"
    ]
  }

  dynamic "grant" {
    for_each = var.databricks_sso_email != "" ? [var.databricks_sso_email] : []
    content {
      principal = grant.value
      privileges = [
        "ALL_PRIVILEGES",
        "USE_CATALOG",
        "CREATE_SCHEMA",
        "USE_SCHEMA",
        "EXTERNAL_USE_SCHEMA"
      ]
    }
  }

  depends_on = [databricks_catalog.main]
}

# ===============================
# Data Quality Rules (Data Contracts)
# ===============================
# Demo standalone path registers all schemas with no topic prefix.
# Skip in WSA/shared mode to avoid CDC schema subject collisions.

module "data_contracts" {
  source = "../modules/confluent-data-contracts"

  count = local.use_shared ? 0 : 1

  environment_id             = module.confluent_platform.environment_id
  kafka_cluster_id           = module.confluent_platform.kafka_cluster_id
  kafka_rest_endpoint        = module.confluent_platform.kafka_rest_endpoint
  kafka_api_key              = module.confluent_platform.kafka_api_key
  kafka_api_secret           = module.confluent_platform.kafka_api_secret
  schema_registry_id         = module.confluent_platform.schema_registry_id
  schema_registry_endpoint   = module.confluent_platform.schema_registry_endpoint
  schema_registry_api_key    = module.confluent_platform.schema_registry_api_key
  schema_registry_api_secret = module.confluent_platform.schema_registry_api_secret
  schemas_dir                = "${path.module}/../../data/schemas"
  topic_prefix               = ""
  register_all_schemas       = true

  depends_on = [module.confluent_platform]
}

# ===============================
# Confluent PostgreSQL CDC Connector
# ===============================

module "connectors" {
  source = "../modules/confluent-connectors"

  prefix               = local.prefix
  environment_id       = module.confluent_platform.environment_id
  kafka_cluster_id     = module.confluent_platform.kafka_cluster_id
  service_account_id   = module.confluent_platform.service_account_id
  postgres_hostname    = local.effective_postgres_dns
  postgres_port        = var.postgres_db_port
  database_name        = var.postgres_db_name
  debezium_username    = var.postgres_debezium_username
  debezium_password    = local.effective_postgres_debezium_password
  table_include_list   = var.table_include_list
  ssh_key_path         = local.use_shared ? "" : module.keypair[0].private_key_path
  initial_wait_seconds = local.use_shared ? 0 : 90

  depends_on = [module.postgres, module.confluent_platform, module.keypair, module.data_contracts, null_resource.datagen_setup]
}

# ===============================
# Confluent Flink Statements (ALTER TABLE on CDC topics)
# ===============================

module "flink_statements" {
  source = "../modules/confluent-flink-statements"

  organization_id            = module.confluent_platform.organization_id
  environment_id             = module.confluent_platform.environment_id
  environment_name           = module.confluent_platform.environment_name
  kafka_cluster_display_name = module.confluent_platform.kafka_cluster_display_name
  compute_pool_id            = module.flink.compute_pool_id
  service_account_id         = module.confluent_platform.service_account_id
  flink_api_key              = module.flink.flink_api_key
  flink_api_secret           = module.flink.flink_api_secret
  flink_rest_endpoint        = module.flink.flink_rest_endpoint

  clickstream_topic = local.clickstream_topic
  bookings_topic    = local.bookings_topic
  reviews_topic     = local.reviews_topic

  depends_on = [module.connectors, module.flink]
}

# ===============================
# Data Generator Configuration
# ===============================

module "data_generator" {
  count  = local.use_shared ? 0 : 1
  source = "../modules/data-generator"

  output_path                = "../../data/connections"
  postgres_hostname          = local.effective_postgres_ip
  postgres_port              = var.postgres_db_port
  postgres_username          = var.postgres_db_username
  postgres_password          = local.effective_postgres_db_password
  postgres_database          = var.postgres_db_name
  kafka_bootstrap_endpoint   = module.confluent_platform.bootstrap_endpoint_url
  kafka_api_key              = module.confluent_platform.kafka_api_key
  kafka_api_secret           = module.confluent_platform.kafka_api_secret
  schema_registry_endpoint   = module.confluent_platform.schema_registry_endpoint
  schema_registry_api_key    = module.confluent_platform.schema_registry_api_key
  schema_registry_api_secret = module.confluent_platform.schema_registry_api_secret

  depends_on = [module.postgres, module.confluent_platform]
}

# =========================================================================
# DEMO MODE RESOURCES
# =========================================================================
# Everything below this line is specific to demo mode and does not exist
# in the self-service terraform/aws/ root.

# ===============================
# Tableflow API Key
# ===============================
# Catalog integration and Tableflow topic resources require a
# Tableflow-scoped API key, not a Cloud API key.

resource "confluent_api_key" "tableflow" {
  display_name = "${local.prefix}-tableflow-${local.resource_suffix}"

  owner {
    id          = module.confluent_platform.service_account_id
    api_version = module.confluent_platform.service_account_api_version
    kind        = module.confluent_platform.service_account_kind
  }

  managed_resource {
    id          = "tableflow"
    api_version = "tableflow/v1"
    kind        = "Tableflow"

    environment {
      id = module.confluent_platform.environment_id
    }
  }

  depends_on = [module.confluent_platform]
}

# ===============================
# Unity Catalog Integration
# ===============================
# Connects Confluent Tableflow to Databricks Unity Catalog so that
# Tableflow-enabled topics appear as external Delta Lake tables.

module "catalog_integration" {
  source = "../modules/confluent-catalog-integration"

  prefix           = local.prefix
  resource_suffix  = local.resource_suffix
  environment_id   = module.confluent_platform.environment_id
  kafka_cluster_id = module.confluent_platform.kafka_cluster_id

  databricks_workspace_url    = var.databricks_host
  databricks_catalog_name     = databricks_catalog.main.name
  databricks_sp_client_id     = var.databricks_service_principal_client_id
  databricks_sp_client_secret = var.databricks_service_principal_client_secret

  api_key    = confluent_api_key.tableflow.id
  api_secret = confluent_api_key.tableflow.secret

  depends_on = [
    module.flink_statements,
    module.connectors,
    databricks_catalog.main,
    confluent_api_key.tableflow,
  ]
}

# ===============================
# Flink Materialized Tables
# ===============================
# Creates denormalized_hotel_bookings and reviews_with_sentiment via
# persistent Flink Materialized Tables. These are the statements users
# run manually in self-service LAB4.

module "flink_ctas" {
  source = "../modules/confluent-flink-ctas"

  organization_id            = module.confluent_platform.organization_id
  environment_id             = module.confluent_platform.environment_id
  environment_name           = module.confluent_platform.environment_name
  kafka_cluster_id           = module.confluent_platform.kafka_cluster_id
  kafka_cluster_display_name = module.confluent_platform.kafka_cluster_display_name
  compute_pool_id            = module.flink.compute_pool_id
  service_account_id         = module.confluent_platform.service_account_id
  flink_api_key              = module.flink.flink_api_key
  flink_api_secret           = module.flink.flink_api_secret
  flink_rest_endpoint        = module.flink.flink_rest_endpoint

  bookings_topic = local.bookings_topic
  reviews_topic  = local.reviews_topic
  customer_topic = local.customer_topic
  hotel_topic    = local.hotel_topic

  # flink_statements configures changelog/watermark; connectors ensure CDC topics exist
  depends_on = [module.flink_statements, module.connectors]
}

# ===============================
# Tableflow Topic Enablement
# ===============================
# Enables Tableflow on clickstream, denormalized_hotel_bookings, and
# reviews_with_sentiment. The materialized table topics need a delay
# before Tableflow can be enabled (handled by time_sleep inside the module).

module "tableflow_topics" {
  source = "../modules/confluent-tableflow-topics"

  environment_id          = module.confluent_platform.environment_id
  kafka_cluster_id        = module.confluent_platform.kafka_cluster_id
  cloud_provider          = "aws"
  s3_bucket_name          = local.effective_s3_bucket_name
  provider_integration_id = module.tableflow.integration_id
  clickstream_topic       = local.clickstream_topic

  api_key    = confluent_api_key.tableflow.id
  api_secret = confluent_api_key.tableflow.secret

  depends_on = [
    module.flink_ctas,
    module.catalog_integration,
    confluent_api_key.tableflow,
  ]
}

# ===============================
# Wait for Tableflow Sync to Unity Catalog
# ===============================
# After Tableflow is enabled on topics, the Delta Lake tables need time
# to appear in Unity Catalog. This sleep allows the initial sync to
# complete before the hotel_performance view is created.

resource "time_sleep" "wait_for_tableflow_sync" {
  create_duration = "180s"
  depends_on      = [module.tableflow_topics]
}

# ===============================
# Hotel Performance View
# ===============================
# Creates the hotel_performance SQL view in Databricks via the SQL
# Statement Execution API. Uses the service principal OAuth M2M token
# for authentication. Retries up to 5 times with 60s delay to handle
# cases where Tableflow tables are not yet visible in Unity Catalog.

resource "null_resource" "hotel_performance_view" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e

      TOKEN=$(curl -sf -X POST "$DB_HOST/oidc/v1/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials&client_id=$DB_CLIENT_ID&client_secret=$DB_CLIENT_SECRET&scope=all-apis" \
        | jq -r '.access_token')

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "ERROR: Failed to obtain Databricks OAuth token"
        exit 1
      fi

      SQL='CREATE OR REPLACE VIEW hotel_performance AS WITH booking_metrics AS (SELECT hotel_id, MAX(hotel_name) AS hotel_name, MAX(hotel_city) AS hotel_city, MAX(hotel_country) AS hotel_country, MAX(hotel_category) AS hotel_category, MAX(hotel_description) AS hotel_description, COUNT(*) AS total_bookings_count, SUM(guest_count) AS total_guest_count, SUM(booking_amount) AS total_booking_amount FROM denormalized_hotel_bookings WHERE booking_date >= current_timestamp() - INTERVAL 7 DAYS GROUP BY hotel_id), review_metrics AS (SELECT hotel_id, CAST(AVG(review_rating) AS DECIMAL(10, 2)) AS average_review_rating, COUNT(*) AS review_count, SUM(CASE WHEN cleanliness_label = '"'"'Positive'"'"' THEN 1 ELSE 0 END) AS positive_cleanliness_count, SUM(CASE WHEN amenities_label = '"'"'Positive'"'"' THEN 1 ELSE 0 END) AS positive_amenities_count, SUM(CASE WHEN service_label = '"'"'Positive'"'"' THEN 1 ELSE 0 END) AS positive_service_count FROM reviews_with_sentiment GROUP BY hotel_id) SELECT bm.*, rm.average_review_rating, rm.review_count, rm.positive_cleanliness_count, rm.positive_amenities_count, rm.positive_service_count FROM booking_metrics bm LEFT JOIN review_metrics rm ON rm.hotel_id = bm.hotel_id'

      MAX_RETRIES=5
      RETRY_DELAY=60

      for i in $(seq 1 $MAX_RETRIES); do
        echo "Attempt $i/$MAX_RETRIES: Creating hotel_performance view..."

        PAYLOAD=$(jq -n \
          --arg warehouse_id "$DB_WAREHOUSE_ID" \
          --arg catalog "$DB_CATALOG" \
          --arg schema "$DB_SCHEMA" \
          --arg statement "$SQL" \
          '{warehouse_id: $warehouse_id, catalog: $catalog, schema: $schema, statement: $statement, wait_timeout: "30s"}')

        RESPONSE=$(curl -s -X POST "$DB_HOST/api/2.0/sql/statements" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d "$PAYLOAD")

        STATUS=$(echo "$RESPONSE" | jq -r '.status.state')

        if [ "$STATUS" = "SUCCEEDED" ]; then
          echo "hotel_performance view created successfully"
          exit 0
        fi

        echo "Attempt $i failed (status: $STATUS). Response: $(echo "$RESPONSE" | jq -c '.status')"

        if [ "$i" -lt "$MAX_RETRIES" ]; then
          echo "Retrying in $RETRY_DELAY seconds..."
          sleep $RETRY_DELAY
        fi
      done

      echo "ERROR: Failed to create hotel_performance view after $MAX_RETRIES attempts"
      exit 1
    EOT

    environment = {
      DB_HOST          = var.databricks_host
      DB_CLIENT_ID     = var.databricks_service_principal_client_id
      DB_CLIENT_SECRET = var.databricks_service_principal_client_secret
      DB_WAREHOUSE_ID  = module.databricks.sql_warehouse_id
      DB_CATALOG       = databricks_catalog.main.name
      DB_SCHEMA        = module.databricks.databricks_schema_name
    }
  }

  triggers = {
    catalog_name = databricks_catalog.main.name
    schema_name  = module.databricks.databricks_schema_name
  }

  depends_on = [time_sleep.wait_for_tableflow_sync]
}

# ===============================
# Databricks Notebook Import
# ===============================
# Pre-imports the marketing agent notebook so users can open it
# directly instead of importing from a URL.

resource "databricks_notebook" "marketing_agent" {
  provider = databricks.workspace

  path     = "/Shared/workshop/river_hotel_marketing_agent"
  language = "PYTHON"
  source   = "${path.module}/../../labs/shared/river_hotel_marketing_agent.ipynb"
  format   = "JUPYTER"

  depends_on = [databricks_catalog.main]
}
