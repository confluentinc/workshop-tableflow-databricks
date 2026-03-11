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

variable "cloud_provider" {
  description = "Cloud provider (aws or azure)"
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "azure"], var.cloud_provider)
    error_message = "Must be one of: aws, azure."
  }
}

# AWS-specific
variable "customer_iam_role_arn" {
  description = "Customer IAM role ARN for S3 access (required for AWS)"
  type        = string
  default     = null
}

# Azure-specific
variable "azure_tenant_id" {
  description = "Azure Tenant ID (required for Azure)"
  type        = string
  default     = null
}
