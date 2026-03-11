# ===============================
# Databricks Module
# ===============================
# Creates Storage Credential and Grants (multi-cloud: AWS IAM Role or Azure Managed Identity)

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
  comment = var.cloud_provider == "aws" ? "Storage credential for Unity Catalog S3 access" : "Storage credential for Unity Catalog ADLS Gen2 access"

  dynamic "aws_iam_role" {
    for_each = var.cloud_provider == "aws" ? [1] : []
    content {
      role_arn = var.iam_role_arn
    }
  }

  dynamic "azure_managed_identity" {
    for_each = var.cloud_provider == "azure" ? [1] : []
    content {
      access_connector_id = var.azure_access_connector_id
    }
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

  dynamic "grant" {
    for_each = var.sso_email != "" ? [var.sso_email] : []
    content {
      principal = grant.value
      privileges = [
        "ALL_PRIVILEGES",
        "CREATE_EXTERNAL_LOCATION",
        "CREATE_EXTERNAL_TABLE",
        "READ_FILES",
        "WRITE_FILES"
      ]
    }
  }
}

# ===============================
# Workshop User
# ===============================

resource "databricks_user" "workshop" {
  provider  = databricks.workspace
  user_name = var.user_email
  force     = true
}

resource "databricks_user" "sso" {
  count     = var.sso_email != "" ? 1 : 0
  provider  = databricks.workspace
  user_name = var.sso_email
  force     = true
}

# ===============================
# SQL Warehouse Data Source
# ===============================

data "databricks_sql_warehouse" "main" {
  count    = var.cloud_provider == "aws" ? 1 : 0
  provider = databricks.workspace
  name     = "Serverless Starter Warehouse"
}
