# ===============================
# Confluent Flink Materialized Tables Module Outputs
# ===============================

output "denormalized_hotel_bookings_table_name" {
  description = "Display name of the denormalized_hotel_bookings materialized table"
  value       = confluent_flink_materialized_table.denormalized_hotel_bookings.display_name
}

output "reviews_with_sentiment_table_name" {
  description = "Display name of the reviews_with_sentiment materialized table (null when disabled)"
  value       = var.enable_reviews_with_sentiment ? confluent_flink_materialized_table.reviews_with_sentiment[0].display_name : null
}
