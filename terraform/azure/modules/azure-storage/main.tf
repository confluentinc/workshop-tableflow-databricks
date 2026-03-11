# Azure ADLS Gen2 Storage Account and Container for Tableflow

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}

resource "azurerm_storage_account" "adls" {
  name                     = "${var.storage_account_prefix}${var.resource_suffix}"
  resource_group_name      = var.resource_group_name
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true

  tags = var.common_tags
}

resource "azurerm_storage_container" "tableflow" {
  name                  = "tableflow-databricks"
  storage_account_id    = azurerm_storage_account.adls.id
  container_access_type = "private"
}
