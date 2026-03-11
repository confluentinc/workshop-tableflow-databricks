# ===============================
# AWS S3 Module Outputs
# ===============================

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_url" {
  description = "S3 URL of the bucket"
  value       = "s3://${aws_s3_bucket.main.bucket}/"
}
