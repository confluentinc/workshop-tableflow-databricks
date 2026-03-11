# Databricks Unity Catalog Metastore for Azure

terraform {
  required_providers {
    databricks = {
      source                = "databricks/databricks"
      version               = ">= 1.79.0"
      configuration_aliases = [databricks.workspace]
    }
  }
}

locals {
  create_metastore = var.existing_metastore_id == null
  metastore_id     = local.create_metastore ? databricks_metastore.this[0].id : var.existing_metastore_id
}

resource "databricks_metastore" "this" {
  count    = local.create_metastore ? 1 : 0
  provider = databricks.workspace

  name         = "unity-metastore-${var.region}-${var.resource_suffix}"
  region       = var.region
  storage_root = "abfss://${var.container_name}@${var.storage_account_name}.dfs.core.windows.net/metastore"

  force_destroy = true
}

resource "databricks_metastore_data_access" "this" {
  count    = local.create_metastore ? 1 : 0
  provider = databricks.workspace

  metastore_id = databricks_metastore.this[0].id
  name         = "unity-metastore-access-${var.resource_suffix}"

  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }

  is_default = true
}

resource "databricks_metastore_assignment" "this" {
  count    = var.skip_metastore_assignment ? 0 : 1
  provider = databricks.workspace

  workspace_id = var.workspace_id
  metastore_id = local.metastore_id
}

resource "databricks_sql_endpoint" "unity" {
  count    = var.create_sql_warehouse ? 1 : 0
  provider = databricks.workspace

  name             = "Workshop Warehouse"
  cluster_size     = "2X-Small"
  max_num_clusters = 1

  enable_photon             = true
  enable_serverless_compute = false
  warehouse_type            = "PRO"

  auto_stop_mins = 10

  tags {
    custom_tags {
      key   = "ManagedBy"
      value = "Terraform"
    }
    custom_tags {
      key   = "Environment"
      value = "Workshop"
    }
  }

  depends_on = [databricks_metastore_assignment.this]
}
