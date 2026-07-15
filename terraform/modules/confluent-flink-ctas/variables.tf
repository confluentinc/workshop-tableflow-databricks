# ===============================
# Confluent Flink Materialized Tables Module Variables
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
  description = "Confluent environment display name (Flink SQL catalog). Required to fully qualify table refs so dotted CDC topic names like riverhotel.cdc.bookings are not parsed as catalog.database.table."
  type        = string
}

variable "kafka_cluster_id" {
  description = "Kafka cluster ID hosting the materialized table backing topics (e.g. lkc-abc123)"
  type        = string
}

variable "kafka_cluster_display_name" {
  description = "Kafka cluster display name (Flink SQL database). Required to fully qualify table refs (same role as sql.current-database on confluent_flink_statement)."
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
# These are the Flink table / Kafka topic names within the catalog.database
# (not fully qualified). The module wraps them as catalog.database.`topic`.

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

variable "enable_reviews_with_sentiment" {
  description = "Whether to create the reviews_with_sentiment materialized table (requires AI_SENTIMENT; AWS-only as of 2026-03-19 — https://docs.confluent.io/cloud/current/release-notes/index.html#march-19-2026)"
  type        = bool
  default     = true
}
