provider "aws" {
  region = var.cloud_region

  default_tags {
    tags = {
      Created_by  = "terraform"
      Project     = "Workshop Shared Infrastructure"
      owner_email = var.owner_email
      Environment = "workshop"
    }
  }
}

provider "databricks" {
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_service_principal_client_id
  client_secret = var.databricks_service_principal_client_secret
}

provider "databricks" {
  alias         = "workspace"
  host          = var.databricks_host
  client_id     = var.databricks_service_principal_client_id
  client_secret = var.databricks_service_principal_client_secret
}
