# ===============================
# Confluent Flink Statements Module Outputs
# ===============================

output "clickstream_statement_name" {
  description = "Clickstream ALTER TABLE statement name"
  value       = confluent_flink_statement.clickstream_set_append.statement_name
}

output "bookings_watermark_statement_name" {
  description = "Bookings watermark ALTER TABLE statement name"
  value       = confluent_flink_statement.bookings_add_watermark.statement_name
}
