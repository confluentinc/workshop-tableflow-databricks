# ===============================
# AWS IAM Module
# ===============================
# Creates IAM roles and policies for Tableflow and Databricks

locals {
  role_name = "${var.prefix}-unified-role-${var.resource_suffix}"
}

# ===============================
# IAM Role
# ===============================

resource "aws_iam_role" "main" {
  name        = local.role_name
  description = "IAM role for S3 access with trust policies for Confluent Tableflow and Databricks Unity Catalog"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Confluent Provider Integration - AssumeRole
      {
        Effect = "Allow"
        Principal = {
          AWS = var.confluent_iam_role_arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.confluent_external_id
          }
        }
      },
      # Confluent Provider Integration - TagSession
      {
        Effect = "Allow"
        Principal = {
          AWS = var.confluent_iam_role_arn
        }
        Action = "sts:TagSession"
      },
      # Databricks Unity Catalog
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root" # Databricks AWS Account
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      }
    ]
  })

  lifecycle {
    ignore_changes = [assume_role_policy]
  }

  tags = merge(var.common_tags, {
    Name = local.role_name
  })
}

# ===============================
# IAM Role Policy
# ===============================

resource "aws_iam_role_policy" "s3_access" {
  name = "${var.prefix}-s3-access-policy-${var.resource_suffix}"
  role = aws_iam_role.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

# ===============================
# S3 Bucket Policy
# ===============================

resource "aws_s3_bucket_policy" "main" {
  bucket = var.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.main.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

# ===============================
# Note: Trust policy updates with Databricks external ID
# are handled in the root main.tf after the databricks module
# creates the storage credential.
# ===============================
