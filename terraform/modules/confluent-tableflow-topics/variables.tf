# ===============================
# Confluent Tableflow Topics Module Variables
# ===============================

variable "environment_id" {
  description = "Confluent environment ID"
  type        = string
}

variable "kafka_cluster_id" {
  description = "Confluent Kafka cluster ID"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for Tableflow storage (BYOB)"
  type        = string
}

variable "provider_integration_id" {
  description = "Confluent Tableflow provider integration ID"
  type        = string
}

variable "clickstream_topic" {
  description = "Clickstream topic name"
  type        = string
  default     = "clickstream"
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
