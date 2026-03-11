# ===============================
# Confluent Platform Module Variables
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
  description = "Cloud provider for the Kafka cluster (AWS, AZURE, GCP)"
  type        = string
  default     = "AWS"

  validation {
    condition     = contains(["AWS", "AZURE", "GCP"], upper(var.cloud))
    error_message = "Must be one of: AWS, AZURE, GCP."
  }
}

variable "cloud_region" {
  description = "Cloud region for the Kafka cluster (e.g., us-east-2, eastus2)"
  type        = string
}

variable "cluster_type" {
  description = "Kafka cluster type (standard or enterprise)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "enterprise"], var.cluster_type)
    error_message = "Must be one of: standard, enterprise."
  }
}

variable "environment_id" {
  description = "WSA: pre-created Confluent Cloud environment ID (skip creation when set)"
  type        = string
  default     = ""
}

variable "user_email" {
  description = "Workshop attendee email — when set, grants EnvironmentAdmin RBAC on the environment"
  type        = string
  default     = ""
}
