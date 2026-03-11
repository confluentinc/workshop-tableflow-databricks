# ===============================
# Confluent Platform Module
# ===============================
# Creates Environment, Kafka Cluster, Schema Registry, Service Accounts, API Keys, and ACLs

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.32.0"
    }
  }
}

data "confluent_organization" "current" {}

locals {
  create_environment                  = var.environment_id == ""
  effective_environment_id            = local.create_environment ? confluent_environment.main[0].id : var.environment_id
  effective_environment_resource_name = local.create_environment ? confluent_environment.main[0].resource_name : data.confluent_environment.existing[0].resource_name
  effective_environment_display_name  = local.create_environment ? confluent_environment.main[0].display_name : data.confluent_environment.existing[0].display_name
}

# ===============================
# Environment (created only when environment_id is not provided)
# ===============================

resource "confluent_environment" "main" {
  count        = local.create_environment ? 1 : 0
  display_name = "${var.prefix}-environment-${var.resource_suffix}"

  stream_governance {
    package = "ADVANCED"
  }
}

data "confluent_environment" "existing" {
  count = local.create_environment ? 0 : 1
  id    = var.environment_id
}

# ===============================
# Kafka Cluster
# ===============================

resource "confluent_kafka_cluster" "main" {
  display_name = "${var.prefix}-cluster-${var.resource_suffix}"
  availability = "SINGLE_ZONE"
  cloud        = upper(var.cloud)
  region       = var.cloud_region

  dynamic "standard" {
    for_each = var.cluster_type == "standard" ? [1] : []
    content {}
  }

  dynamic "enterprise" {
    for_each = var.cluster_type == "enterprise" ? [1] : []
    content {}
  }

  environment {
    id = local.effective_environment_id
  }
}

# ===============================
# Schema Registry
# ===============================

data "confluent_schema_registry_cluster" "main" {
  environment {
    id = local.effective_environment_id
  }

  depends_on = [confluent_kafka_cluster.main]
}

# ===============================
# Service Account
# ===============================

resource "confluent_service_account" "app_manager" {
  display_name = "${var.prefix}-app-manager-${var.resource_suffix}"
  description  = "Service account for workshop Kafka cluster management"
}

# ===============================
# Role Binding
# ===============================

resource "confluent_role_binding" "app_manager_admin" {
  principal   = "User:${confluent_service_account.app_manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = local.effective_environment_resource_name
}

data "confluent_user" "workshop" {
  count = var.user_email != "" ? 1 : 0
  email = var.user_email
}

resource "confluent_role_binding" "user_env_admin" {
  count       = var.user_email != "" ? 1 : 0
  principal   = "User:${data.confluent_user.workshop[0].id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = local.effective_environment_resource_name
}

# ===============================
# Kafka API Key
# ===============================

resource "confluent_api_key" "kafka" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key for app-manager service account"

  owner {
    id          = confluent_service_account.app_manager.id
    api_version = confluent_service_account.app_manager.api_version
    kind        = confluent_service_account.app_manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.main.id
    api_version = confluent_kafka_cluster.main.api_version
    kind        = confluent_kafka_cluster.main.kind

    environment {
      id = local.effective_environment_id
    }
  }

  depends_on = [confluent_role_binding.app_manager_admin]
}

# ===============================
# Schema Registry API Key
# ===============================

resource "confluent_api_key" "schema_registry" {
  display_name = "app-manager-schema-registry-api-key"
  description  = "Schema Registry API Key for app-manager service account"

  owner {
    id          = confluent_service_account.app_manager.id
    api_version = confluent_service_account.app_manager.api_version
    kind        = confluent_service_account.app_manager.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.main.id
    api_version = data.confluent_schema_registry_cluster.main.api_version
    kind        = data.confluent_schema_registry_cluster.main.kind

    environment {
      id = local.effective_environment_id
    }
  }

  depends_on = [confluent_role_binding.app_manager_admin]
}

# ===============================
# ACLs
# ===============================

resource "confluent_kafka_acl" "read_topics" {
  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }
  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_manager.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.main.rest_endpoint

  credentials {
    key    = confluent_api_key.kafka.id
    secret = confluent_api_key.kafka.secret
  }
}

resource "confluent_kafka_acl" "write_topics" {
  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }
  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_manager.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.main.rest_endpoint

  credentials {
    key    = confluent_api_key.kafka.id
    secret = confluent_api_key.kafka.secret
  }
}

resource "confluent_kafka_acl" "create_topics" {
  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }
  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_manager.id}"
  host          = "*"
  operation     = "CREATE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.main.rest_endpoint

  credentials {
    key    = confluent_api_key.kafka.id
    secret = confluent_api_key.kafka.secret
  }
}

resource "confluent_kafka_acl" "describe_cluster" {
  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }
  resource_type = "CLUSTER"
  resource_name = "kafka-cluster"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_manager.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.main.rest_endpoint

  credentials {
    key    = confluent_api_key.kafka.id
    secret = confluent_api_key.kafka.secret
  }
}

resource "confluent_kafka_acl" "read_groups" {
  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }
  resource_type = "GROUP"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_manager.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.main.rest_endpoint

  credentials {
    key    = confluent_api_key.kafka.id
    secret = confluent_api_key.kafka.secret
  }
}
