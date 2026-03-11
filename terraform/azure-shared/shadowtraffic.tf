# ===============================
# ShadowTraffic Data Generator
# ===============================
# Runs ShadowTraffic as a Docker container on the PostgreSQL Azure VM.
# All generators write to PostgreSQL tables in the cdc schema.
# Per-account CDC connectors handle the Kafka fan-out.

variable "enable_shadowtraffic" {
  description = "Whether to run ShadowTraffic on the PostgreSQL VM"
  type        = bool
  default     = true
}

variable "shadowtraffic_image" {
  description = "ShadowTraffic Docker image"
  type        = string
  default     = "public.ecr.aws/s2b8p3j6/shadowtraffic/shadowtraffic:latest"
}

# ===============================
# ShadowTraffic License
# ===============================

data "http" "shadowtraffic_license" {
  count = var.enable_shadowtraffic ? 1 : 0
  url   = "https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license-docker.env"
}

# ===============================
# PostgreSQL Connection Config
# ===============================

resource "local_file" "shadowtraffic_postgres_connection" {
  count = var.enable_shadowtraffic ? 1 : 0

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
# ShadowTraffic License File
# ===============================

resource "local_file" "shadowtraffic_license" {
  count = var.enable_shadowtraffic ? 1 : 0

  content  = data.http.shadowtraffic_license[0].response_body
  filename = "${path.module}/generated/shadow-traffic-license.env"
}

# ===============================
# ShadowTraffic Setup via SSH
# ===============================

resource "null_resource" "shadowtraffic_setup" {
  count = var.enable_shadowtraffic ? 1 : 0

  triggers = {
    vm_id        = azurerm_linux_virtual_machine.postgres.id
    config_hash  = md5(local_file.shadowtraffic_postgres_connection[0].content)
    license_hash = md5(local_file.shadowtraffic_license[0].content)
  }

  depends_on = [
    azurerm_linux_virtual_machine.postgres,
    local_file.shadowtraffic_postgres_connection,
    local_file.shadowtraffic_license,
  ]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.postgres.ip_address
    user        = var.vm_admin_username
    private_key = tls_private_key.shared.private_key_pem
    timeout     = "10m"
  }

  # Create directory structure on the VM
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/shadowtraffic/data/generators",
      "sudo mkdir -p /opt/shadowtraffic/data/generators-workshop",
      "sudo mkdir -p /opt/shadowtraffic/data/generators/content",
      "sudo mkdir -p /opt/shadowtraffic/data/connections",
      "sudo mkdir -p /opt/shadowtraffic/data/schemas",
      "sudo chmod -R 777 /opt/shadowtraffic",
    ]
  }

  # --- Connection config (generated with localhost + credentials) ---
  provisioner "file" {
    source      = local_file.shadowtraffic_postgres_connection[0].filename
    destination = "/opt/shadowtraffic/data/connections/postgres.json"
  }

  # --- ShadowTraffic license ---
  provisioner "file" {
    source      = local_file.shadowtraffic_license[0].filename
    destination = "/opt/shadowtraffic/shadow-traffic-license.env"
  }

  # --- Workshop ShadowTraffic config ---
  provisioner "file" {
    source      = "${var.data_dir}/shadow-traffic-configuration-workshop.json"
    destination = "/opt/shadowtraffic/data/shadow-traffic-configuration-workshop.json"
  }

  # --- Original PostgreSQL generators (customer, hotel) ---
  provisioner "file" {
    source      = "${var.data_dir}/generators/customer_generator_historical.json"
    destination = "/opt/shadowtraffic/data/generators/customer_generator_historical.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators/customer_generator_streaming.json"
    destination = "/opt/shadowtraffic/data/generators/customer_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators/hotel_generator_historical.json"
    destination = "/opt/shadowtraffic/data/generators/hotel_generator_historical.json"
  }

  # --- Workshop generators (bookings, clickstream, reviews → PostgreSQL) ---
  provisioner "file" {
    source      = "${var.data_dir}/generators-workshop/booking_generator_historical.json"
    destination = "/opt/shadowtraffic/data/generators-workshop/booking_generator_historical.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-workshop/booking_generator_streaming.json"
    destination = "/opt/shadowtraffic/data/generators-workshop/booking_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-workshop/clickstream_generator_historical.json"
    destination = "/opt/shadowtraffic/data/generators-workshop/clickstream_generator_historical.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-workshop/clickstream_generator_streaming.json"
    destination = "/opt/shadowtraffic/data/generators-workshop/clickstream_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-workshop/review_generator_historical.json"
    destination = "/opt/shadowtraffic/data/generators-workshop/review_generator_historical.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-workshop/review_generator_streaming.json"
    destination = "/opt/shadowtraffic/data/generators-workshop/review_generator_streaming.json"
  }

  # --- Content files (hotel descriptions, review texts) ---
  provisioner "file" {
    source      = "${var.data_dir}/generators/content/hotel_descriptions_airport.json"
    destination = "/opt/shadowtraffic/data/generators/content/hotel_descriptions_airport.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators/content/hotel_descriptions_economy.json"
    destination = "/opt/shadowtraffic/data/generators/content/hotel_descriptions_economy.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators/content/hotel_descriptions_extended_stay.json"
    destination = "/opt/shadowtraffic/data/generators/content/hotel_descriptions_extended_stay.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators/content/hotel_descriptions_luxury.json"
    destination = "/opt/shadowtraffic/data/generators/content/hotel_descriptions_luxury.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators/content/hotel_descriptions_resort.json"
    destination = "/opt/shadowtraffic/data/generators/content/hotel_descriptions_resort.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators/content/review_text_choices_1_star.json"
    destination = "/opt/shadowtraffic/data/generators/content/review_text_choices_1_star.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators/content/review_text_choices_2_star.json"
    destination = "/opt/shadowtraffic/data/generators/content/review_text_choices_2_star.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators/content/review_text_choices_3_star.json"
    destination = "/opt/shadowtraffic/data/generators/content/review_text_choices_3_star.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators/content/review_text_choices_4_star.json"
    destination = "/opt/shadowtraffic/data/generators/content/review_text_choices_4_star.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators/content/review_text_choices_5_star.json"
    destination = "/opt/shadowtraffic/data/generators/content/review_text_choices_5_star.json"
  }

  # --- Wait for PostgreSQL, then start ShadowTraffic ---
  provisioner "remote-exec" {
    inline = [
      <<-SCRIPT
      set -e
      echo '================================================'
      echo 'ShadowTraffic Setup'
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

      echo ''
      echo 'Verifying CDC tables...'
      sudo docker exec postgres-workshop psql -U postgres -d ${var.postgres_db_name} -c '\dt cdc.*'

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
        --config /home/data/shadow-traffic-configuration-workshop.json

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
        UNION ALL SELECT 'cdc.hotel', count(*) FROM cdc.hotel
        UNION ALL SELECT 'cdc.bookings', count(*) FROM cdc.bookings
        UNION ALL SELECT 'cdc.clickstream', count(*) FROM cdc.clickstream
        UNION ALL SELECT 'cdc.hotel_reviews', count(*) FROM cdc.hotel_reviews;"

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
  description = "Whether ShadowTraffic is running"
  value       = var.enable_shadowtraffic
}

output "shadowtraffic_image" {
  description = "ShadowTraffic Docker image used"
  value       = var.enable_shadowtraffic ? var.shadowtraffic_image : ""
}

output "shadowtraffic_ssh_command" {
  description = "SSH command to check ShadowTraffic logs"
  value       = var.enable_shadowtraffic ? "ssh -i ${local_file.ssh_private_key.filename} ${var.vm_admin_username}@${azurerm_public_ip.postgres.ip_address} 'docker logs -f shadowtraffic'" : ""
}
