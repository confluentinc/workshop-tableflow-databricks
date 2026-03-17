provider "azurerm" {
  features {}
  resource_provider_registrations = "core"
}

provider "databricks" {
  alias         = "workspace"
  host          = var.databricks_host
  client_id     = var.databricks_service_principal_client_id
  client_secret = var.databricks_service_principal_client_secret
  auth_type     = "oauth-m2m"
}
