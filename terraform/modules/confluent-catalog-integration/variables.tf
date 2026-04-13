# ===============================
# Confluent Catalog Integration Module Variables
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

variable "kafka_cluster_id" {
  description = "Confluent Kafka cluster ID"
  type        = string
}

variable "databricks_workspace_url" {
  description = "Databricks workspace URL (e.g., https://dbc-xxx.cloud.databricks.com)"
  type        = string
}

variable "databricks_catalog_name" {
  description = "Databricks Unity Catalog name"
  type        = string
}

variable "databricks_sp_client_id" {
  description = "Databricks Service Principal Client ID for Unity Catalog authentication"
  type        = string
}

variable "databricks_sp_client_secret" {
  description = "Databricks Service Principal Client Secret"
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "Confluent API key with Tableflow management permissions"
  type        = string
}

variable "api_secret" {
  description = "Confluent API secret"
  type        = string
  sensitive   = true
}
