# ===============================
# Confluent Tableflow Module Variables
# ===============================

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "resource_suffix" {
  description = "Unique suffix for resource names"
  type        = string
}

variable "environment_id" {
  description = "Confluent environment ID"
  type        = string
}

variable "customer_iam_role_arn" {
  description = "Customer IAM role ARN for S3 access"
  type        = string
}
