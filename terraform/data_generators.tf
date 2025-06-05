resource "local_file" "oracle_connection_config" {
  content = jsonencode({
    kind : "oracle"
    tablePolicy : "dropAndCreate"
    connectionConfigs : {
      host : "${aws_instance.oracle_instance.public_ip}"
      port : "${var.oracle_db_port}"
      username : "${var.oracle_db_username}"
      password : "${var.oracle_db_password}"
      db : "XEPDB1"
    }
  })
  filename = "../data/connections/oracle.json"
}

resource "local_file" "kafka_connection_config" {
  content = jsonencode({
    kind : "kafka"
    logLevel : "ERROR",
    producerConfigs : {
      "bootstrap.servers" : "${local.bootstrap_endpoint_url_only}",
      "schema.registry.url" : "${data.confluent_schema_registry_cluster.sr-cluster.rest_endpoint}",
      "basic.auth.user.info" : "${confluent_api_key.app-manager-schema-registry-api-key.id}:${confluent_api_key.app-manager-schema-registry-api-key.secret}",
      "basic.auth.credentials.source" : "USER_INFO",
      "key.serializer" : "io.shadowtraffic.kafka.serdes.JsonSerializer",
      "value.serializer" : "io.confluent.kafka.serializers.KafkaAvroSerializer",
      "sasl.jaas.config" : "org.apache.kafka.common.security.plain.PlainLoginModule required username='${confluent_api_key.app-manager-kafka-api-key.id}' password='${confluent_api_key.app-manager-kafka-api-key.secret}';",
      "sasl.mechanism" : "PLAIN",
      "security.protocol" : "SASL_SSL"
    }
  })
  filename = "../data/connections/confluent.json"
}
