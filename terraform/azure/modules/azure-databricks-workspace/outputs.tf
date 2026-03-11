output "workspace_url" {
  description = "URL of the Databricks workspace"
  value       = var.create_workspace ? "https://${azurerm_databricks_workspace.this[0].workspace_url}" : null
}

output "workspace_id" {
  description = "Numeric workspace ID"
  value       = var.create_workspace ? azurerm_databricks_workspace.this[0].workspace_id : null
}

output "workspace_resource_id" {
  description = "Azure resource ID of the workspace"
  value       = var.create_workspace ? azurerm_databricks_workspace.this[0].id : null
}
