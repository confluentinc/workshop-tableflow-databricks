# ===============================
# Data Contracts Module Outputs
# ===============================

output "dlq_topic_name" {
  description = "DLQ topic name for invalid clickstream events"
  value       = confluent_kafka_topic.invalid_clickstream_events.topic_name
}

output "clickstream_schema_id" {
  description = "Schema ID for the registered clickstream schema with DQR rules"
  value       = confluent_schema.clickstream_value.schema_identifier
}
