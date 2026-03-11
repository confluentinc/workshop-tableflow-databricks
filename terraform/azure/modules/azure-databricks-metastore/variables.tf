variable "workspace_id" {
  description = "Databricks workspace ID (numeric)"
  type        = string
}

variable "existing_metastore_id" {
  description = "Existing metastore ID (if provided, metastore creation is skipped)"
  type        = string
  default     = null
}

variable "storage_account_name" {
  description = "Azure Storage Account name"
  type        = string
}

variable "container_name" {
  description = "ADLS Gen2 container name"
  type        = string
}

variable "access_connector_id" {
  description = "Azure Databricks Access Connector resource ID"
  type        = string
}

variable "region" {
  description = "Azure region"
  type        = string
}

variable "resource_suffix" {
  description = "Unique suffix for resource names"
  type        = string
}

variable "skip_metastore_assignment" {
  description = "Skip metastore assignment (true for shared accounts without admin)"
  type        = bool
  default     = false
}

variable "create_sql_warehouse" {
  description = "Whether to create a SQL warehouse"
  type        = bool
  default     = true
}
