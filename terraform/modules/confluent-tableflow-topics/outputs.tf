# ===============================
# Confluent Tableflow Topics Module Outputs
# ===============================

output "clickstream_tableflow_id" {
  description = "Tableflow topic ID for clickstream"
  value       = confluent_tableflow_topic.clickstream.id
}

output "denormalized_hotel_bookings_tableflow_id" {
  description = "Tableflow topic ID for denormalized_hotel_bookings"
  value       = confluent_tableflow_topic.denormalized_hotel_bookings.id
}

output "reviews_with_sentiment_tableflow_id" {
  description = "Tableflow topic ID for reviews_with_sentiment"
  value       = confluent_tableflow_topic.reviews_with_sentiment.id
}
