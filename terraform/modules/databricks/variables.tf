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

variable "lookup_sql_warehouse" {
  description = "Whether to look up a SQL warehouse by name"
  type        = bool
  default     = true
}

variable "sql_warehouse_name" {
  description = "Name of the SQL warehouse to look up (both AWS and Azure auto-provision one)"
  type        = string
  default     = "Serverless Starter Warehouse"
}

variable "add_user_to_admins" {
  description = "Add the workshop user to the workspace admins group (true for self-service, false for WSA)"
  type        = bool
  default     = true
}

variable "lookup_existing_users" {
  description = "If true, look up existing workspace users via data source instead of managing them as resources. Use true for self-service (user already owns workspace), false for WSA (users may not exist yet)."
  type        = bool
  default     = true
}
