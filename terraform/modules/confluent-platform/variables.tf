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

variable "cloud_region" {
  description = "AWS region for the Kafka cluster"
  type        = string
}
