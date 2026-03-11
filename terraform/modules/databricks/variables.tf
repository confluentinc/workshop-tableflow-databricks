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
variable "iam_role_arn" {
  description = "AWS IAM role ARN for storage credential (required for AWS)"
  type        = string
  default     = null
}

variable "s3_bucket_url" {
  description = "S3 bucket URL (e.g., s3://bucket-name/) (used for AWS)"
  type        = string
  default     = null
}

# Azure-specific
variable "azure_access_connector_id" {
  description = "Azure Databricks Access Connector resource ID (required for Azure)"
  type        = string
  default     = null
}

# Shared
variable "user_email" {
  description = "Databricks user email for granting permissions"
  type        = string
}

variable "sso_email" {
  description = "Azure AD UPN for SSO login (e.g., wp2@tenant.onmicrosoft.com). When set, grants are added for this identity."
  type        = string
  default     = ""
}

variable "service_principal_client_id" {
  description = "Databricks service principal client ID"
  type        = string
}

variable "kafka_cluster_id" {
  description = "Kafka cluster ID (used for expected schema name)"
  type        = string
}
