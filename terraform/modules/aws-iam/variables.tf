# ===============================
# AWS IAM Module Variables
# ===============================

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "resource_suffix" {
  description = "Unique suffix for resource names"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}

variable "s3_bucket_id" {
  description = "ID of the S3 bucket"
  type        = string
}

variable "confluent_iam_role_arn" {
  description = "Confluent Provider Integration IAM role ARN"
  type        = string
}

variable "confluent_external_id" {
  description = "Confluent Provider Integration external ID"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID for external ID"
  type        = string
}

variable "databricks_storage_credential_external_id" {
  description = "External ID from Databricks storage credential"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
