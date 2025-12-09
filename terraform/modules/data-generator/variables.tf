# ===============================
# Data Generator Module Variables
# ===============================

variable "output_path" {
  description = "Path to output connection configuration files"
  type        = string
  default     = "../data/connections"
}

# PostgreSQL Configuration
variable "postgres_hostname" {
  description = "PostgreSQL hostname"
  type        = string
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "postgres_username" {
  description = "PostgreSQL username"
  type        = string
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
}

# Kafka Configuration
variable "kafka_bootstrap_endpoint" {
  description = "Kafka bootstrap endpoint (without protocol)"
  type        = string
}

variable "kafka_api_key" {
  description = "Kafka API key"
  type        = string
}

variable "kafka_api_secret" {
  description = "Kafka API secret"
  type        = string
  sensitive   = true
}

# Schema Registry Configuration
variable "schema_registry_endpoint" {
  description = "Schema Registry REST endpoint"
  type        = string
}

variable "schema_registry_api_key" {
  description = "Schema Registry API key"
  type        = string
}

variable "schema_registry_api_secret" {
  description = "Schema Registry API secret"
  type        = string
  sensitive   = true
}
