# ===============================
# Data Generator Module
# ===============================
# Creates configuration files for ShadowTraffic data generation

# ===============================
# PostgreSQL Connection Config
# ===============================

resource "local_file" "postgres_connection" {
  content = jsonencode({
    kind : "postgres"
    tablePolicy : "create" # Create tables if they don't exist (won't drop existing data)
    connectionConfigs : {
      host : var.postgres_hostname
      port : var.postgres_port
      username : var.postgres_username
      password : var.postgres_password
      db : var.postgres_database
    }
  })
  filename = "${var.output_path}/postgres.json"
}

# ===============================
# Kafka Connection Config
# ===============================

resource "local_file" "kafka_connection" {
  content = jsonencode({
    kind : "kafka"
    logLevel : "ERROR"
    producerConfigs : {
      "bootstrap.servers" : var.kafka_bootstrap_endpoint
      "schema.registry.url" : var.schema_registry_endpoint
      "basic.auth.user.info" : "${var.schema_registry_api_key}:${var.schema_registry_api_secret}"
      "basic.auth.credentials.source" : "USER_INFO"
      "key.serializer" : "io.shadowtraffic.kafka.serdes.JsonSerializer"
      "value.serializer" : "io.confluent.kafka.serializers.KafkaAvroSerializer"
      "sasl.jaas.config" : "org.apache.kafka.common.security.plain.PlainLoginModule required username='${var.kafka_api_key}' password='${var.kafka_api_secret}';"
      "sasl.mechanism" : "PLAIN"
      "security.protocol" : "SASL_SSL"
    }
  })
  filename = "${var.output_path}/confluent.json"
}

# ===============================
# ShadowTraffic License
# ===============================

data "http" "shadow_traffic_license" {
  url = "https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license-docker.env"
}

resource "local_file" "shadow_traffic_license" {
  content  = data.http.shadow_traffic_license.response_body
  filename = "${var.output_path}/../shadow-traffic-license.env"
}
