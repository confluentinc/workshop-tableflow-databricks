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

variable "cloud_provider" {
  description = "Cloud provider for Tableflow BYOB storage (aws or azure)"
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "azure"], var.cloud_provider)
    error_message = "Must be one of: aws, azure."
  }
}

variable "s3_bucket_name" {
  description = "S3 bucket name for Tableflow storage (BYOB). Required when cloud_provider is aws."
  type        = string
  default     = ""
}

variable "storage_account_name" {
  description = "Azure storage account name for Tableflow ADLS Gen2 storage. Required when cloud_provider is azure."
  type        = string
  default     = ""
}

variable "container_name" {
  description = "Azure container name for Tableflow ADLS Gen2 storage. Required when cloud_provider is azure."
  type        = string
  default     = ""
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

variable "enable_reviews_with_sentiment" {
  description = "Whether to enable Tableflow on reviews_with_sentiment (requires AI_SENTIMENT; AWS-only as of 2026-03-19 — https://docs.confluent.io/cloud/current/release-notes/index.html#march-19-2026)"
  type        = bool
  default     = true
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
