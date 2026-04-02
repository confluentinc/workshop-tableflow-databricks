provider "azurerm" {
  features {}
  resource_provider_registrations = "core"
}

provider "databricks" {
  alias     = "workspace"
  host      = var.databricks_host
  auth_type = "azure-client-secret"
}
