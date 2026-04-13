# ===============================
# Confluent Flink CTAS Module Variables
# ===============================

variable "organization_id" {
  description = "Confluent organization ID"
  type        = string
}

variable "environment_id" {
  description = "Confluent environment ID"
  type        = string
}

variable "environment_name" {
  description = "Confluent environment display name (Flink SQL catalog)"
  type        = string
}

variable "kafka_cluster_display_name" {
  description = "Kafka cluster display name (Flink SQL database)"
  type        = string
}

variable "compute_pool_id" {
  description = "Flink compute pool ID"
  type        = string
}

variable "service_account_id" {
  description = "Service account ID for Flink statement principal"
  type        = string
}

variable "flink_api_key" {
  description = "Flink API key"
  type        = string
}

variable "flink_api_secret" {
  description = "Flink API secret"
  type        = string
  sensitive   = true
}

variable "flink_rest_endpoint" {
  description = "Flink REST endpoint URL for the region"
  type        = string
}

# ===============================
# Topic Names
# ===============================
# Self-service mode uses plain names; WSA/instructor-led uses CDC prefix.

variable "bookings_topic" {
  description = "Flink table name for bookings data"
  type        = string
  default     = "bookings"
}

variable "reviews_topic" {
  description = "Flink table name for reviews data"
  type        = string
  default     = "reviews"
}

variable "customer_topic" {
  description = "Flink table name for customer data"
  type        = string
  default     = "riverhotel.cdc.customer"
}

variable "hotel_topic" {
  description = "Flink table name for hotel data"
  type        = string
  default     = "riverhotel.cdc.hotel"
}
