# ===============================
# Confluent Flink Module Variables
# ===============================

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "resource_suffix" {
  description = "Unique suffix for resource names"
  type        = string
}

variable "cloud" {
  description = "Cloud provider for the Flink compute pool (AWS, AZURE, GCP)"
  type        = string
  default     = "AWS"

  validation {
    condition     = contains(["AWS", "AZURE", "GCP"], upper(var.cloud))
    error_message = "Must be one of: AWS, AZURE, GCP."
  }
}

variable "cloud_region" {
  description = "Cloud region for the Flink compute pool (e.g., us-east-2, eastus2)"
  type        = string
}

variable "environment_id" {
  description = "Confluent environment ID"
  type        = string
}

variable "max_cfu" {
  description = "Maximum CFUs for Flink compute pool"
  type        = number
  default     = 20
}

variable "service_account_id" {
  description = "Service account ID for Flink API key"
  type        = string
}

variable "service_account_api_version" {
  description = "Service account API version"
  type        = string
}

variable "service_account_kind" {
  description = "Service account kind"
  type        = string
}
