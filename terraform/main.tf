# ===============================
# Root Terraform Configuration
# ===============================
# Orchestrates all modules for the Tableflow Databricks Workshop

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

  common_tags = {
    Project     = "Hospitality AI Agent"
    Environment = var.environment
    Created_by  = "Terraform"
    owner_email = var.email
  }

  # IAM role name for Confluent Provider Integration
  # Must be defined before the role exists due to circular dependency
  iam_role_name = "${local.prefix}-unified-role-${local.resource_suffix}"
}

# ===============================
# AWS Networking
# ===============================

module "networking" {
  source = "./modules/aws-networking"

  prefix      = local.prefix
  common_tags = local.common_tags
}

# ===============================
# AWS SSH Key Pair
# ===============================

module "keypair" {
  source = "./modules/aws-keypair"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  output_path     = path.module
  common_tags     = local.common_tags
}

# ===============================
# AWS S3 Bucket
# ===============================

module "s3" {
  source = "./modules/aws-s3"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  common_tags     = local.common_tags
}

# ===============================
# Confluent Platform
# ===============================

module "confluent_platform" {
  source = "./modules/confluent-platform"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  cloud_region    = var.cloud_region
}

# ===============================
# Confluent Tableflow Provider Integration
# ===============================

module "tableflow" {
  source = "./modules/confluent-tableflow"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  environment_id  = module.confluent_platform.environment_id

  # Note: This creates a circular dependency that we resolve with IAM trust policy updates
  customer_iam_role_arn = "arn:aws:iam::${module.networking.aws_account_id}:role/${local.iam_role_name}"

  depends_on = [module.confluent_platform]
}

# ===============================
# Confluent Flink
# ===============================

module "flink" {
  source = "./modules/confluent-flink"

  prefix                      = local.prefix
  resource_suffix             = local.resource_suffix
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
  source = "./modules/aws-postgres"

  prefix              = local.prefix
  vpc_id              = module.networking.vpc_id
  subnet_id           = module.networking.public_subnet_id
  key_name            = module.keypair.key_name
  instance_type       = var.postgres_instance_type
  allowed_cidr_blocks = var.allowed_cidr_blocks
  db_name             = var.postgres_db_name
  db_username         = var.postgres_db_username
  db_password         = var.postgres_db_password
  debezium_password   = var.postgres_debezium_password
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
  aws_account_id                            = module.networking.aws_account_id
  s3_bucket_arn                             = module.s3.bucket_arn
  s3_bucket_id                              = module.s3.bucket_name
  confluent_iam_role_arn                    = module.tableflow.iam_role_arn
  confluent_external_id                     = module.tableflow.external_id
  databricks_account_id                     = var.databricks_account_id
  databricks_storage_credential_external_id = "" # Will be updated by null_resource after databricks module
  common_tags                               = local.common_tags

  depends_on = [module.s3, module.tableflow]
}

# ===============================
# Databricks Integration (Storage Credential Only)
# ===============================

module "databricks" {
  source = "./modules/databricks"

  providers = {
    databricks.workspace = databricks.workspace
  }

  prefix                      = local.prefix
  resource_suffix             = local.resource_suffix
  iam_role_arn                = module.iam.role_arn
  s3_bucket_url               = module.s3.bucket_url
  user_email                  = var.databricks_user_email
  service_principal_client_id = var.databricks_service_principal_client_id
  kafka_cluster_id            = module.confluent_platform.kafka_cluster_id

  depends_on = [module.iam, module.s3, module.tableflow]
}

# ===============================
# AWS IAM Trust Policy Update - PHASE 1
# ===============================
# First update: Databricks external ID + account root for self-assumption
# This allows the role to be assumed before we add the specific role ARN

resource "null_resource" "update_iam_trust_policy_phase1" {
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
                "AWS": "arn:aws:iam::${module.networking.aws_account_id}:root"
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
# Wait for Phase 1 Trust Policy Propagation
# ===============================

resource "null_resource" "wait_for_trust_policy_phase1" {
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
# AWS IAM Trust Policy Update - PHASE 2 (Final)
# ===============================
# Second update: Complete trust policy with Confluent + Databricks + specific role ARN

resource "null_resource" "update_iam_trust_policy_phase2" {
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
# Wait for Phase 2 Trust Policy Propagation
# ===============================

resource "null_resource" "wait_for_trust_policy_phase2" {
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
# Databricks External Location (After Trust Policy Update)
# ===============================
# Created AFTER the two-phase trust policy update and wait periods.
# Note: We cannot validate IAM assumability from Terraform because the trust
# policy only allows Databricks (414351767826) to assume the role, not the
# Terraform user. The extended wait times (90s + 60s = 150s) should be sufficient.

resource "databricks_external_location" "main" {
  provider = databricks.workspace

  name            = "${local.prefix}-external-location-${local.resource_suffix}"
  url             = module.s3.bucket_url
  credential_name = module.databricks.storage_credential_name
  comment         = "External location for Unity Catalog S3 access"
  force_destroy   = true

  depends_on = [null_resource.wait_for_trust_policy_phase2]
}

# ===============================
# Databricks External Location Grants
# ===============================

resource "databricks_grants" "external_location" {
  provider = databricks.workspace

  external_location = databricks_external_location.main.name

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
}

# ===============================
# Databricks Catalog (After External Location)
# ===============================

resource "databricks_catalog" "main" {
  provider = databricks.workspace

  name          = "${local.prefix}-${local.resource_suffix}"
  comment       = "Dedicated catalog for Confluent Tableflow integration"
  storage_root  = "${module.s3.bucket_url}catalog/"
  force_destroy = true

  depends_on = [databricks_external_location.main]
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

  depends_on = [databricks_catalog.main]
}

# ===============================
# Confluent PostgreSQL CDC Connector
# ===============================

module "connectors" {
  source = "./modules/confluent-connectors"

  prefix             = local.prefix
  create_connector   = var.create_postgres_cdc_connector
  environment_id     = module.confluent_platform.environment_id
  kafka_cluster_id   = module.confluent_platform.kafka_cluster_id
  service_account_id = module.confluent_platform.service_account_id
  postgres_hostname  = module.postgres.public_dns
  postgres_port      = var.postgres_db_port
  database_name      = var.postgres_db_name
  debezium_username  = var.postgres_debezium_username
  debezium_password  = var.postgres_debezium_password
  ssh_key_path       = module.keypair.private_key_path

  depends_on = [module.postgres, module.confluent_platform, module.keypair]
}

# ===============================
# Data Generator Configuration
# ===============================

module "data_generator" {
  source = "./modules/data-generator"

  output_path                = "../data/connections"
  postgres_hostname          = module.postgres.public_ip
  postgres_port              = var.postgres_db_port
  postgres_username          = var.postgres_db_username
  postgres_password          = var.postgres_db_password
  postgres_database          = var.postgres_db_name
  kafka_bootstrap_endpoint   = module.confluent_platform.bootstrap_endpoint_url
  kafka_api_key              = module.confluent_platform.kafka_api_key
  kafka_api_secret           = module.confluent_platform.kafka_api_secret
  schema_registry_endpoint   = module.confluent_platform.schema_registry_endpoint
  schema_registry_api_key    = module.confluent_platform.schema_registry_api_key
  schema_registry_api_secret = module.confluent_platform.schema_registry_api_secret

  depends_on = [module.postgres, module.confluent_platform]
}
