# ===============================
# Shared Infrastructure Outputs
# ===============================
# These values are passed to per-account Terraform (terraform/azure/)
# via `wsa build` as TF_VAR_shared_* variables.

# --- Resource Group ---

output "resource_group_name" {
  description = "Shared resource group name"
  value       = azurerm_resource_group.shared.name
}

output "resource_group_id" {
  description = "Shared resource group ID"
  value       = azurerm_resource_group.shared.id
}

# --- Networking ---

output "vnet_id" {
  description = "Shared VNet ID"
  value       = azurerm_virtual_network.shared.id
}

output "vnet_name" {
  description = "Shared VNet name"
  value       = azurerm_virtual_network.shared.name
}

output "subnet_id" {
  description = "Shared subnet ID"
  value       = azurerm_subnet.shared.id
}

# --- Storage ---

output "storage_account_name" {
  description = "Shared storage account name"
  value       = azurerm_storage_account.shared.name
}

output "storage_account_id" {
  description = "Shared storage account ID"
  value       = azurerm_storage_account.shared.id
}

output "storage_container_name" {
  description = "Shared ADLS Gen2 container name"
  value       = azurerm_storage_container.shared.name
}

output "storage_account_primary_dfs_endpoint" {
  description = "ADLS Gen2 DFS endpoint (abfss:// URL base)"
  value       = azurerm_storage_account.shared.primary_dfs_endpoint
}

# --- SSH ---

output "private_key_path" {
  description = "Path to the shared SSH private key"
  value       = local_file.ssh_private_key.filename
}

# --- PostgreSQL ---

output "postgres_public_ip" {
  description = "Shared PostgreSQL VM public IP"
  value       = azurerm_public_ip.postgres.ip_address
}

output "postgres_vm_id" {
  description = "Shared PostgreSQL VM resource ID"
  value       = azurerm_linux_virtual_machine.postgres.id
}

# --- PostgreSQL Credentials ---

output "postgres_db_password" {
  description = "PostgreSQL admin password (generated or explicit)"
  value       = local.effective_postgres_db_password
  sensitive   = true
}

output "postgres_debezium_password" {
  description = "PostgreSQL Debezium CDC user password (generated or explicit)"
  value       = local.effective_postgres_debezium_password
  sensitive   = true
}

# --- Databricks SP (pass-through for credentials email) ---

output "dbx_sp_client_id" {
  description = "Databricks service principal Application (Client) ID"
  value       = var.databricks_service_principal_client_id
}

output "dbx_sp_client_secret" {
  description = "Databricks service principal OAuth secret"
  value       = var.databricks_service_principal_client_secret
  sensitive   = true
}

# --- Databricks Shared External Location ---

output "dbx_storage_credential_name" {
  description = "Shared Databricks storage credential name"
  value       = databricks_storage_credential.shared.name
}

output "dbx_external_location_name" {
  description = "Shared Databricks external location name"
  value       = databricks_external_location.shared.name
}

output "dbx_access_connector_id" {
  description = "Shared Databricks Access Connector resource ID"
  value       = azurerm_databricks_access_connector.shared.id
}

# --- Monitoring ---

output "dashboard_url" {
  description = "Azure Portal dashboard URL"
  value       = "https://portal.azure.com/#@/dashboard/arm${azurerm_portal_dashboard.shared_infra.id}"
}

# --- Summary ---

output "shared_infra_summary" {
  description = "Summary of shared infrastructure for wsa build"
  value = {
    resource_group         = azurerm_resource_group.shared.name
    location               = azurerm_resource_group.shared.location
    vnet_id                = azurerm_virtual_network.shared.id
    subnet_id              = azurerm_subnet.shared.id
    storage_account        = azurerm_storage_account.shared.name
    postgres_public_ip     = azurerm_public_ip.postgres.ip_address
    dbx_external_location  = databricks_external_location.shared.name
    dbx_storage_credential = databricks_storage_credential.shared.name
    ssh_command            = "ssh -i ${local_file.ssh_private_key.filename} ${var.vm_admin_username}@${azurerm_public_ip.postgres.ip_address}"
  }
}
