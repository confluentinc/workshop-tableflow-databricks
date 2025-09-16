data "confluent_organization" "current" {}

locals {
  bootstrap_endpoint_url_only = split("SASL_SSL://", confluent_kafka_cluster.standard.bootstrap_endpoint)[1]
  # bedrock_ai_connection_endpoint = "https://bedrock-runtime.${var.cloud_region}.amazonaws.com/model/${var.aws_bedrock_anthropic_model_id}/invoke"
}

# ------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------

resource "confluent_environment" "staging" {
  display_name = "${local.prefix}-environment-${random_id.env_display_id.hex}"

  stream_governance {
    package = "ADVANCED"
  }
}

# ------------------------------------------------------
# KAFKA Cluster
# ------------------------------------------------------

data "confluent_schema_registry_cluster" "sr-cluster" {
  environment {
    id = confluent_environment.staging.id
  }

  depends_on = [
    confluent_kafka_cluster.standard
  ]
}

# Update the config to use a cloud provider and region of your choice.
# https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/confluent_kafka_cluster
resource "confluent_kafka_cluster" "standard" {
  display_name = "${local.prefix}-cluster-${random_id.env_display_id.hex}"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = var.cloud_region
  standard {}
  environment {
    id = confluent_environment.staging.id
  }
}

# ------------------------------------------------------
# SERVICE ACCOUNTS
# ------------------------------------------------------

resource "confluent_service_account" "app-manager" {
  display_name = "${local.prefix}-app-manager-${random_id.env_display_id.hex}"
  description  = "Service account to manage 'inventory' Kafka cluster"
}

resource "confluent_role_binding" "app-manager-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.staging.resource_name
}

# -------------------------------
# Confluent Provider Integration
# -------------------------------

resource "confluent_provider_integration" "s3_tableflow_integration" {
  display_name = "${local.prefix}-s3-integration-${random_id.env_display_id.hex}"
  environment {
    id = confluent_environment.staging.id
  }
  aws {
    # During the creation of confluent_provider_integration.main, the S3 role does not yet exist.
    # The role will be created after confluent_provider_integration.main is provisioned
    # by the s3_access_role module using the specified target name.
    # Note: This is a workaround to avoid updating an existing role or creating a circular dependency.
    customer_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.iam_role_name}"
  }
}

output "s3_tableflow_integration_details" {
  value = {
    role_arn    = confluent_provider_integration.s3_tableflow_integration.aws[0].iam_role_arn
    external_id = confluent_provider_integration.s3_tableflow_integration.aws[0].external_id
  }
  sensitive = false
}

# Service Account API Keys for Connector Configuration
output "confluent_service_account_credentials" {
  description = "Service account API keys for Oracle XStream connector and other integrations"
  value = {
    service_account_id         = confluent_service_account.app-manager.id
    kafka_api_key              = confluent_api_key.app-manager-kafka-api-key.id
    kafka_api_secret           = confluent_api_key.app-manager-kafka-api-key.secret
    schema_registry_api_key    = confluent_api_key.app-manager-schema-registry-api-key.id
    schema_registry_api_secret = confluent_api_key.app-manager-schema-registry-api-key.secret
    flink_api_key              = confluent_api_key.app-manager-flink-api-key.id
    flink_api_secret           = confluent_api_key.app-manager-flink-api-key.secret
  }
  sensitive = true
}

# ------------------------------------------------------
# Flink Compute Pool
# ------------------------------------------------------

resource "confluent_flink_compute_pool" "flink-compute-pool" {
  display_name = "${local.prefix}_flink_compute_pool_${random_id.env_display_id.hex}"
  cloud        = "AWS"
  region       = var.cloud_region
  max_cfu      = 20
  environment {
    id = confluent_environment.staging.id
  }
}

# ------------------------------------------------------
# API Keys
# ------------------------------------------------------

resource "confluent_api_key" "app-manager-kafka-api-key" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.standard.id
    api_version = confluent_kafka_cluster.standard.api_version
    kind        = confluent_kafka_cluster.standard.kind

    environment {
      id = confluent_environment.staging.id
    }
  }

  depends_on = [
    confluent_role_binding.app-manager-kafka-cluster-admin
  ]
}


resource "confluent_api_key" "app-manager-schema-registry-api-key" {
  display_name = "env-manager-schema-registry-api-key"
  description  = "Schema Registry API Key that is owned by 'env-manager' service account"

  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr-cluster.id
    api_version = data.confluent_schema_registry_cluster.sr-cluster.api_version
    kind        = data.confluent_schema_registry_cluster.sr-cluster.kind

    environment {
      id = confluent_environment.staging.id
    }
  }
  depends_on = [
    confluent_role_binding.app-manager-kafka-cluster-admin
  ]
}

data "confluent_flink_region" "demo_flink_region" {
  cloud  = "AWS"
  region = var.cloud_region
}

# Flink management API Keys

resource "confluent_api_key" "app-manager-flink-api-key" {
  display_name = "env-manager-flink-api-key"
  description  = "Flink API Key that is owned by 'env-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.demo_flink_region.id
    api_version = data.confluent_flink_region.demo_flink_region.api_version
    kind        = data.confluent_flink_region.demo_flink_region.kind

    environment {
      id = confluent_environment.staging.id
    }
  }
}



# ------------------------------------------------------
# ACLS
# ------------------------------------------------------




resource "confluent_kafka_acl" "app-manager-read-on-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.standard.id
  }
  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.standard.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-manager-describe-on-cluster" {
  kafka_cluster {
    id = confluent_kafka_cluster.standard.id
  }
  resource_type = "CLUSTER"
  resource_name = "kafka-cluster"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.standard.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}


resource "confluent_kafka_acl" "app-manager-write-on-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.standard.id
  }
  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.standard.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-manager-create-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.standard.id
  }
  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "CREATE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.standard.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-manager-read-on-group" {
  kafka_cluster {
    id = confluent_kafka_cluster.standard.id
  }
  resource_type = "GROUP"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.standard.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}


output "confluent" {
  value = <<-EOT
  Environment ID:   ${confluent_environment.staging.id}
  Kafka Cluster ID: ${confluent_kafka_cluster.standard.id}
  Flink Compute pool ID: ${confluent_flink_compute_pool.flink-compute-pool.id}

  Service Accounts and their Kafka API Keys (API Keys inherit the permissions granted to the owner):
  ${confluent_service_account.app-manager.display_name}:                     ${confluent_service_account.app-manager.id}
  ${confluent_service_account.app-manager.display_name}'s Kafka API Key:     "${confluent_api_key.app-manager-kafka-api-key.id}"
  ${confluent_service_account.app-manager.display_name}'s Kafka API Secret:  "${confluent_api_key.app-manager-kafka-api-key.secret}"


  Service Accounts and their Flink management API Keys (API Keys inherit the permissions granted to the owner):
  ${confluent_service_account.app-manager.display_name}:                     ${confluent_service_account.app-manager.id}
  ${confluent_service_account.app-manager.display_name}'s Flink management API Key:     "${confluent_api_key.app-manager-flink-api-key.id}"
  ${confluent_service_account.app-manager.display_name}'s Flink management API Secret:  "${confluent_api_key.app-manager-flink-api-key.secret}"


  sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="${confluent_api_key.app-manager-kafka-api-key.id}" password="${confluent_api_key.app-manager-kafka-api-key.secret}";
  bootstrap.servers=${confluent_kafka_cluster.standard.bootstrap_endpoint}
  schema.registry.url= ${data.confluent_schema_registry_cluster.sr-cluster.rest_endpoint}
  schema.registry.basic.auth.user.info= "${confluent_api_key.app-manager-schema-registry-api-key.id}:${confluent_api_key.app-manager-schema-registry-api-key.secret}"

  Confluent Cloud Tableflow Provider Integration ID: ${confluent_provider_integration.s3_tableflow_integration.id}

  EOT

  sensitive = true
}

# Flink Connection ID: ${confluent_flink_connection.bedrock_ai_connection.id}
