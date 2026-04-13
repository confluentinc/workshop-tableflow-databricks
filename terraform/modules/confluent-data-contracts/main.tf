# ===============================
# Data Contracts Module
# ===============================
# Registers Avro schemas with CEL data quality rules and creates
# the DLQ topic for invalid events. Supports both self-service
# (direct Kafka) and instructor-led/demo (CDC) paths via topic_prefix.

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.32.0"
    }
  }
}

# ===============================
# DLQ Topic
# ===============================

resource "confluent_kafka_topic" "invalid_clickstream_events" {
  topic_name    = "invalid_clickstream_events"
  partitions_count = 1

  kafka_cluster {
    id = var.kafka_cluster_id
  }

  rest_endpoint = var.kafka_rest_endpoint

  credentials {
    key    = var.kafka_api_key
    secret = var.kafka_api_secret
  }
}

# ===============================
# Clickstream Schema with CEL DQR
# ===============================

resource "confluent_schema" "clickstream_value" {
  schema_registry_cluster {
    id = var.schema_registry_id
  }

  rest_endpoint = var.schema_registry_endpoint
  subject_name  = "${var.topic_prefix}clickstream-value"
  format        = "AVRO"
  schema        = file("${var.schemas_dir}/clickstream_schema.avsc")
  hard_delete   = true

  credentials {
    key    = var.schema_registry_api_key
    secret = var.schema_registry_api_secret
  }

  ruleset {
    domain_rules {
      name       = "validateClickstreamAction"
      kind       = "CONDITION"
      mode       = "WRITEREAD"
      type       = "CEL"
      expr       = "message.action.matches('^(page-view|page-click|booking-click)$')"
      on_failure = "DLQ"
      params = {
        "dlq.topic"      = confluent_kafka_topic.invalid_clickstream_events.topic_name
        "dlq.auto.flush" = "true"
      }
    }
  }
}

# ===============================
# DLQ Schema (reuses clickstream schema)
# ===============================

resource "confluent_schema" "invalid_clickstream_value" {
  schema_registry_cluster {
    id = var.schema_registry_id
  }

  rest_endpoint = var.schema_registry_endpoint
  subject_name  = "invalid_clickstream_events-value"
  format        = "AVRO"
  schema        = file("${var.schemas_dir}/clickstream_schema.avsc")
  hard_delete   = true

  credentials {
    key    = var.schema_registry_api_key
    secret = var.schema_registry_api_secret
  }
}

# ===============================
# Additional Schemas (self-service only)
# ===============================
# When auto.register.schemas=false, all schemas for topics produced
# directly to Kafka must be pre-registered.

resource "confluent_schema" "booking_value" {
  count = var.register_all_schemas ? 1 : 0

  schema_registry_cluster {
    id = var.schema_registry_id
  }

  rest_endpoint = var.schema_registry_endpoint
  subject_name  = "${var.topic_prefix}bookings-value"
  format        = "AVRO"
  schema        = file("${var.schemas_dir}/booking_schema.avsc")
  hard_delete   = true

  credentials {
    key    = var.schema_registry_api_key
    secret = var.schema_registry_api_secret
  }
}

resource "confluent_schema" "review_value" {
  count = var.register_all_schemas ? 1 : 0

  schema_registry_cluster {
    id = var.schema_registry_id
  }

  rest_endpoint = var.schema_registry_endpoint
  subject_name  = "${var.topic_prefix}reviews-value"
  format        = "AVRO"
  schema        = file("${var.schemas_dir}/review_schema.avsc")
  hard_delete   = true

  credentials {
    key    = var.schema_registry_api_key
    secret = var.schema_registry_api_secret
  }
}
