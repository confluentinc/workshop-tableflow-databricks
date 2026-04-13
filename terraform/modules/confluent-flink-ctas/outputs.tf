# ===============================
# Confluent Flink CTAS Module Outputs
# ===============================

output "denormalized_hotel_bookings_statement_name" {
  description = "Statement name for denormalized_hotel_bookings CTAS"
  value       = "denormalized-hotel-bookings"
}

output "reviews_with_sentiment_statement_name" {
  description = "Statement name for reviews_with_sentiment CTAS"
  value       = "hotel-reviews-with-sentiment"
}
