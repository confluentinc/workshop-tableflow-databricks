# ===============================
# Root Terraform Configuration — Azure Demo Mode
# ===============================
# Orchestrates all modules for the Tableflow Databricks Workshop in demo mode
# on Azure. Provisions everything that self-service mode requires PLUS:
#   - Unity Catalog integration (confluent_catalog_integration)
#   - Flink Materialized Table (denormalized_hotel_bookings)
#   - Tableflow topic enablement (clickstream, denormalized_hotel_bookings)
#   - Databricks notebook import (marketing agent)
#
# Note: reviews_with_sentiment and hotel_performance are intentionally omitted.
# AI_SENTIMENT (Confluent Cloud for Apache Flink) is currently AWS-only
# (announced 2026-03-19):
# https://docs.confluent.io/cloud/current/release-notes/index.html#march-19-2026
# When Azure support lands, set enable_reviews_with_sentiment = true on
# flink_ctas and tableflow_topics below (and optionally add hotel_performance).
#
# Supports two modes:
#   Self-service: all resources created per-account (shared_* vars empty)
#   WSA mode:     shared infra provided via shared_* vars

# ===============================
# Random ID for Resource Naming
# ===============================

resource "random_id" "env_display_id" {
  byte_length = 4
}

# ===============================
# Azure Client Config (for tenant_id fallback when variable is null)
# ===============================

data "azurerm_client_config" "current" {}

# ===============================
# Local Variables
# ===============================

locals {
  prefix          = "${var.prefix}-${var.project_name}"
  resource_suffix = random_id.env_display_id.hex

  # WSA: use per-account email when provided, fall back to self-service email
  effective_email = var.account_email != "" ? var.account_email : var.confluent_cloud_email

  # When shared_* vars are set, use them; otherwise use per-account module outputs.
  use_shared = var.shared_resource_group_name != ""

  effective_resource_group_name        = local.use_shared ? var.shared_resource_group_name : azurerm_resource_group.main[0].name
  effective_storage_account_name       = local.use_shared ? var.shared_storage_account_name : module.storage[0].storage_account_name
  effective_storage_account_id         = local.use_shared ? var.shared_storage_account_id : module.storage[0].storage_account_id
  effective_storage_container_name     = local.use_shared ? var.shared_storage_container_name : module.storage[0].container_name
  effective_abfss_url                  = local.use_shared ? "abfss://${var.shared_storage_container_name}@${var.shared_storage_account_name}.dfs.core.windows.net/" : module.storage[0].abfss_url
  effective_postgres_host              = local.use_shared ? var.shared_postgres_public_ip : module.postgres[0].fqdn
  effective_postgres_db_password       = local.use_shared && var.shared_postgres_db_password != "" ? var.shared_postgres_db_password : var.postgres_db_password
  effective_postgres_debezium_password = local.use_shared && var.shared_postgres_debezium_password != "" ? var.shared_postgres_debezium_password : var.postgres_debezium_password
  effective_resource_group_id          = local.use_shared ? var.shared_resource_group_id : azurerm_resource_group.main[0].id

  common_tags = {
    Project     = "Hospitality AI Agent"
    Environment = var.environment
    Created_by  = "Terraform"
    owner_email = local.effective_email
    mode        = "demo"
  }

  # Databricks workspace URL — auto-provisioned or pre-existing
  create_workspace         = var.databricks_host == ""
  databricks_workspace_url = local.create_workspace ? module.databricks_workspace.workspace_url : var.databricks_host
  databricks_workspace_id  = local.create_workspace ? module.databricks_workspace.workspace_id : null

  effective_access_connector_id = local.use_shared ? var.shared_dbx_access_connector_id : module.databricks_access_connector[0].access_connector_id

  # Topic names: WSA/shared uses CDC-prefixed topics; standalone demo uses plain names
  clickstream_topic = local.use_shared ? "riverhotel.cdc.clickstream" : "clickstream"
  bookings_topic    = local.use_shared ? "riverhotel.cdc.bookings" : "bookings"
  reviews_topic     = local.use_shared ? "riverhotel.cdc.reviews" : "reviews"
  customer_topic    = "riverhotel.cdc.customer"
  hotel_topic       = "riverhotel.cdc.hotel"
}

# ===============================
# Azure Resource Group
# ===============================

resource "azurerm_resource_group" "main" {
  count    = local.use_shared ? 0 : 1
  name     = var.azure_resource_group_name
  location = var.cloud_region

  tags = local.common_tags
}

# ===============================
# Azure Storage (ADLS Gen2)
# ===============================

module "storage" {
  count  = local.use_shared ? 0 : 1
  source = "../azure/modules/azure-storage"

  storage_account_prefix = var.azure_storage_account_prefix
  resource_suffix        = local.resource_suffix
  resource_group_name    = local.effective_resource_group_name
  region                 = var.cloud_region
  common_tags            = local.common_tags
}

# ===============================
# Confluent Platform
# ===============================

module "confluent_platform" {
  source = "../modules/confluent-platform"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  cloud           = "AZURE"
  cloud_region    = var.cloud_region
  cluster_type    = var.cluster_type
  environment_id  = var.cc_environment_id
  user_email      = local.effective_email
}

# ===============================
# Confluent Tableflow Provider Integration (Azure two-step)
# ===============================

module "tableflow" {
  source = "../modules/confluent-tableflow"

  prefix          = local.prefix
  resource_suffix = local.resource_suffix
  environment_id  = module.confluent_platform.environment_id
  cloud_provider  = "azure"
  azure_tenant_id = coalesce(var.azure_tenant_id, data.azurerm_client_config.current.tenant_id)

  depends_on = [module.confluent_platform]
}

# ===============================
# Azure Identity (Confluent SP + RBAC for Tableflow → ADLS Gen2)
# ===============================

module "identity" {
  source = "../azure/modules/azure-identity"

  confluent_multi_tenant_app_id = module.tableflow.azure_confluent_multi_tenant_app_id
  storage_account_id            = local.effective_storage_account_id
  resource_group_id             = local.effective_resource_group_id

  depends_on = [module.tableflow]
}

# ===============================
# Confluent Flink
# ===============================

module "flink" {
  source = "../modules/confluent-flink"

  prefix                      = local.prefix
  resource_suffix             = local.resource_suffix
  cloud                       = "AZURE"
  cloud_region                = var.cloud_region
  environment_id              = module.confluent_platform.environment_id
  service_account_id          = module.confluent_platform.service_account_id
  service_account_api_version = module.confluent_platform.service_account_api_version
  service_account_kind        = module.confluent_platform.service_account_kind

  depends_on = [module.confluent_platform]
}

# ===============================
# Azure PostgreSQL (Flexible Server)
# ===============================

module "postgres" {
  count  = local.use_shared ? 0 : 1
  source = "../azure/modules/azure-postgres"

  prefix              = local.prefix
  resource_suffix     = local.resource_suffix
  resource_group_name = local.effective_resource_group_name
  region              = var.cloud_region
  sku_name            = var.postgres_sku_name
  storage_mb          = var.postgres_storage_mb
  admin_username      = var.postgres_db_username
  admin_password      = local.effective_postgres_db_password
  db_name             = var.postgres_db_name
  debezium_username   = var.postgres_debezium_username
  debezium_password   = local.effective_postgres_debezium_password
  common_tags         = local.common_tags

  depends_on = [azurerm_resource_group.main]
}

# ===============================
# Cluster Networking (Private Link to PostgreSQL)
# ===============================

resource "confluent_network" "azure_egress" {
  count            = local.use_shared ? 0 : 1
  display_name     = "${local.prefix}-network-${local.resource_suffix}"
  cloud            = "AZURE"
  region           = var.cloud_region
  connection_types = ["PRIVATELINK"]

  environment {
    id = module.confluent_platform.environment_id
  }

  depends_on = [module.confluent_platform]
}

resource "confluent_access_point" "postgres" {
  count        = local.use_shared ? 0 : 1
  display_name = "${local.prefix}-postgres-ap-${local.resource_suffix}"

  environment {
    id = module.confluent_platform.environment_id
  }

  gateway {
    id = confluent_network.azure_egress[0].gateway[0].id
  }

  azure_egress_private_link_endpoint {
    private_link_service_resource_id = module.postgres[0].server_id
    private_link_subresource_name    = "postgresqlServer"
  }

  depends_on = [confluent_network.azure_egress, module.postgres]
}

# ===============================
# Databricks Workspace (auto-provisioned if no host provided)
# ===============================

module "databricks_workspace" {
  source = "../azure/modules/azure-databricks-workspace"

  prefix              = local.prefix
  resource_suffix     = local.resource_suffix
  resource_group_name = local.effective_resource_group_name
  region              = var.cloud_region
  create_workspace    = local.create_workspace
  common_tags         = local.common_tags
}

# ===============================
# Databricks Access Connector (managed identity → ADLS Gen2)
# ===============================

module "databricks_access_connector" {
  count  = local.use_shared ? 0 : 1
  source = "../azure/modules/azure-databricks-access-connector"

  prefix              = local.prefix
  resource_suffix     = local.resource_suffix
  resource_group_name = local.effective_resource_group_name
  region              = var.cloud_region
  storage_account_id  = local.effective_storage_account_id
  common_tags         = local.common_tags
}

# ===============================
# Databricks Metastore (Unity Catalog)
# ===============================

module "databricks_metastore" {
  count  = local.use_shared ? 0 : 1
  source = "../azure/modules/azure-databricks-metastore"

  providers = {
    databricks.workspace = databricks.workspace
  }

  workspace_id         = local.databricks_workspace_id
  storage_account_name = local.effective_storage_account_name
  container_name       = local.effective_storage_container_name
  access_connector_id  = local.effective_access_connector_id
  region               = var.cloud_region
  resource_suffix      = local.resource_suffix
  create_sql_warehouse = local.create_workspace

  depends_on = [module.databricks_workspace]
}

# ===============================
# Databricks Storage Credential (shared module — Azure path)
# ===============================

module "databricks" {
  source = "../modules/databricks"

  providers = {
    databricks.workspace = databricks.workspace
  }

  prefix                      = local.prefix
  resource_suffix             = local.resource_suffix
  cloud_provider              = "azure"
  azure_access_connector_id   = local.effective_access_connector_id
  user_email                  = var.databricks_user_email
  sso_email                   = var.databricks_sso_email
  service_principal_client_id = var.databricks_service_principal_client_id
  kafka_cluster_id            = module.confluent_platform.kafka_cluster_id
  sql_warehouse_name          = var.databricks_sql_warehouse_name

  # WSA mode (shared infra): create users via SCIM and skip admins membership.
  # Self-service mode: look up the existing user who owns the workspace.
  lookup_existing_users = !local.use_shared
  add_user_to_admins    = !local.use_shared
}

# ===============================
# Databricks External Location
# ===============================

resource "databricks_external_location" "main" {
  count    = local.use_shared ? 0 : 1
  provider = databricks.workspace

  name            = "${local.prefix}-external-location-${local.resource_suffix}"
  url             = "${local.effective_abfss_url}${local.prefix}/"
  credential_name = module.databricks.storage_credential_name
  comment         = "External location for Unity Catalog ADLS Gen2 access"
  force_destroy   = true

  depends_on = [module.databricks]
}

# ===============================
# Databricks External Location Grants
# ===============================

resource "databricks_grants" "external_location" {
  count    = local.use_shared ? 0 : 1
  provider = databricks.workspace

  external_location = databricks_external_location.main[0].name

  grant {
    principal = var.databricks_user_email
    privileges = [
      "ALL_PRIVILEGES",
      "MANAGE",
      "CREATE_EXTERNAL_TABLE",
      "CREATE_EXTERNAL_VOLUME",
      "READ_FILES",
      "WRITE_FILES",
      "CREATE_MANAGED_STORAGE",
      "EXTERNAL_USE_LOCATION"
    ]
  }

  grant {
    principal = var.databricks_service_principal_client_id
    privileges = [
      "ALL_PRIVILEGES",
      "MANAGE",
      "CREATE_EXTERNAL_TABLE",
      "CREATE_EXTERNAL_VOLUME",
      "READ_FILES",
      "WRITE_FILES",
      "CREATE_MANAGED_STORAGE",
      "EXTERNAL_USE_LOCATION"
    ]
  }
}

# ===============================
# Databricks Catalog
# ===============================

resource "databricks_catalog" "main" {
  provider = databricks.workspace

  name          = "${local.prefix}-${local.resource_suffix}"
  comment       = "Dedicated catalog for Confluent Tableflow integration"
  storage_root  = "${local.effective_abfss_url}${local.prefix}/catalog/"
  force_destroy = true

  depends_on = [module.databricks]
}

# ===============================
# Databricks Catalog Grants
# ===============================

resource "databricks_grants" "catalog" {
  provider = databricks.workspace

  catalog = databricks_catalog.main.name

  grant {
    principal = var.databricks_user_email
    privileges = [
      "ALL_PRIVILEGES",
      "USE_CATALOG",
      "CREATE_SCHEMA",
      "USE_SCHEMA",
      "EXTERNAL_USE_SCHEMA"
    ]
  }

  grant {
    principal = var.databricks_service_principal_client_id
    privileges = [
      "ALL_PRIVILEGES",
      "USE_CATALOG",
      "CREATE_SCHEMA",
      "USE_SCHEMA",
      "EXTERNAL_USE_SCHEMA",
      "CREATE_TABLE"
    ]
  }

  dynamic "grant" {
    for_each = var.databricks_sso_email != "" ? [var.databricks_sso_email] : []
    content {
      principal = grant.value
      privileges = [
        "ALL_PRIVILEGES",
        "USE_CATALOG",
        "CREATE_SCHEMA",
        "USE_SCHEMA",
        "EXTERNAL_USE_SCHEMA"
      ]
    }
  }

  depends_on = [databricks_catalog.main]
}

# ===============================
# Data Quality Rules (Data Contracts)
# ===============================
# Demo standalone path uses self-service generators (direct Kafka), so register
# all schemas with no topic prefix. Skip in WSA/shared mode (CDC collision).

module "data_contracts" {
  source = "../modules/confluent-data-contracts"

  count = local.use_shared ? 0 : 1

  environment_id             = module.confluent_platform.environment_id
  kafka_cluster_id           = module.confluent_platform.kafka_cluster_id
  kafka_rest_endpoint        = module.confluent_platform.kafka_rest_endpoint
  kafka_api_key              = module.confluent_platform.kafka_api_key
  kafka_api_secret           = module.confluent_platform.kafka_api_secret
  schema_registry_id         = module.confluent_platform.schema_registry_id
  schema_registry_endpoint   = module.confluent_platform.schema_registry_endpoint
  schema_registry_api_key    = module.confluent_platform.schema_registry_api_key
  schema_registry_api_secret = module.confluent_platform.schema_registry_api_secret
  schemas_dir                = "${path.module}/../../data/schemas"
  topic_prefix               = ""
  register_all_schemas       = true

  depends_on = [module.confluent_platform]
}

# ===============================
# Confluent PostgreSQL CDC Connector
# ===============================

module "connectors" {
  source = "../modules/confluent-connectors"

  prefix               = local.prefix
  environment_id       = module.confluent_platform.environment_id
  kafka_cluster_id     = module.confluent_platform.kafka_cluster_id
  service_account_id   = module.confluent_platform.service_account_id
  postgres_hostname    = local.effective_postgres_host
  postgres_port        = var.postgres_db_port
  database_name        = var.postgres_db_name
  debezium_username    = var.postgres_debezium_username
  debezium_password    = local.effective_postgres_debezium_password
  table_include_list   = var.table_include_list
  ssh_key_path         = ""
  initial_wait_seconds = local.use_shared ? 0 : 90

  depends_on = [module.postgres, module.confluent_platform, confluent_access_point.postgres, module.data_contracts]
}

# ===============================
# Confluent Flink Statements (ALTER TABLE on CDC topics)
# ===============================

module "flink_statements" {
  source = "../modules/confluent-flink-statements"

  organization_id            = module.confluent_platform.organization_id
  environment_id             = module.confluent_platform.environment_id
  environment_name           = module.confluent_platform.environment_name
  kafka_cluster_display_name = module.confluent_platform.kafka_cluster_display_name
  compute_pool_id            = module.flink.compute_pool_id
  service_account_id         = module.confluent_platform.service_account_id
  flink_api_key              = module.flink.flink_api_key
  flink_api_secret           = module.flink.flink_api_secret
  flink_rest_endpoint        = module.flink.flink_rest_endpoint

  clickstream_topic = local.clickstream_topic
  bookings_topic    = local.bookings_topic
  reviews_topic     = local.reviews_topic

  depends_on = [module.connectors, module.flink]
}

# ===============================
# Data Generator Configuration
# ===============================

module "data_generator" {
  count  = local.use_shared ? 0 : 1
  source = "../modules/data-generator"

  output_path                = "../../data/connections"
  postgres_hostname          = local.effective_postgres_host
  postgres_port              = var.postgres_db_port
  postgres_username          = var.postgres_db_username
  postgres_password          = local.effective_postgres_db_password
  postgres_database          = var.postgres_db_name
  kafka_bootstrap_endpoint   = module.confluent_platform.bootstrap_endpoint_url
  kafka_api_key              = module.confluent_platform.kafka_api_key
  kafka_api_secret           = module.confluent_platform.kafka_api_secret
  schema_registry_endpoint   = module.confluent_platform.schema_registry_endpoint
  schema_registry_api_key    = module.confluent_platform.schema_registry_api_key
  schema_registry_api_secret = module.confluent_platform.schema_registry_api_secret

  depends_on = [module.confluent_platform]
}

# =========================================================================
# DEMO MODE RESOURCES
# =========================================================================
# Everything below this line is specific to demo mode and does not exist
# in the self-service terraform/azure/ root.

# ===============================
# Tableflow API Key
# ===============================

resource "confluent_api_key" "tableflow" {
  display_name = "${local.prefix}-tableflow-${local.resource_suffix}"

  owner {
    id          = module.confluent_platform.service_account_id
    api_version = module.confluent_platform.service_account_api_version
    kind        = module.confluent_platform.service_account_kind
  }

  managed_resource {
    id          = "tableflow"
    api_version = "tableflow/v1"
    kind        = "Tableflow"

    environment {
      id = module.confluent_platform.environment_id
    }
  }

  depends_on = [module.confluent_platform]
}

# ===============================
# Unity Catalog Integration
# ===============================

module "catalog_integration" {
  source = "../modules/confluent-catalog-integration"

  prefix           = local.prefix
  resource_suffix  = local.resource_suffix
  environment_id   = module.confluent_platform.environment_id
  kafka_cluster_id = module.confluent_platform.kafka_cluster_id

  databricks_workspace_url    = local.databricks_workspace_url
  databricks_catalog_name     = databricks_catalog.main.name
  databricks_sp_client_id     = var.databricks_service_principal_client_id
  databricks_sp_client_secret = var.databricks_service_principal_client_secret

  api_key    = confluent_api_key.tableflow.id
  api_secret = confluent_api_key.tableflow.secret

  depends_on = [
    module.flink_statements,
    module.connectors,
    databricks_catalog.main,
    confluent_api_key.tableflow,
  ]
}

# ===============================
# Flink Materialized Tables
# ===============================
# Creates denormalized_hotel_bookings only.
#
# reviews_with_sentiment is DISABLED on Azure — AI_SENTIMENT is AWS-only today.
# See: https://docs.confluent.io/cloud/current/release-notes/index.html#march-19-2026
#
# To enable when Azure support is available:
#   enable_reviews_with_sentiment = true
# (also flip the same flag on module.tableflow_topics below)

module "flink_ctas" {
  source = "../modules/confluent-flink-ctas"

  organization_id            = module.confluent_platform.organization_id
  environment_id             = module.confluent_platform.environment_id
  environment_name           = module.confluent_platform.environment_name
  kafka_cluster_id           = module.confluent_platform.kafka_cluster_id
  kafka_cluster_display_name = module.confluent_platform.kafka_cluster_display_name
  compute_pool_id            = module.flink.compute_pool_id
  service_account_id         = module.confluent_platform.service_account_id
  flink_api_key              = module.flink.flink_api_key
  flink_api_secret           = module.flink.flink_api_secret
  flink_rest_endpoint        = module.flink.flink_rest_endpoint

  bookings_topic = local.bookings_topic
  reviews_topic  = local.reviews_topic
  customer_topic = local.customer_topic
  hotel_topic    = local.hotel_topic

  # AWS-only today — do not enable until AI_SENTIMENT is available on Azure
  enable_reviews_with_sentiment = false

  # flink_statements configures changelog/watermark; connectors ensure CDC topics exist
  depends_on = [module.flink_statements, module.connectors]
}

# ===============================
# Tableflow Topic Enablement
# ===============================
# Enables Tableflow on clickstream + denormalized_hotel_bookings.
# reviews_with_sentiment Tableflow is skipped (same AI_SENTIMENT Azure gap).

module "tableflow_topics" {
  source = "../modules/confluent-tableflow-topics"

  environment_id   = module.confluent_platform.environment_id
  kafka_cluster_id = module.confluent_platform.kafka_cluster_id
  cloud_provider   = "azure"

  storage_account_name    = local.effective_storage_account_name
  container_name          = local.effective_storage_container_name
  provider_integration_id = module.tableflow.integration_id
  clickstream_topic       = local.clickstream_topic

  # Keep in sync with module.flink_ctas.enable_reviews_with_sentiment
  enable_reviews_with_sentiment = false

  api_key    = confluent_api_key.tableflow.id
  api_secret = confluent_api_key.tableflow.secret

  depends_on = [
    module.flink_ctas,
    module.catalog_integration,
    module.identity,
    confluent_api_key.tableflow,
  ]
}

# ===============================
# Databricks Notebook Import
# ===============================

resource "databricks_notebook" "marketing_agent" {
  provider = databricks.workspace

  path     = "/Shared/workshop/river_hotel_marketing_agent"
  language = "PYTHON"
  source   = "${path.module}/../../labs/shared/river_hotel_marketing_agent.ipynb"
  format   = "JUPYTER"

  depends_on = [databricks_catalog.main]
}
