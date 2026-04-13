# ===============================
# Data Generator Module
# ===============================
# Creates connection configuration files for the custom data generator

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
      "key.serializer" : "org.apache.kafka.common.serialization.StringSerializer"
      "value.serializer" : "io.confluent.kafka.serializers.KafkaAvroSerializer"
      "sasl.jaas.config" : "org.apache.kafka.common.security.plain.PlainLoginModule required username='${var.kafka_api_key}' password='${var.kafka_api_secret}';"
      "sasl.mechanism" : "PLAIN"
      "security.protocol" : "SASL_SSL"
      "auto.register.schemas" : "false"
      "use.latest.version" : "true"
    }
  })
  filename = "${var.output_path}/confluent.json"
}

