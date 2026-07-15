variable "confluent_cloud_email" {
  description = "Your Confluent Cloud account email — used for EnvironmentAdmin RBAC and AWS resource tagging"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.confluent_cloud_email))
    error_message = "Must be a valid email address (e.g., user@example.com)."
  }
}

variable "prefix" {
  description = "Call sign to use in prefix for resource names, it could be your initials or your first name"
  type        = string
  default     = "neo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,10}$", var.prefix))
    error_message = "Call sign must be 2-11 lowercase alphanumeric characters, starting with a letter (e.g., 'neo', 'jsmith')."
  }
}

variable "project_name" {
  description = "Name of this project to use in prefix for resource names"
  type        = string
  default     = "tf-db"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod", "test", "workshop"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test, workshop."
  }
}

variable "cloud_region" {
  description = "AWS Cloud Region"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.cloud_region))
    error_message = "Must be a valid AWS region (e.g., us-east-1, us-west-2, eu-west-1)."
  }
}

# ---------------------
# Confluent Cloud variables
# ---------------------

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.confluent_cloud_api_key) > 0
    error_message = "Confluent Cloud API Key is required. Create one at https://confluent.cloud/settings/api-keys"
  }
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.confluent_cloud_api_secret) > 0
    error_message = "Confluent Cloud API Secret is required. Create one at https://confluent.cloud/settings/api-keys"
  }
}

variable "cc_environment_id" {
  description = "Pre-created Confluent Cloud environment ID (skip creation when set)"
  type        = string
  default     = ""
}

# ---------------------
# PostgreSQL DB variables
# ---------------------

variable "postgres_instance_type" {
  description = "PostgreSQL DB instance type"
  type        = string
  default     = "m7i-flex.large"
}

variable "postgres_db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "workshop"
}

variable "postgres_db_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "postgres"
}

variable "postgres_db_password" {
  description = "PostgreSQL admin password"
  type        = string
  default     = "Welcome1"
  sensitive   = true
}

variable "postgres_db_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432

  validation {
    condition     = var.postgres_db_port > 0 && var.postgres_db_port < 65536
    error_message = "PostgreSQL port must be between 1 and 65535."
  }
}

variable "postgres_debezium_username" {
  description = "PostgreSQL Debezium CDC user"
  type        = string
  default     = "debezium"
}

variable "postgres_debezium_password" {
  description = "PostgreSQL Debezium user password"
  type        = string
  default     = "password"
  sensitive   = true
}

# ---------------------
# Databricks variables
# ---------------------

variable "databricks_host" {
  description = "The Databricks workspace URL (e.g., https://your-workspace.cloud.databricks.com)"
  type        = string

  validation {
    condition     = can(regex("^https://[a-zA-Z0-9-]+\\.cloud\\.databricks\\.com/?$", var.databricks_host))
    error_message = "Must be a valid Databricks workspace URL (e.g., https://dbc-12345678-abcd.cloud.databricks.com)."
  }
}

variable "databricks_account_id" {
  description = "Databricks account ID (optional, only needed for account-level resources)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "databricks_user_email" {
  description = "Databricks user email to grant permissions to external location"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.databricks_user_email))
    error_message = "Must be a valid email address (e.g., user@example.com)."
  }
}

variable "databricks_service_principal_client_id" {
  description = "Databricks Service Principal Client ID (Application ID) for Tableflow integration"
  type        = string
  sensitive   = false

  validation {
    condition     = length(var.databricks_service_principal_client_id) > 0
    error_message = "Databricks Service Principal Client ID is required. See LAB1.md for setup instructions."
  }
}

variable "databricks_service_principal_client_secret" {
  description = "Databricks Service Principal Client Secret (OAuth Secret) for Tableflow integration"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.databricks_service_principal_client_secret) > 0
    error_message = "Databricks Service Principal Client Secret is required. See LAB1.md for setup instructions."
  }
}

variable "databricks_sql_warehouse_name" {
  description = "Name of the Databricks SQL warehouse to look up (must already exist in the workspace)"
  type        = string
  default     = "Serverless Starter Warehouse"
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access PostgreSQL and SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "table_include_list" {
  description = "Comma-separated PostgreSQL tables for CDC"
  type        = string
  default     = "cdc.customer,cdc.hotel"
}

# ---------------------
# WSA integration variables (defaults preserve backward compatibility for self-service)
# ---------------------

variable "account_email" {
  description = "WSA: per-account email (overrides var.confluent_cloud_email when set)"
  type        = string
  default     = ""
}

variable "account_number" {
  description = "WSA: account number for this run"
  type        = number
  default     = 0
}

variable "cc_environment_name" {
  description = "WSA: pre-created Confluent Cloud environment name"
  type        = string
  default     = ""
}

variable "dbx_workspace_url" {
  description = "WSA: Databricks workspace URL for CSV output"
  type        = string
  default     = ""
}

variable "dbx_schema_name" {
  description = "WSA: Databricks schema name (per-user isolation)"
  type        = string
  default     = ""
}

variable "dbx_catalog_name" {
  description = "WSA: Databricks catalog name (per-user isolation)"
  type        = string
  default     = ""
}

variable "databricks_sso_email" {
  description = "WSA: Azure AD UPN for the participant (e.g., wp2@tenant.onmicrosoft.com). When set, catalog and storage credential grants are added for this identity in addition to databricks_user_email."
  type        = string
  default     = ""
}

variable "aws_account_tag" {
  description = "WSA: tag value for per-account resource identification"
  type        = string
  default     = ""
}

# ---------------------
# Shared infrastructure variables (set by wsa when using terraform/aws-shared/)
# ---------------------

variable "shared_vpc_id" {
  description = "WSA: shared VPC ID (skips networking module when set)"
  type        = string
  default     = ""
}

variable "shared_subnet_id" {
  description = "WSA: shared subnet ID (skips networking module when set)"
  type        = string
  default     = ""
}

variable "shared_s3_bucket_name" {
  description = "WSA: shared S3 bucket name (skips S3 module when set)"
  type        = string
  default     = ""
}

variable "shared_s3_bucket_arn" {
  description = "WSA: shared S3 bucket ARN (skips S3 module when set)"
  type        = string
  default     = ""
}

variable "shared_s3_bucket_url" {
  description = "WSA: shared S3 bucket URL (skips S3 module when set)"
  type        = string
  default     = ""
}

variable "shared_key_name" {
  description = "WSA: shared SSH key name (skips keypair module when set)"
  type        = string
  default     = ""
}

variable "shared_postgres_hostname" {
  description = "WSA: shared PostgreSQL hostname (skips postgres module when set)"
  type        = string
  default     = ""
}

variable "shared_postgres_public_ip" {
  description = "WSA: shared PostgreSQL public IP (skips postgres module when set)"
  type        = string
  default     = ""
}

variable "shared_postgres_db_password" {
  description = "WSA: shared PostgreSQL admin password (from shared infra output)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "shared_postgres_debezium_password" {
  description = "WSA: shared PostgreSQL debezium password (from shared infra output)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "shared_dbx_sp_client_id" {
  description = "WSA: Databricks SP client ID from shared infra (for credentials email)"
  type        = string
  default     = ""
}

variable "shared_dbx_sp_client_secret" {
  description = "WSA: Ephemeral Databricks SP secret from shared infra (for credentials email)"
  type        = string
  sensitive   = true
  default     = ""
}
