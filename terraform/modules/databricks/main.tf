# ===============================
# Databricks Module
# ===============================
# Creates Storage Credential, External Location, Catalog, and Grants

terraform {
  required_providers {
    databricks = {
      source                = "databricks/databricks"
      version               = ">= 1.79.0"
      configuration_aliases = [databricks.workspace]
    }
  }
}

# ===============================
# Storage Credential
# ===============================

resource "databricks_storage_credential" "main" {
  provider = databricks.workspace

  name    = "${var.prefix}-storage-credential-${var.resource_suffix}"
  comment = "Storage credential for Unity Catalog S3 access"

  aws_iam_role {
    role_arn = var.iam_role_arn
  }
}

# ===============================
# Storage Credential Grants
# ===============================

resource "databricks_grants" "storage_credential" {
  provider = databricks.workspace

  storage_credential = databricks_storage_credential.main.name

  grant {
    principal = var.user_email
    privileges = [
      "ALL_PRIVILEGES",
      "CREATE_EXTERNAL_LOCATION",
      "CREATE_EXTERNAL_TABLE",
      "READ_FILES",
      "WRITE_FILES"
    ]
  }

  grant {
    principal = var.service_principal_client_id
    privileges = [
      "ALL_PRIVILEGES",
      "CREATE_EXTERNAL_LOCATION",
      "CREATE_EXTERNAL_TABLE",
      "READ_FILES",
      "WRITE_FILES"
    ]
  }
}

# ===============================
# Note: External Location, Catalog, and their Grants
# are created in root main.tf AFTER the IAM trust policy
# is updated. This avoids the 403 Forbidden error.
# ===============================

# ===============================
# SQL Warehouse Data Source
# ===============================

data "databricks_sql_warehouse" "main" {
  provider = databricks.workspace
  name     = "Starter Warehouse"
}
