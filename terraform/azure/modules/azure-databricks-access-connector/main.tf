# Databricks Access Connector with managed identity for Unity Catalog → ADLS Gen2

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}

resource "azurerm_databricks_access_connector" "this" {
  name                = "${var.prefix}-access-connector-${var.resource_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.region

  identity {
    type = "SystemAssigned"
  }

  tags = var.common_tags
}

resource "azurerm_role_assignment" "blob_data_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "queue_data_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
}

# Wait for Azure AD to propagate the identity and role assignments
resource "time_sleep" "wait_for_propagation" {
  create_duration = "120s"

  triggers = {
    access_connector_id = azurerm_databricks_access_connector.this.id
    blob_role           = azurerm_role_assignment.blob_data_contributor.id
    queue_role          = azurerm_role_assignment.queue_data_contributor.id
  }

  depends_on = [
    azurerm_role_assignment.blob_data_contributor,
    azurerm_role_assignment.queue_data_contributor
  ]
}
