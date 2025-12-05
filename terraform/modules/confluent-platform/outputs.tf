# ===============================
# Confluent Platform Module Outputs
# ===============================

output "organization_id" {
  description = "Confluent organization ID"
  value       = data.confluent_organization.current.id
}

output "environment_id" {
  description = "Confluent environment ID"
  value       = confluent_environment.main.id
}

output "environment_name" {
  description = "Confluent environment display name"
  value       = confluent_environment.main.display_name
}

output "kafka_cluster_id" {
  description = "Kafka cluster ID"
  value       = confluent_kafka_cluster.main.id
}

output "kafka_bootstrap_endpoint" {
  description = "Kafka bootstrap endpoint"
  value       = confluent_kafka_cluster.main.bootstrap_endpoint
}

output "kafka_rest_endpoint" {
  description = "Kafka REST endpoint"
  value       = confluent_kafka_cluster.main.rest_endpoint
}

output "schema_registry_id" {
  description = "Schema Registry cluster ID"
  value       = data.confluent_schema_registry_cluster.main.id
}

output "schema_registry_endpoint" {
  description = "Schema Registry REST endpoint"
  value       = data.confluent_schema_registry_cluster.main.rest_endpoint
}

output "service_account_id" {
  description = "Service account ID"
  value       = confluent_service_account.app_manager.id
}

output "service_account_api_version" {
  description = "Service account API version"
  value       = confluent_service_account.app_manager.api_version
}

output "service_account_kind" {
  description = "Service account kind"
  value       = confluent_service_account.app_manager.kind
}

output "kafka_api_key" {
  description = "Kafka API key"
  value       = confluent_api_key.kafka.id
}

output "kafka_api_secret" {
  description = "Kafka API secret"
  value       = confluent_api_key.kafka.secret
  sensitive   = true
}

output "schema_registry_api_key" {
  description = "Schema Registry API key"
  value       = confluent_api_key.schema_registry.id
}

output "schema_registry_api_secret" {
  description = "Schema Registry API secret"
  value       = confluent_api_key.schema_registry.secret
  sensitive   = true
}

output "bootstrap_endpoint_url" {
  description = "Kafka bootstrap endpoint URL (without protocol)"
  value       = split("SASL_SSL://", confluent_kafka_cluster.main.bootstrap_endpoint)[1]
}
