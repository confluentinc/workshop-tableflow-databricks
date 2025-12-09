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

# ===============================
# Environment
# ===============================

resource "confluent_environment" "main" {
  display_name = "${var.prefix}-environment-${var.resource_suffix}"

  stream_governance {
    package = "ADVANCED"
  }
}

# ===============================
# Kafka Cluster
# ===============================

resource "confluent_kafka_cluster" "main" {
  display_name = "${var.prefix}-cluster-${var.resource_suffix}"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = var.cloud_region
  standard {}

  environment {
    id = confluent_environment.main.id
  }
}

# ===============================
# Schema Registry
# ===============================

data "confluent_schema_registry_cluster" "main" {
  environment {
    id = confluent_environment.main.id
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
  crn_pattern = confluent_environment.main.resource_name
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
      id = confluent_environment.main.id
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
      id = confluent_environment.main.id
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
