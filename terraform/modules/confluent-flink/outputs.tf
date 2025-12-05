# ===============================
# Confluent Flink Module Outputs
# ===============================

output "compute_pool_id" {
  description = "Flink compute pool ID"
  value       = confluent_flink_compute_pool.main.id
}

output "compute_pool_name" {
  description = "Flink compute pool display name"
  value       = confluent_flink_compute_pool.main.display_name
}

output "flink_api_key" {
  description = "Flink API key"
  value       = confluent_api_key.flink.id
}

output "flink_api_secret" {
  description = "Flink API secret"
  value       = confluent_api_key.flink.secret
  sensitive   = true
}

output "flink_region_id" {
  description = "Flink region ID"
  value       = data.confluent_flink_region.main.id
}
