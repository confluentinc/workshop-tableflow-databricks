# Azure Databricks Workspace (auto-provisioned when no existing workspace is provided)

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}

resource "azurerm_databricks_workspace" "this" {
  count = var.create_workspace ? 1 : 0

  name                = "${var.prefix}-databricks-${var.resource_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = "premium"

  tags = var.common_tags

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}
