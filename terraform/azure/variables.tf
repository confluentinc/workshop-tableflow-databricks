# ===============================
# General Variables
# ===============================

variable "email" {
  description = "Your email to tag all resources"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.email))
    error_message = "Must be a valid email address (e.g., user@example.com)."
  }
}

variable "prefix" {
  description = "Call sign to use in prefix for resource names (e.g., your initials or a nickname)"
  type        = string
  default     = "neo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,10}$", var.prefix))
    error_message = "Must be 2-11 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "project_name" {
  description = "Name of this project to use in prefix for resource names"
  type        = string
  default     = "tf-db"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod", "test", "workshop"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test, workshop."
  }
}

variable "cloud_region" {
  description = "Azure region (e.g., eastus2, westus2)"
  type        = string
  default     = "eastus2"
}

# ===============================
# Azure Variables
# ===============================

variable "azure_subscription_id" {
  description = "Azure Subscription ID (falls back to ARM_SUBSCRIPTION_ID env var when null)"
  type        = string
  default     = null
}

variable "azure_tenant_id" {
  description = "Azure AD Tenant ID (falls back to ARM_TENANT_ID env var when null)"
  type        = string
  default     = null
}

variable "azure_resource_group_name" {
  description = "Name for the Azure resource group"
  type        = string
  default     = "tableflow-workshop-rg"
}

variable "azure_storage_account_prefix" {
  description = "Prefix for the Azure Storage Account name (3-10 lowercase alphanumeric)"
  type        = string
  default     = "cflttflow"

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.azure_storage_account_prefix))
    error_message = "Storage account prefix must be 3-10 lowercase alphanumeric characters."
  }
}

# ===============================
# Confluent Cloud Variables
# ===============================

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key (Cloud Resource Management scope)"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret"
  type        = string
  sensitive   = true
}

# ===============================
# PostgreSQL Variables
# ===============================

variable "postgres_db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "workshop"
}

variable "postgres_db_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "pgadmin"

  validation {
    condition     = !contains(["postgres", "admin", "administrator", "root", "azure_superuser", "azure_pg_admin"], var.postgres_db_username)
    error_message = "Username cannot be a reserved PostgreSQL or Azure name."
  }
}

variable "postgres_db_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
  default     = "W0rksh0p!2025"
}

variable "postgres_db_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "postgres_debezium_username" {
  description = "Debezium CDC replication username"
  type        = string
  default     = "debezium"
}

variable "postgres_debezium_password" {
  description = "Debezium CDC replication password"
  type        = string
  sensitive   = true
  default     = "D3bezium!2025"
}

variable "postgres_sku_name" {
  description = "PostgreSQL Flexible Server SKU (e.g., B_Standard_B1ms for burstable)"
  type        = string
  default     = "B_Standard_B2s"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage size in MB"
  type        = number
  default     = 32768
}

variable "create_postgres_cdc_connector" {
  description = "Whether to auto-create the PostgreSQL CDC connector"
  type        = bool
  default     = true
}

# ===============================
# Databricks Variables
# ===============================

variable "databricks_host" {
  description = "Databricks workspace URL (e.g., https://adb-1234567890.12.azuredatabricks.net). Leave blank to auto-provision."
  type        = string
  default     = ""
}

variable "databricks_account_id" {
  description = "Databricks account ID"
  type        = string
  default     = ""
}

variable "databricks_user_email" {
  description = "Databricks user email for granting permissions"
  type        = string
}

variable "databricks_service_principal_client_id" {
  description = "Databricks Service Principal Application (Client) ID"
  type        = string
}

variable "databricks_service_principal_client_secret" {
  description = "Databricks Service Principal OAuth Secret"
  type        = string
  sensitive   = true
}

# ---------------------
# WSA integration variables (defaults preserve backward compatibility for self-service)
# ---------------------

variable "account_email" {
  description = "WSA: per-account email (overrides var.email when set)"
  type        = string
  default     = ""
}

variable "account_number" {
  description = "WSA: account number for this run"
  type        = number
  default     = 0
}

variable "cc_environment_id" {
  description = "WSA: pre-created Confluent Cloud environment ID (skip creation when set)"
  type        = string
  default     = ""
}

variable "cc_environment_name" {
  description = "WSA: pre-created Confluent Cloud environment name"
  type        = string
  default     = ""
}

variable "databricks_sso_email" {
  description = "WSA: Azure AD UPN for the participant (e.g., wp2@tenant.onmicrosoft.com). When set, catalog and storage credential grants are added for this identity in addition to databricks_user_email."
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

# ---------------------
# WSA shared infrastructure variables (skip per-account resources when set)
# ---------------------

variable "shared_resource_group_name" {
  description = "WSA: shared resource group name (skips RG creation when set)"
  type        = string
  default     = ""
}

variable "shared_resource_group_id" {
  description = "WSA: shared resource group ID (for RBAC scoping in shared mode)"
  type        = string
  default     = ""
}

variable "shared_vnet_id" {
  description = "WSA: shared VNet ID"
  type        = string
  default     = ""
}

variable "shared_subnet_id" {
  description = "WSA: shared subnet ID"
  type        = string
  default     = ""
}

variable "shared_storage_account_name" {
  description = "WSA: shared storage account name (skips storage module when set)"
  type        = string
  default     = ""
}

variable "shared_storage_account_id" {
  description = "WSA: shared storage account ID"
  type        = string
  default     = ""
}

variable "shared_storage_container_name" {
  description = "WSA: shared storage container name"
  type        = string
  default     = ""
}

variable "shared_storage_dfs_endpoint" {
  description = "WSA: shared ADLS Gen2 DFS endpoint"
  type        = string
  default     = ""
}

variable "shared_postgres_public_ip" {
  description = "WSA: shared PostgreSQL VM public IP (skips postgres module when set)"
  type        = string
  default     = ""
}

variable "cluster_type" {
  description = "Confluent Cloud cluster type (enterprise when self-service, standard when shared)"
  type        = string
  default     = "enterprise"
}

variable "table_include_list" {
  description = "CDC connector table include list (all 5 CDC tables when shared, 2 when self-service)"
  type        = string
  default     = "cdc.customer,cdc.hotel"
}

variable "shared_dbx_sp_client_id" {
  description = "WSA: Databricks SP client ID from shared infra (for credentials email)"
  type        = string
  default     = ""
}

variable "shared_dbx_sp_client_secret" {
  description = "WSA: Databricks SP secret from shared infra (for credentials email)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "shared_dbx_access_connector_id" {
  description = "WSA: shared Databricks Access Connector resource ID (skips per-account connector when set)"
  type        = string
  default     = ""
}
