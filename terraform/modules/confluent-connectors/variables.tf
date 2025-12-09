# ===============================
# Confluent Connectors Module Variables
# ===============================

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "create_connector" {
  description = "Whether to create the PostgreSQL CDC connector"
  type        = bool
  default     = true
}

variable "environment_id" {
  description = "Confluent environment ID"
  type        = string
}

variable "kafka_cluster_id" {
  description = "Kafka cluster ID"
  type        = string
}

variable "service_account_id" {
  description = "Service account ID for connector"
  type        = string
}

variable "postgres_hostname" {
  description = "PostgreSQL hostname"
  type        = string
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "workshop"
}

variable "debezium_username" {
  description = "Debezium CDC username"
  type        = string
  default     = "debezium"
}

variable "debezium_password" {
  description = "Debezium CDC password"
  type        = string
  sensitive   = true
}

variable "ssh_key_path" {
  description = "Path to SSH private key for PostgreSQL health check"
  type        = string
}
