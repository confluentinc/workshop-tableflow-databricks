# ===============================
# Confluent Catalog Integration Module
# ===============================
# Creates a Unity Catalog external catalog integration for Tableflow.
# Enables automated Delta Lake table synchronization to Databricks.

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.64.0"
    }
  }
}

resource "confluent_catalog_integration" "unity" {
  environment {
    id = var.environment_id
  }
  kafka_cluster {
    id = var.kafka_cluster_id
  }

  display_name = "${var.prefix}-unity-${var.resource_suffix}"

  unity {
    workspace_endpoint = var.databricks_workspace_url
    catalog_name       = var.databricks_catalog_name
    client_id          = var.databricks_sp_client_id
    client_secret      = var.databricks_sp_client_secret
  }

  credentials {
    key    = var.api_key
    secret = var.api_secret
  }
}
