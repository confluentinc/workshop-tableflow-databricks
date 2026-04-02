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
# Self-service (lookup_existing_users = true):  data source — user already
#   owns the workspace. Avoids invitation emails and entitlement stripping.
# WSA (lookup_existing_users = false):  managed resource with force = true —
#   user may not exist yet; resource ensures creation and cleanup on destroy.

# --- Data source path (self-service) ---

data "databricks_user" "workshop_existing" {
  count     = var.lookup_existing_users ? 1 : 0
  provider  = databricks.workspace
  user_name = var.user_email
}

data "databricks_user" "sso_existing" {
  count     = var.lookup_existing_users && var.sso_email != "" ? 1 : 0
  provider  = databricks.workspace
  user_name = var.sso_email
}

# --- Resource path (WSA) ---

resource "databricks_user" "workshop" {
  count     = var.lookup_existing_users ? 0 : 1
  provider  = databricks.workspace
  user_name = var.user_email
  force     = true
}

resource "databricks_user" "sso" {
  count     = !var.lookup_existing_users && var.sso_email != "" ? 1 : 0
  provider  = databricks.workspace
  user_name = var.sso_email
  force     = true
}

# --- Unified user IDs ---

locals {
  workshop_user_id = (
    var.lookup_existing_users
    ? data.databricks_user.workshop_existing[0].id
    : databricks_user.workshop[0].id
  )
  sso_user_id = (
    var.sso_email != ""
    ? (var.lookup_existing_users
      ? data.databricks_user.sso_existing[0].id
      : databricks_user.sso[0].id)
    : null
  )
}

# ===============================
# Workshop User Entitlements
# ===============================

resource "databricks_entitlements" "workshop" {
  provider = databricks.workspace
  user_id  = local.workshop_user_id

  workspace_access      = true
  databricks_sql_access = true
  allow_cluster_create  = true
}

resource "databricks_entitlements" "sso" {
  count    = var.sso_email != "" ? 1 : 0
  provider = databricks.workspace
  user_id  = local.sso_user_id

  workspace_access      = true
  databricks_sql_access = true
  allow_cluster_create  = true
}

# ===============================
# Workshop User Admin Group Membership
# ===============================

data "databricks_group" "admins" {
  count        = var.add_user_to_admins ? 1 : 0
  provider     = databricks.workspace
  display_name = "admins"
}

resource "databricks_group_member" "workshop_admin" {
  count     = var.add_user_to_admins ? 1 : 0
  provider  = databricks.workspace
  group_id  = data.databricks_group.admins[0].id
  member_id = local.workshop_user_id
}

# ===============================
# SQL Warehouse Data Source
# ===============================

data "databricks_sql_warehouse" "main" {
  count    = var.lookup_sql_warehouse ? 1 : 0
  provider = databricks.workspace
  name     = var.sql_warehouse_name
}
