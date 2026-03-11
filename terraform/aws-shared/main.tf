# ===============================
# Shared Workshop Infrastructure
# ===============================
# Runs ONCE before `wsa build`. Provisions resources shared across all
# 95 workshop accounts: VPC, S3, SSH keypair, and PostgreSQL.
#
# Per-account Terraform (terraform/aws/) receives these outputs as
# input variables (shared_vpc_id, shared_s3_bucket_arn, etc.).
#
# Usage (via wsa):
#   wsa build --shared-infra terraform/aws-shared/ ...
#
# Usage (manual):
#   cd terraform/aws-shared
#   terraform init && terraform apply

resource "random_id" "suffix" {
  byte_length = 4
}

resource "random_password" "postgres_db" {
  length  = 24
  special = false
}

resource "random_password" "postgres_debezium" {
  length  = 24
  special = false
}

locals {
  resource_suffix = random_id.suffix.hex

  effective_postgres_db_password       = coalesce(var.postgres_db_password, random_password.postgres_db.result)
  effective_postgres_debezium_password = coalesce(var.postgres_debezium_password, random_password.postgres_debezium.result)

  common_tags = merge(
    {
      Project     = "Workshop Shared Infrastructure"
      Environment = "workshop"
      Created_by  = "Terraform"
      owner_email = var.owner_email
    },
    var.run_id != "" ? { wsa_run_id = var.run_id } : {}
  )
}

# ===============================
# Networking (1 VPC for all accounts)
# ===============================

module "networking" {
  source = "../aws/modules/aws-networking"

  prefix      = var.prefix
  common_tags = local.common_tags
}

# ===============================
# SSH Key Pair (1 keypair for all EC2 instances)
# ===============================

module "keypair" {
  source = "../aws/modules/aws-keypair"

  prefix          = var.prefix
  resource_suffix = local.resource_suffix
  output_path     = path.module
  common_tags     = local.common_tags
}

# ===============================
# S3 Bucket (1 bucket for Tableflow + Databricks)
# ===============================

module "s3" {
  source = "../aws/modules/aws-s3"

  prefix          = var.prefix
  resource_suffix = local.resource_suffix
  expiration_days = var.s3_expiration_days
  common_tags     = local.common_tags
}

# ===============================
# PostgreSQL (1 × m5.2xlarge with 95 replication slots)
# ===============================

module "postgres" {
  source = "../aws/modules/aws-postgres"

  prefix                = var.prefix
  vpc_id                = module.networking.vpc_id
  subnet_id             = module.networking.public_subnet_id
  key_name              = module.keypair.key_name
  instance_type         = var.postgres_instance_type
  volume_size           = var.postgres_volume_size
  allowed_cidr_blocks   = var.allowed_cidr_blocks
  db_name               = var.postgres_db_name
  db_username           = var.postgres_db_username
  db_password           = local.effective_postgres_db_password
  debezium_password     = local.effective_postgres_debezium_password
  max_replication_slots = var.postgres_max_replication_slots
  max_wal_senders       = var.postgres_max_wal_senders
  max_connections       = var.postgres_max_connections
  iam_instance_profile  = aws_iam_instance_profile.monitoring.name
  common_tags           = local.common_tags

  depends_on = [module.networking, module.keypair]
}

# ===============================
# Databricks Ephemeral SP Secret
# ===============================
# Creates a new OAuth secret for the existing service principal.
# The secret is included in attendee credentials emails for the
# Tableflow → Unity Catalog integration (LAB 3). Destroyed
# automatically when `wsa clean` tears down shared infra.

data "databricks_service_principal" "main" {
  application_id = var.databricks_service_principal_client_id
}

resource "databricks_service_principal_secret" "workshop" {
  service_principal_id = data.databricks_service_principal.main.id
}

# ===============================
# Shared Databricks External Location
# ===============================
# All workshop accounts share one Databricks workspace and S3 bucket.
# Confluent Tableflow writes Delta files to an internal path structure
# (e.g. s3://<bucket>/11111011/...) that can't be predicted at
# provisioning time. A bucket-root external location created here
# (once, before per-account runs) covers all paths — including
# Tableflow data and per-account catalog storage roots.
#
# Per-account Terraform skips external location creation in shared
# mode and relies on this shared location instead.

resource "aws_iam_role" "databricks_storage" {
  name        = "${var.prefix}-dbx-storage-${local.resource_suffix}"
  description = "Shared IAM role for Databricks Unity Catalog S3 access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = "arn:aws:iam::414351767826:root" }
        Condition = {
          StringEquals = { "sts:ExternalId" = var.databricks_account_id }
        }
      },
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = "arn:aws:iam::${module.networking.aws_account_id}:root" }
      }
    ]
  })

  lifecycle {
    ignore_changes = [assume_role_policy]
  }
}

resource "aws_iam_role_policy" "databricks_storage_s3" {
  name = "${var.prefix}-dbx-storage-s3-${local.resource_suffix}"
  role = aws_iam_role.databricks_storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = [module.s3.bucket_arn, "${module.s3.bucket_arn}/*"]
      }
    ]
  })
}

resource "databricks_storage_credential" "shared" {
  provider = databricks.workspace

  name    = "${var.prefix}-storage-credential-${local.resource_suffix}"
  comment = "Shared storage credential for Unity Catalog S3 access"

  aws_iam_role {
    role_arn = aws_iam_role.databricks_storage.arn
  }
}

resource "null_resource" "update_databricks_storage_trust" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      ROLE_NAME="${aws_iam_role.databricks_storage.name}"
      ROLE_ARN="${aws_iam_role.databricks_storage.arn}"
      EXTERNAL_ID="${databricks_storage_credential.shared.aws_iam_role[0].external_id}"
      POLICY='{
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": { "AWS": "arn:aws:iam::414351767826:root" },
            "Condition": { "StringEquals": { "sts:ExternalId": "'"$EXTERNAL_ID"'" } }
          },
          {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": { "AWS": "'"$ROLE_ARN"'" }
          }
        ]
      }'

      echo "Updating shared IAM trust policy (self-assuming with role ARN)..."
      for i in 1 2 3 4 5 6 7 8; do
        if aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "$POLICY" 2>/dev/null; then
          echo "Shared IAM trust policy updated."
          exit 0
        fi
        echo "  IAM propagation pending, retrying in 15s... (attempt $i/8)"
        sleep 15
      done
      echo "ERROR: failed to update trust policy after 8 attempts" >&2
      exit 1
    EOT
  }

  triggers = {
    credential_id = databricks_storage_credential.shared.id
  }

  depends_on = [databricks_storage_credential.shared, aws_iam_role.databricks_storage]
}

resource "time_sleep" "wait_for_databricks_trust" {
  create_duration = "60s"
  depends_on      = [null_resource.update_databricks_storage_trust]
}

resource "databricks_external_location" "shared" {
  provider = databricks.workspace

  name            = "${var.prefix}-external-location-${local.resource_suffix}"
  url             = module.s3.bucket_url
  credential_name = databricks_storage_credential.shared.name
  comment         = "Shared external location for Tableflow and Unity Catalog data"
  force_destroy   = true
  skip_validation = true

  depends_on = [time_sleep.wait_for_databricks_trust]
}

resource "databricks_grants" "shared_external_location" {
  provider = databricks.workspace

  external_location = databricks_external_location.shared.name

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

  depends_on = [databricks_external_location.shared]
}
