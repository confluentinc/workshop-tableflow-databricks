# ===============================
# Confluent Connectors Module Outputs
# ===============================

output "connector_id" {
  description = "PostgreSQL CDC connector ID"
  value       = var.create_connector ? confluent_connector.postgres_cdc[0].id : null
}

output "connector_name" {
  description = "PostgreSQL CDC connector name"
  value       = var.create_connector ? confluent_connector.postgres_cdc[0].config_nonsensitive["name"] : null
}

output "connector_status" {
  description = "PostgreSQL CDC connector status"
  value       = var.create_connector ? confluent_connector.postgres_cdc[0].status : null
}

output "topics" {
  description = "Topics created by the connector"
  value = {
    customer_topic  = "riverhotel.cdc.customer"
    hotel_topic     = "riverhotel.cdc.hotel"
    heartbeat_topic = "__debezium-heartbeat-riverhotel"
  }
}

output "enabled" {
  description = "Whether the connector was created"
  value       = var.create_connector
}
