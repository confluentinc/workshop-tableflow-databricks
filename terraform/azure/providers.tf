# ===============================
# Provider Configuration
# ===============================

# ===============================
# Azure Resource Manager
# ===============================

provider "azurerm" {
  subscription_id                 = var.azure_subscription_id
  resource_provider_registrations = "core"

  features {}
}

# ===============================
# Azure Active Directory
# ===============================

provider "azuread" {
  tenant_id = var.azure_tenant_id
}

# ===============================
# Confluent Provider
# ===============================

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# ===============================
# Databricks Provider (Workspace)
# ===============================

provider "databricks" {
  alias = "workspace"
  host  = local.databricks_workspace_url
}
