output "access_connector_id" {
  description = "Full resource ID of the Databricks Access Connector"
  value       = azurerm_databricks_access_connector.this.id
  depends_on  = [time_sleep.wait_for_propagation]
}

output "principal_id" {
  description = "Principal ID of the Access Connector's system-assigned managed identity"
  value       = azurerm_databricks_access_connector.this.identity[0].principal_id
}
