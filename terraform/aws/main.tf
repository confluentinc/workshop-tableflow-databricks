# ===============================
# Root Terraform Configuration
# ===============================
# Orchestrates all modules for the Tableflow Databricks Workshop.
#
# Supports two modes:
#   Self-service: all resources created per-account (shared_* vars empty)
#   WSA mode:     shared infra provided via shared_* vars (networking, S3,
#                 keypair, and PostgreSQL modules are skipped)

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

  effective_vpc_id         = local.use_shared ? var.shared_vpc_id : module.networking[0].vpc_id
  effective_subnet_id      = local.use_shared ? var.shared_subnet_id : module.networking[0].public_subnet_id
  effective_aws_account    = local.use_shared ? data.aws_caller_identity.current[0].account_id : module.networking[0].aws_account_id
  effective_s3_bucket_name = local.use_shared ? var.shared_s3_bucket_name : module.s3[0].bucket_name
  effective_s3_bucket_arn  = local.use_shared ? var.shared_s3_bucket_arn : module.s3[0].bucket_arn
  effective_s3_bucket_url  = local.use_shared ? var.shared_s3_bucket_url : module.s3[0].bucket_url
  effective_key_name       = local.use_shared ? var.shared_key_name : module.keypair[0].key_name
  effective_postgres_dns              = local.use_shared ? var.shared_postgres_hostname : module.postgres[0].public_dns
  effective_postgres_ip               = local.use_shared ? var.shared_postgres_public_ip : module.postgres[0].public_ip
  effective_postgres_db_password       = local.use_shared && var.shared_postgres_db_password != "" ? var.shared_postgres_db_password : var.postgres_db_password
  effective_postgres_debezium_password = local.use_shared && var.shared_postgres_debezium_password != "" ? var.shared_postgres_debezium_password : var.postgres_debezium_password

  common_tags = merge(
    {
      Project     = "Hospitality AI Agent"
      Environment = var.environment
      Created_by  = "Terraform"
      owner_email = local.effective_email
    },
    var.aws_account_tag != "" ? { workshop_account = var.aws_account_tag } : {}
  )

  # IAM role name for Confluent Provider Integration
  iam_role_name = "${local.prefix}-unified-role-${local.resource_suffix}"
}

# AWS account ID lookup (only needed in shared mode where networking module is skipped)
data "aws_caller_identity" "current" {
  count = local.use_shared ? 1 : 0
}

# ===============================
# AWS Networking (skipped when shared_vpc_id is set)
# ===============================

module "networking" {
  count  = local.use_shared ? 0 : 1
  source = "./modules/aws-networking"

  prefix      = local.prefix
  common_tags = local.common_tags
}

# ===============================
# AWS SSH Key Pair (skipped when shared_key_name is set)
# ===============================

module "keypair" {
  count  = local.use_shared ? 0 : 1
  source = "./modules/aws-keypair"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  output_path     = path.module
  common_tags     = local.common_tags
}

# ===============================
# AWS S3 Bucket (skipped when shared_s3_bucket_arn is set)
# ===============================

module "s3" {
  count  = local.use_shared ? 0 : 1
  source = "./modules/aws-s3"

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
# AWS PostgreSQL (skipped when shared_postgres_hostname is set)
# ===============================

module "postgres" {
  count  = local.use_shared ? 0 : 1
  source = "./modules/aws-postgres"

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
# Note: IAM role is created first with Confluent trust policy.
# Databricks trust policy is updated after storage credential is created.

module "iam" {
  source = "./modules/aws-iam"

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

  depends_on = [module.iam, module.s3, module.tableflow]
}

# ===============================
# AWS IAM Trust Policy Update - PHASE 1 (self-service only)
# ===============================
# First update: Databricks external ID + account root for self-assumption.
# Skipped in shared mode — aws-shared creates the storage credential and
# manages its own trust policy; the per-account IAM role only needs the
# Confluent trust that the IAM module sets in the initial assume_role_policy.

resource "null_resource" "update_iam_trust_policy_phase1" {
  count = local.use_shared ? 0 : 1

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e

      echo "🔧 Phase 1: Updating IAM trust policy with Databricks external ID..."
      echo "   Role: ${module.iam.role_name}"
      echo "   Databricks External ID: ${module.databricks.storage_credential_external_id}"
      echo ""

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

      echo "✅ Phase 1 complete!"
    EOT
  }

  triggers = {
    storage_credential_id = module.databricks.storage_credential_id
    role_arn              = module.iam.role_arn
  }

  depends_on = [module.databricks, module.iam]
}

# ===============================
# Wait for Phase 1 Trust Policy Propagation (self-service only)
# ===============================

resource "null_resource" "wait_for_trust_policy_phase1" {
  count = local.use_shared ? 0 : 1

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "⏳ Waiting 60 seconds for Phase 1 IAM propagation..."
      sleep 60
      echo "✅ Phase 1 propagation wait complete!"
    EOT
  }

  depends_on = [null_resource.update_iam_trust_policy_phase1]
}

# ===============================
# AWS IAM Trust Policy Update - PHASE 2 (self-service only)
# ===============================
# Complete trust policy with Confluent + Databricks + specific role ARN.
# Skipped in shared mode for the same reason as Phase 1.

resource "null_resource" "update_iam_trust_policy_phase2" {
  count = local.use_shared ? 0 : 1

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e

      echo "🔧 Phase 2: Updating IAM trust policy with complete policy..."
      echo "   Role: ${module.iam.role_name}"
      echo "   Databricks External ID: ${module.databricks.storage_credential_external_id}"
      echo "   Confluent External ID: ${module.tableflow.external_id}"
      echo ""

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

      echo "✅ Phase 2 complete!"
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
# Wait for Phase 2 Trust Policy Propagation (self-service only)
# ===============================

resource "null_resource" "wait_for_trust_policy_phase2" {
  count = local.use_shared ? 0 : 1

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "⏳ Waiting 30 seconds for Phase 2 IAM propagation..."
      sleep 30
      echo "✅ Phase 2 propagation wait complete!"
    EOT
  }

  depends_on = [null_resource.update_iam_trust_policy_phase2]
}

# ===============================
# Databricks External Location (self-service only)
# ===============================
# In self-service mode, the per-account external location covers the entire
# bucket (single account, no overlap risk). In shared mode (wsa build),
# aws-shared creates a bucket-root external location that covers all paths
# including Confluent Tableflow's internal storage structure.

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
# Databricks External Location Grants (self-service only)
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
# In shared mode the catalog's storage_root falls under the bucket-root
# external location created by aws-shared. In self-service mode it falls
# under the per-account external location above.

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

  depends_on = [module.postgres, module.confluent_platform, module.keypair, null_resource.shadowtraffic_setup]
}

# ===============================
# Confluent Flink Statements (ALTER TABLE on CDC topics)
# ===============================
# Configures CDC topics for direct use with Tableflow and temporal joins:
# - clickstream: append mode
# - customer/hotel: upsert mode + primary key + watermark
# - bookings: watermark

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

  clickstream_topic   = local.use_shared ? "riverhotel.cdc.clickstream" : "clickstream"
  bookings_topic      = local.use_shared ? "riverhotel.cdc.bookings" : "bookings"
  hotel_reviews_topic = local.use_shared ? "riverhotel.cdc.hotel_reviews" : "hotel_reviews"

  depends_on = [module.connectors, module.flink]
}

# ===============================
# Data Generator Configuration
# ===============================

module "data_generator" {
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
