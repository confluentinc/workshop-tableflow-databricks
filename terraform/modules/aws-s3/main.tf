# ===============================
# AWS S3 Bucket Module
# ===============================
# Creates S3 bucket for Tableflow and Databricks integration

resource "aws_s3_bucket" "main" {
  bucket        = "${var.prefix}-${var.resource_suffix}"
  force_destroy = true

  tags = var.common_tags
}

# ===============================
# Lifecycle Configuration
# ===============================

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "cleanup-old-data"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.expiration_days
    }
  }
}

# ===============================
# Public Access Block
# ===============================

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = false # Allow bucket policies for Unity Catalog
  ignore_public_acls      = true
  restrict_public_buckets = false # Allow access via bucket policies
}
