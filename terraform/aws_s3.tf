# ===============================
# S3 Bucket for Tableflow and Databricks
# ===============================

resource "aws_s3_bucket" "tableflow_bucket" {
  bucket        = "${local.prefix}-${local.resource_suffix}"
  force_destroy = true
  tags          = local.common_tags
}

# Add S3 lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "tableflow_bucket_lifecycle" {
  bucket = aws_s3_bucket.tableflow_bucket.id

  rule {
    id     = "cleanup-old-data"
    status = "Enabled"

    filter {
      prefix = "" # Empty prefix means apply to all objects
    }

    expiration {
      days = 30
    }
  }
}

# Explicitly configure public access settings to allow bucket policies
resource "aws_s3_bucket_public_access_block" "tableflow_bucket_access" {
  bucket = aws_s3_bucket.tableflow_bucket.id

  # Block public ACLs but allow public policies for Unity Catalog
  block_public_acls       = true
  block_public_policy     = false # Allow public policies
  ignore_public_acls      = true
  restrict_public_buckets = false # Allow public access via bucket policies
}

output "aws_s3" {
  value = {
    name = aws_s3_bucket.tableflow_bucket.bucket
    arn  = aws_s3_bucket.tableflow_bucket.arn
    url  = "s3://${aws_s3_bucket.tableflow_bucket.bucket}/"
  }
}
