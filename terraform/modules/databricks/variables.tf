# ===============================
# Databricks Module Variables
# ===============================

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "resource_suffix" {
  description = "Unique suffix for resource names"
  type        = string
}

variable "iam_role_arn" {
  description = "AWS IAM role ARN for storage credential"
  type        = string
}

variable "s3_bucket_url" {
  description = "S3 bucket URL (e.g., s3://bucket-name/)"
  type        = string
}

variable "user_email" {
  description = "Databricks user email for granting permissions"
  type        = string
}

variable "service_principal_client_id" {
  description = "Databricks service principal client ID"
  type        = string
}

variable "kafka_cluster_id" {
  description = "Kafka cluster ID (used for expected schema name)"
  type        = string
}
