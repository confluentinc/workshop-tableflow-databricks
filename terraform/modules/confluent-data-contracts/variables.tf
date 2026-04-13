# ===============================
# Data Contracts Module Variables
# ===============================

variable "environment_id" {
  description = "Confluent environment ID"
  type        = string
}

variable "kafka_cluster_id" {
  description = "Kafka cluster ID"
  type        = string
}

variable "kafka_rest_endpoint" {
  description = "Kafka REST endpoint"
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

variable "schema_registry_id" {
  description = "Schema Registry cluster ID"
  type        = string
}

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

variable "topic_prefix" {
  description = "Prefix for topic and subject names. Empty for self-service (direct Kafka), 'riverhotel.cdc.' for instructor-led/demo (CDC)."
  type        = string
  default     = ""
}

variable "schemas_dir" {
  description = "Path to the directory containing Avro schema files"
  type        = string
}

variable "register_all_schemas" {
  description = "Whether to pre-register all schemas (booking, review) in addition to clickstream. Required for self-service where auto.register.schemas=false."
  type        = bool
  default     = false
}
