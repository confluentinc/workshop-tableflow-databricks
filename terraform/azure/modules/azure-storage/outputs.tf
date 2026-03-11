output "storage_account_name" {
  description = "Name of the Azure Storage Account"
  value       = azurerm_storage_account.adls.name
}

output "storage_account_id" {
  description = "Resource ID of the Azure Storage Account"
  value       = azurerm_storage_account.adls.id
}

output "container_name" {
  description = "Name of the ADLS Gen2 container"
  value       = azurerm_storage_container.tableflow.name
}

output "primary_dfs_endpoint" {
  description = "Primary DFS endpoint for ADLS Gen2 operations"
  value       = azurerm_storage_account.adls.primary_dfs_endpoint
}

output "abfss_url" {
  description = "Full abfss:// URL for Databricks access"
  value       = "abfss://${azurerm_storage_container.tableflow.name}@${azurerm_storage_account.adls.name}.dfs.core.windows.net/"
}
