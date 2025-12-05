# ===============================
# Provider Configuration
# ===============================
# Note: Version constraints are in versions.tf

# ===============================
# AWS Provider
# ===============================

provider "aws" {
  region = var.cloud_region

  default_tags {
    tags = {
      Created_by  = "terraform"
      Project     = "River Hotels Hospitality AI Insights"
      owner_email = var.email
      Environment = var.environment
    }
  }
}

# ===============================
# Confluent Provider
# ===============================

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# ===============================
# Databricks Provider
# ===============================

provider "databricks" {
  alias         = "workspace"
  host          = var.databricks_host
  client_id     = var.databricks_service_principal_client_id
  client_secret = var.databricks_service_principal_client_secret
}
