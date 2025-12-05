# ===============================
# Data Generator Module Outputs
# ===============================

output "postgres_config_path" {
  description = "Path to PostgreSQL connection config"
  value       = local_file.postgres_connection.filename
}

output "kafka_config_path" {
  description = "Path to Kafka connection config"
  value       = local_file.kafka_connection.filename
}

output "license_path" {
  description = "Path to ShadowTraffic license file"
  value       = local_file.shadow_traffic_license.filename
}
