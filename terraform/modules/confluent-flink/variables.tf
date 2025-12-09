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

variable "cloud_region" {
  description = "AWS region for the Flink compute pool"
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
