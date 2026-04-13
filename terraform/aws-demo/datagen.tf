# ===============================
# Data Generator
# ===============================
# Runs the workshop data generator as a Docker container on the PostgreSQL EC2 instance.
# Writes to BOTH PostgreSQL (customer, hotel via CDC) and Kafka directly
# (clickstream, bookings, reviews with Avro schemas).

variable "enable_datagen" {
  description = "Whether to run the data generator on the PostgreSQL instance"
  type        = bool
  default     = true
}

variable "datagen_image" {
  description = "Data generator Docker image"
  type        = string
  default     = "public.ecr.aws/v3a9u0p7/workshop-datagen:latest"
}

variable "datagen_ssh_username" {
  description = "SSH username for the PostgreSQL EC2 instance"
  type        = string
  default     = "ec2-user"
}

locals {
  deploy_datagen = var.enable_datagen
  data_dir       = "${path.module}/../../data"
}

# ===============================
# PostgreSQL Connection Config
# ===============================

resource "local_file" "datagen_postgres_connection" {
  count = local.deploy_datagen ? 1 : 0

  content = jsonencode({
    kind        = "postgres"
    tablePolicy = "create"
    connectionConfigs = {
      host     = "localhost"
      port     = 5432
      username = var.postgres_db_username
      password = var.postgres_db_password
      db       = var.postgres_db_name
    }
  })

  filename        = "${path.module}/generated/connections/postgres.json"
  file_permission = "0600"
}

# ===============================
# Confluent Cloud Connection Config
# ===============================

resource "local_file" "datagen_confluent_connection" {
  count = local.deploy_datagen ? 1 : 0

  content = jsonencode({
    kind     = "kafka"
    logLevel = "ERROR"
    producerConfigs = {
      "bootstrap.servers"              = module.confluent_platform.bootstrap_endpoint_url
      "schema.registry.url"            = module.confluent_platform.schema_registry_endpoint
      "basic.auth.user.info"           = "${module.confluent_platform.schema_registry_api_key}:${module.confluent_platform.schema_registry_api_secret}"
      "basic.auth.credentials.source"  = "USER_INFO"
      "key.serializer"                 = "org.apache.kafka.common.serialization.StringSerializer"
      "value.serializer"               = "io.confluent.kafka.serializers.KafkaAvroSerializer"
      "sasl.jaas.config"               = "org.apache.kafka.common.security.plain.PlainLoginModule required username='${module.confluent_platform.kafka_api_key}' password='${module.confluent_platform.kafka_api_secret}';"
      "sasl.mechanism"                 = "PLAIN"
      "security.protocol"              = "SASL_SSL"
      "auto.register.schemas"          = "false"
      "use.latest.version"             = "true"
    }
  })

  filename        = "${path.module}/generated/connections/confluent.json"
  file_permission = "0600"
}

# ===============================
# Data generator setup via SSH
# ===============================

resource "null_resource" "datagen_setup" {
  count = local.deploy_datagen ? 1 : 0

  triggers = {
    instance_id    = module.postgres.instance_id
    pg_config_hash = md5(local_file.datagen_postgres_connection[0].content)
    cc_config_hash = md5(local_file.datagen_confluent_connection[0].content)
  }

  depends_on = [
    module.postgres,
    module.keypair,
    module.confluent_platform,
    local_file.datagen_postgres_connection,
    local_file.datagen_confluent_connection,
  ]

  connection {
    type        = "ssh"
    host        = module.postgres.public_dns
    user        = var.datagen_ssh_username
    private_key = file(module.keypair.private_key_path)
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/datagen/data/generators-shared/content",
      "sudo mkdir -p /opt/datagen/data/generators-self-service",
      "sudo mkdir -p /opt/datagen/data/connections",
      "sudo mkdir -p /opt/datagen/data/schemas",
      "sudo chmod -R 777 /opt/datagen",
    ]
  }

  provisioner "file" {
    source      = local_file.datagen_postgres_connection[0].filename
    destination = "/opt/datagen/data/connections/postgres.json"
  }
  provisioner "file" {
    source      = local_file.datagen_confluent_connection[0].filename
    destination = "/opt/datagen/data/connections/confluent.json"
  }

  provisioner "file" {
    source      = "${local.data_dir}/java-datagen-configuration.json"
    destination = "/opt/datagen/data/java-datagen-configuration.json"
  }

  # Shared generators
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/customer_generator_historical.json"
    destination = "/opt/datagen/data/generators-shared/customer_generator_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/customer_generator_streaming.json"
    destination = "/opt/datagen/data/generators-shared/customer_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/hotel_generator_historical.json"
    destination = "/opt/datagen/data/generators-shared/hotel_generator_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/hotel_generator_streaming.json"
    destination = "/opt/datagen/data/generators-shared/hotel_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/customer_updates_historical.json"
    destination = "/opt/datagen/data/generators-shared/customer_updates_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/hotel_updates_historical.json"
    destination = "/opt/datagen/data/generators-shared/hotel_updates_historical.json"
  }

  # Self-service generators (clickstream, bookings, reviews -> Kafka)
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/clickstream_generator_historical.json"
    destination = "/opt/datagen/data/generators-self-service/clickstream_generator_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/clickstream_generator_streaming.json"
    destination = "/opt/datagen/data/generators-self-service/clickstream_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/booking_generator_historical.json"
    destination = "/opt/datagen/data/generators-self-service/booking_generator_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/booking_generator_streaming.json"
    destination = "/opt/datagen/data/generators-self-service/booking_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/review_generator_historical.json"
    destination = "/opt/datagen/data/generators-self-service/review_generator_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/review_generator_streaming.json"
    destination = "/opt/datagen/data/generators-self-service/review_generator_streaming.json"
  }

  # Content files
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/hotel_descriptions_airport.json"
    destination = "/opt/datagen/data/generators-shared/content/hotel_descriptions_airport.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/hotel_descriptions_economy.json"
    destination = "/opt/datagen/data/generators-shared/content/hotel_descriptions_economy.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/hotel_descriptions_extended_stay.json"
    destination = "/opt/datagen/data/generators-shared/content/hotel_descriptions_extended_stay.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/hotel_descriptions_luxury.json"
    destination = "/opt/datagen/data/generators-shared/content/hotel_descriptions_luxury.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/hotel_descriptions_resort.json"
    destination = "/opt/datagen/data/generators-shared/content/hotel_descriptions_resort.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/review_text_choices_1_star.json"
    destination = "/opt/datagen/data/generators-shared/content/review_text_choices_1_star.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/review_text_choices_2_star.json"
    destination = "/opt/datagen/data/generators-shared/content/review_text_choices_2_star.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/review_text_choices_3_star.json"
    destination = "/opt/datagen/data/generators-shared/content/review_text_choices_3_star.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/review_text_choices_4_star.json"
    destination = "/opt/datagen/data/generators-shared/content/review_text_choices_4_star.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/review_text_choices_5_star.json"
    destination = "/opt/datagen/data/generators-shared/content/review_text_choices_5_star.json"
  }

  # Avro schemas
  provisioner "file" {
    source      = "${local.data_dir}/schemas/clickstream_schema.avsc"
    destination = "/opt/datagen/data/schemas/clickstream_schema.avsc"
  }
  provisioner "file" {
    source      = "${local.data_dir}/schemas/booking_schema.avsc"
    destination = "/opt/datagen/data/schemas/booking_schema.avsc"
  }
  provisioner "file" {
    source      = "${local.data_dir}/schemas/review_schema.avsc"
    destination = "/opt/datagen/data/schemas/review_schema.avsc"
  }

  provisioner "remote-exec" {
    inline = [
      <<-SCRIPT
      set -e
      echo '================================================'
      echo 'Data Generator Setup (Demo Mode)'
      echo '================================================'

      echo 'Waiting for PostgreSQL to be healthy...'
      MAX_RETRIES=60
      COUNT=0
      while [ $COUNT -lt $MAX_RETRIES ]; do
        if sudo docker exec postgres-workshop pg_isready -U postgres -d ${var.postgres_db_name} 2>/dev/null; then
          echo 'PostgreSQL is healthy!'
          break
        fi
        COUNT=$((COUNT + 1))
        echo "  Attempt $COUNT/$MAX_RETRIES - waiting 10s..."
        sleep 10
      done

      if [ $COUNT -eq $MAX_RETRIES ]; then
        echo 'ERROR: PostgreSQL did not become healthy after 10 minutes'
        exit 1
      fi

      sudo docker stop datagen 2>/dev/null || true
      sudo docker rm datagen 2>/dev/null || true

      echo ''
      echo 'Pulling Data Generator image...'
      sudo docker pull ${var.datagen_image}

      echo ''
      echo 'Starting Data Generator...'
      sudo docker run -d --name datagen \
        --network host \
        --restart on-failure:3 \
        --health-cmd "curl -sf http://localhost:9400 || exit 1" \
        --health-interval 30s \
        --health-retries 3 \
        --health-start-period 60s \
        -v /opt/datagen/data:/home/data \
        ${var.datagen_image} \
        --config /home/data/java-datagen-configuration.json

      echo ''
      echo 'Waiting for Data Generator to initialize (30s)...'
      sleep 30

      echo ''
      echo 'Data Generator container status:'
      sudo docker ps --filter name=datagen --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

      if ! sudo docker ps --filter name=datagen --format '{{.Names}}' | grep -q datagen; then
        echo ''
        echo 'ERROR: Data Generator container is not running!'
        echo 'Container logs:'
        sudo docker logs datagen 2>&1
        exit 1
      fi

      echo ''
      echo 'Data Generator logs (last 30 lines):'
      sudo docker logs datagen 2>&1 | tail -30

      echo ''
      echo 'Checking PostgreSQL tables for data...'
      sudo docker exec postgres-workshop psql -U postgres -d ${var.postgres_db_name} -c "
        SELECT 'cdc.customer' as table_name, count(*) FROM cdc.customer
        UNION ALL SELECT 'cdc.hotel', count(*) FROM cdc.hotel;"

      echo ''
      echo '================================================'
      echo 'Data Generator setup complete!'
      echo '================================================'
      SCRIPT
    ]
  }
}

# ===============================
# Data generator outputs
# ===============================

output "datagen_enabled" {
  description = "Whether the data generator is running on the EC2 instance"
  value       = local.deploy_datagen
}

output "datagen_ssh_command" {
  description = "SSH command to check Data Generator logs"
  value       = local.deploy_datagen ? "ssh -i ${module.keypair.private_key_path} ${var.datagen_ssh_username}@${module.postgres.public_dns} 'docker logs -f datagen'" : ""
}
