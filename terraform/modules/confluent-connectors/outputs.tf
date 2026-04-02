# ===============================
# Confluent Connectors Module Outputs
# ===============================

output "connector_id" {
  description = "PostgreSQL CDC connector ID"
  value       = confluent_connector.postgres_cdc.id
}

output "connector_name" {
  description = "PostgreSQL CDC connector name"
  value       = confluent_connector.postgres_cdc.config_nonsensitive["name"]
}

output "connector_status" {
  description = "PostgreSQL CDC connector status"
  value       = confluent_connector.postgres_cdc.status
}

output "topics" {
  description = "Topics created by the connector"
  value = {
    customer_topic  = "riverhotel.cdc.customer"
    hotel_topic     = "riverhotel.cdc.hotel"
    heartbeat_topic = "__debezium-heartbeat-riverhotel"
  }
}
