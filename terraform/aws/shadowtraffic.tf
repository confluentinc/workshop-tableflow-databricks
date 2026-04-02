# ===============================
# ShadowTraffic Data Generator
# ===============================
# Runs ShadowTraffic as a Docker container on the PostgreSQL EC2 instance.
# Unlike the instructor-led (aws-shared) variant that writes only to PostgreSQL,
# self-service ShadowTraffic writes to BOTH PostgreSQL (customer, hotel via CDC)
# and Kafka directly (clickstream, bookings, hotel_reviews with Avro schemas).

variable "enable_shadowtraffic" {
  description = "Whether to run ShadowTraffic on the PostgreSQL instance"
  type        = bool
  default     = true
}

variable "shadowtraffic_image" {
  description = "ShadowTraffic Docker image"
  type        = string
  default     = "public.ecr.aws/s2b8p3j6/shadowtraffic/shadowtraffic:latest"
}

variable "shadowtraffic_ssh_username" {
  description = "SSH username for the PostgreSQL EC2 instance"
  type        = string
  default     = "ec2-user"
}

locals {
  # Only deploy ShadowTraffic in self-service mode (not WSA shared mode)
  deploy_shadowtraffic = var.enable_shadowtraffic && !local.use_shared
  data_dir             = "${path.module}/../../data"
}

# ===============================
# ShadowTraffic License
# ===============================

data "http" "shadowtraffic_license" {
  count = local.deploy_shadowtraffic ? 1 : 0
  url   = "https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license-docker.env"
}

# ===============================
# PostgreSQL Connection Config
# ===============================
# ShadowTraffic connects to PostgreSQL on localhost (co-located on same EC2).

resource "local_file" "shadowtraffic_postgres_connection" {
  count = local.deploy_shadowtraffic ? 1 : 0

  content = jsonencode({
    kind        = "postgres"
    tablePolicy = "create"
    connectionConfigs = {
      host     = "localhost"
      port     = 5432
      username = var.postgres_db_username
      password = local.effective_postgres_db_password
      db       = var.postgres_db_name
    }
  })

  filename        = "${path.module}/generated/connections/postgres.json"
  file_permission = "0600"
}

# ===============================
# Confluent Cloud Connection Config
# ===============================
# ShadowTraffic writes clickstream, bookings, and hotel_reviews
# directly to Kafka with Avro serialization.

resource "local_file" "shadowtraffic_confluent_connection" {
  count = local.deploy_shadowtraffic ? 1 : 0

  content = jsonencode({
    kind     = "kafka"
    logLevel = "ERROR"
    producerConfigs = {
      "bootstrap.servers"              = module.confluent_platform.bootstrap_endpoint_url
      "schema.registry.url"            = module.confluent_platform.schema_registry_endpoint
      "basic.auth.user.info"           = "${module.confluent_platform.schema_registry_api_key}:${module.confluent_platform.schema_registry_api_secret}"
      "basic.auth.credentials.source"  = "USER_INFO"
      "key.serializer"                 = "io.shadowtraffic.kafka.serdes.JsonSerializer"
      "value.serializer"               = "io.confluent.kafka.serializers.KafkaAvroSerializer"
      "sasl.jaas.config"               = "org.apache.kafka.common.security.plain.PlainLoginModule required username='${module.confluent_platform.kafka_api_key}' password='${module.confluent_platform.kafka_api_secret}';"
      "sasl.mechanism"                 = "PLAIN"
      "security.protocol"              = "SASL_SSL"
    }
  })

  filename        = "${path.module}/generated/connections/confluent.json"
  file_permission = "0600"
}

# ===============================
# ShadowTraffic License File
# ===============================

resource "local_file" "shadowtraffic_license" {
  count = local.deploy_shadowtraffic ? 1 : 0

  content  = data.http.shadowtraffic_license[0].response_body
  filename = "${path.module}/generated/shadow-traffic-license.env"
}

# ===============================
# ShadowTraffic Setup via SSH
# ===============================
# Copies all generator configs, schemas, content files, and connection
# configs to the EC2 instance, then starts ShadowTraffic as a Docker container.

resource "null_resource" "shadowtraffic_setup" {
  count = local.deploy_shadowtraffic ? 1 : 0

  triggers = {
    instance_id    = module.postgres[0].instance_id
    pg_config_hash = md5(local_file.shadowtraffic_postgres_connection[0].content)
    cc_config_hash = md5(local_file.shadowtraffic_confluent_connection[0].content)
    license_hash   = md5(local_file.shadowtraffic_license[0].content)
  }

  depends_on = [
    module.postgres,
    module.keypair,
    module.confluent_platform,
    local_file.shadowtraffic_postgres_connection,
    local_file.shadowtraffic_confluent_connection,
    local_file.shadowtraffic_license,
  ]

  connection {
    type        = "ssh"
    host        = module.postgres[0].public_dns
    user        = var.shadowtraffic_ssh_username
    private_key = file(module.keypair[0].private_key_path)
    timeout     = "10m"
  }

  # ---- Create directory structure ----
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/shadowtraffic/data/generators-shared/content",
      "sudo mkdir -p /opt/shadowtraffic/data/generators-self-service",
      "sudo mkdir -p /opt/shadowtraffic/data/connections",
      "sudo mkdir -p /opt/shadowtraffic/data/schemas",
      "sudo chmod -R 777 /opt/shadowtraffic",
    ]
  }

  # ---- Connection configs ----
  provisioner "file" {
    source      = local_file.shadowtraffic_postgres_connection[0].filename
    destination = "/opt/shadowtraffic/data/connections/postgres.json"
  }
  provisioner "file" {
    source      = local_file.shadowtraffic_confluent_connection[0].filename
    destination = "/opt/shadowtraffic/data/connections/confluent.json"
  }

  # ---- ShadowTraffic license ----
  provisioner "file" {
    source      = local_file.shadowtraffic_license[0].filename
    destination = "/opt/shadowtraffic/shadow-traffic-license.env"
  }

  # ---- Main ShadowTraffic config ----
  provisioner "file" {
    source      = "${local.data_dir}/shadow-traffic-configuration.json"
    destination = "/opt/shadowtraffic/data/shadow-traffic-configuration.json"
  }

  # ---- Shared generators ----
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/customer_generator_historical.json"
    destination = "/opt/shadowtraffic/data/generators-shared/customer_generator_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/customer_generator_streaming.json"
    destination = "/opt/shadowtraffic/data/generators-shared/customer_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/hotel_generator_historical.json"
    destination = "/opt/shadowtraffic/data/generators-shared/hotel_generator_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/hotel_generator_streaming.json"
    destination = "/opt/shadowtraffic/data/generators-shared/hotel_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/customer_updates_historical.json"
    destination = "/opt/shadowtraffic/data/generators-shared/customer_updates_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/hotel_updates_historical.json"
    destination = "/opt/shadowtraffic/data/generators-shared/hotel_updates_historical.json"
  }

  # ---- Self-service generators (clickstream, bookings, reviews → Kafka) ----
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/clickstream_generator_historical.json"
    destination = "/opt/shadowtraffic/data/generators-self-service/clickstream_generator_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/clickstream_generator_streaming.json"
    destination = "/opt/shadowtraffic/data/generators-self-service/clickstream_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/booking_generator_historical.json"
    destination = "/opt/shadowtraffic/data/generators-self-service/booking_generator_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/booking_generator_streaming.json"
    destination = "/opt/shadowtraffic/data/generators-self-service/booking_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/review_generator_historical.json"
    destination = "/opt/shadowtraffic/data/generators-self-service/review_generator_historical.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-self-service/review_generator_streaming.json"
    destination = "/opt/shadowtraffic/data/generators-self-service/review_generator_streaming.json"
  }

  # ---- Content files (hotel descriptions, review texts) ----
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/hotel_descriptions_airport.json"
    destination = "/opt/shadowtraffic/data/generators-shared/content/hotel_descriptions_airport.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/hotel_descriptions_economy.json"
    destination = "/opt/shadowtraffic/data/generators-shared/content/hotel_descriptions_economy.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/hotel_descriptions_extended_stay.json"
    destination = "/opt/shadowtraffic/data/generators-shared/content/hotel_descriptions_extended_stay.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/hotel_descriptions_luxury.json"
    destination = "/opt/shadowtraffic/data/generators-shared/content/hotel_descriptions_luxury.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/hotel_descriptions_resort.json"
    destination = "/opt/shadowtraffic/data/generators-shared/content/hotel_descriptions_resort.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/review_text_choices_1_star.json"
    destination = "/opt/shadowtraffic/data/generators-shared/content/review_text_choices_1_star.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/review_text_choices_2_star.json"
    destination = "/opt/shadowtraffic/data/generators-shared/content/review_text_choices_2_star.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/review_text_choices_3_star.json"
    destination = "/opt/shadowtraffic/data/generators-shared/content/review_text_choices_3_star.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/review_text_choices_4_star.json"
    destination = "/opt/shadowtraffic/data/generators-shared/content/review_text_choices_4_star.json"
  }
  provisioner "file" {
    source      = "${local.data_dir}/generators-shared/content/review_text_choices_5_star.json"
    destination = "/opt/shadowtraffic/data/generators-shared/content/review_text_choices_5_star.json"
  }

  # ---- Avro schemas (required for Kafka Avro serialization) ----
  provisioner "file" {
    source      = "${local.data_dir}/schemas/clickstream_schema.avsc"
    destination = "/opt/shadowtraffic/data/schemas/clickstream_schema.avsc"
  }
  provisioner "file" {
    source      = "${local.data_dir}/schemas/booking_schema.avsc"
    destination = "/opt/shadowtraffic/data/schemas/booking_schema.avsc"
  }
  provisioner "file" {
    source      = "${local.data_dir}/schemas/review_schema.avsc"
    destination = "/opt/shadowtraffic/data/schemas/review_schema.avsc"
  }

  # ---- Wait for PostgreSQL, then start ShadowTraffic ----
  provisioner "remote-exec" {
    inline = [
      <<-SCRIPT
      set -e
      echo '================================================'
      echo 'ShadowTraffic Setup (Self-Service)'
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

      sudo docker stop shadowtraffic 2>/dev/null || true
      sudo docker rm shadowtraffic 2>/dev/null || true

      echo ''
      echo 'Pulling ShadowTraffic image...'
      sudo docker pull ${var.shadowtraffic_image}

      echo ''
      echo 'Starting ShadowTraffic...'
      sudo docker run -d --name shadowtraffic \
        --network host \
        --restart on-failure:3 \
        --health-cmd "curl -sf http://localhost:9400 || exit 1" \
        --health-interval 30s \
        --health-retries 3 \
        --health-start-period 60s \
        --env-file /opt/shadowtraffic/shadow-traffic-license.env \
        -v /opt/shadowtraffic/data:/home/data \
        ${var.shadowtraffic_image} \
        --config /home/data/shadow-traffic-configuration.json

      echo ''
      echo 'Waiting for ShadowTraffic to initialize (30s)...'
      sleep 30

      echo ''
      echo 'ShadowTraffic container status:'
      sudo docker ps --filter name=shadowtraffic --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

      if ! sudo docker ps --filter name=shadowtraffic --format '{{.Names}}' | grep -q shadowtraffic; then
        echo ''
        echo 'ERROR: ShadowTraffic container is not running!'
        echo 'Container logs:'
        sudo docker logs shadowtraffic 2>&1
        exit 1
      fi

      echo ''
      echo 'ShadowTraffic logs (last 30 lines):'
      sudo docker logs shadowtraffic 2>&1 | tail -30

      echo ''
      echo 'Checking PostgreSQL tables for data...'
      sudo docker exec postgres-workshop psql -U postgres -d ${var.postgres_db_name} -c "
        SELECT 'cdc.customer' as table_name, count(*) FROM cdc.customer
        UNION ALL SELECT 'cdc.hotel', count(*) FROM cdc.hotel;"

      echo ''
      echo '================================================'
      echo 'ShadowTraffic setup complete!'
      echo '================================================'
      SCRIPT
    ]
  }
}

# ===============================
# ShadowTraffic Outputs
# ===============================

output "shadowtraffic_enabled" {
  description = "Whether ShadowTraffic is running on the EC2 instance"
  value       = local.deploy_shadowtraffic
}

output "shadowtraffic_ssh_command" {
  description = "SSH command to check ShadowTraffic logs"
  value       = local.deploy_shadowtraffic ? "ssh -i ${module.keypair[0].private_key_path} ${var.shadowtraffic_ssh_username}@${module.postgres[0].public_dns} 'docker logs -f shadowtraffic'" : ""
}
