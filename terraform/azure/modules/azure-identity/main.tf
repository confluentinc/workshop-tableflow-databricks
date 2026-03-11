# Azure Identity Module
# Creates service principals and RBAC role assignments for Confluent Tableflow → ADLS Gen2 access

terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}

# Service principal for Confluent's multi-tenant application (Tableflow → ADLS Gen2)
resource "azuread_service_principal" "confluent" {
  client_id = var.confluent_multi_tenant_app_id
}

# Storage Blob Data Contributor — allows Tableflow to write Iceberg/Delta data
resource "azurerm_role_assignment" "confluent_storage_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.confluent.object_id

  skip_service_principal_aad_check = true

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# Reader on resource group — allows Tableflow to verify storage account exists
resource "azurerm_role_assignment" "confluent_rg_reader" {
  scope                = var.resource_group_id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.confluent.object_id

  skip_service_principal_aad_check = true

  timeouts {
    create = "5m"
    delete = "5m"
  }
}
