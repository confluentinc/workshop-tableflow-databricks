# ===============================
# Workshop Data Generator
# ===============================
# Runs the workshop data generator as a Docker container on the PostgreSQL Azure VM.
# All generators write to PostgreSQL tables in the cdc schema.
# Per-account CDC connectors handle the Kafka fan-out.

variable "enable_datagen" {
  description = "Whether to run the workshop data generator on the PostgreSQL VM"
  type        = bool
  default     = true
}

variable "datagen_image" {
  description = "Workshop data generator Docker image"
  type        = string
  default     = "public.ecr.aws/v3a9u0p7/workshop-datagen:latest"
}

# ===============================
# PostgreSQL Connection Config
# ===============================

resource "local_file" "datagen_postgres_connection" {
  count = var.enable_datagen ? 1 : 0

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
# Data Generator Setup via SSH
# ===============================

resource "null_resource" "datagen_setup" {
  count = var.enable_datagen ? 1 : 0

  triggers = {
    vm_id       = azurerm_linux_virtual_machine.postgres.id
    config_hash = md5(local_file.datagen_postgres_connection[0].content)
  }

  depends_on = [
    azurerm_linux_virtual_machine.postgres,
    local_file.datagen_postgres_connection,
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
      "sudo mkdir -p /opt/datagen/data/generators-shared/content",
      "sudo mkdir -p /opt/datagen/data/generators-instructor-led",
      "sudo mkdir -p /opt/datagen/data/connections",
      "sudo mkdir -p /opt/datagen/data/schemas",
      "sudo chmod -R 777 /opt/datagen",
    ]
  }

  # --- Connection config (generated with localhost + credentials) ---
  provisioner "file" {
    source      = local_file.datagen_postgres_connection[0].filename
    destination = "/opt/datagen/data/connections/postgres.json"
  }

  # --- Workshop data generator config ---
  provisioner "file" {
    source      = "${var.data_dir}/java-datagen-configuration-workshop.json"
    destination = "/opt/datagen/data/java-datagen-configuration-workshop.json"
  }

  # --- Shared generators (used by both paths) ---
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/customer_generator_historical.json"
    destination = "/opt/datagen/data/generators-shared/customer_generator_historical.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/customer_generator_streaming.json"
    destination = "/opt/datagen/data/generators-shared/customer_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/hotel_generator_historical.json"
    destination = "/opt/datagen/data/generators-shared/hotel_generator_historical.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/hotel_generator_streaming.json"
    destination = "/opt/datagen/data/generators-shared/hotel_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/customer_updates_historical.json"
    destination = "/opt/datagen/data/generators-shared/customer_updates_historical.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/hotel_updates_historical.json"
    destination = "/opt/datagen/data/generators-shared/hotel_updates_historical.json"
  }
  # --- Instructor-led generators (bookings, clickstream, reviews → PostgreSQL) ---
  provisioner "file" {
    source      = "${var.data_dir}/generators-instructor-led/booking_generator_historical.json"
    destination = "/opt/datagen/data/generators-instructor-led/booking_generator_historical.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-instructor-led/booking_generator_streaming.json"
    destination = "/opt/datagen/data/generators-instructor-led/booking_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-instructor-led/clickstream_generator_historical.json"
    destination = "/opt/datagen/data/generators-instructor-led/clickstream_generator_historical.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-instructor-led/clickstream_generator_streaming.json"
    destination = "/opt/datagen/data/generators-instructor-led/clickstream_generator_streaming.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-instructor-led/review_generator_historical.json"
    destination = "/opt/datagen/data/generators-instructor-led/review_generator_historical.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-instructor-led/review_generator_streaming.json"
    destination = "/opt/datagen/data/generators-instructor-led/review_generator_streaming.json"
  }

  # --- Content files (hotel descriptions, review texts) ---
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/content/hotel_descriptions_airport.json"
    destination = "/opt/datagen/data/generators-shared/content/hotel_descriptions_airport.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/content/hotel_descriptions_economy.json"
    destination = "/opt/datagen/data/generators-shared/content/hotel_descriptions_economy.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/content/hotel_descriptions_extended_stay.json"
    destination = "/opt/datagen/data/generators-shared/content/hotel_descriptions_extended_stay.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/content/hotel_descriptions_luxury.json"
    destination = "/opt/datagen/data/generators-shared/content/hotel_descriptions_luxury.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/content/hotel_descriptions_resort.json"
    destination = "/opt/datagen/data/generators-shared/content/hotel_descriptions_resort.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/content/review_text_choices_1_star.json"
    destination = "/opt/datagen/data/generators-shared/content/review_text_choices_1_star.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/content/review_text_choices_2_star.json"
    destination = "/opt/datagen/data/generators-shared/content/review_text_choices_2_star.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/content/review_text_choices_3_star.json"
    destination = "/opt/datagen/data/generators-shared/content/review_text_choices_3_star.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/content/review_text_choices_4_star.json"
    destination = "/opt/datagen/data/generators-shared/content/review_text_choices_4_star.json"
  }
  provisioner "file" {
    source      = "${var.data_dir}/generators-shared/content/review_text_choices_5_star.json"
    destination = "/opt/datagen/data/generators-shared/content/review_text_choices_5_star.json"
  }

  # --- Wait for PostgreSQL, then start data generator ---
  provisioner "remote-exec" {
    inline = [
      <<-SCRIPT
      set -e
      echo '================================================'
      echo 'Data Generator Setup'
      echo '================================================'

      echo 'Waiting for PostgreSQL to be healthy...'
      MAX_RETRIES=60
      COUNT=0
      while [ $COUNT -lt $MAX_RETRIES ]; do
        if sudo docker exec postgres-workshop pg_isready -U ${var.postgres_db_username} -d ${var.postgres_db_name} 2>/dev/null; then
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
      sudo docker exec postgres-workshop psql -U ${var.postgres_db_username} -d ${var.postgres_db_name} -c '\dt cdc.*'

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
        --config /home/data/java-datagen-configuration-workshop.json

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
      sudo docker exec postgres-workshop psql -U ${var.postgres_db_username} -d ${var.postgres_db_name} -c "
        SELECT 'cdc.customer' as table_name, count(*) FROM cdc.customer
        UNION ALL SELECT 'cdc.hotel', count(*) FROM cdc.hotel
        UNION ALL SELECT 'cdc.bookings', count(*) FROM cdc.bookings
        UNION ALL SELECT 'cdc.clickstream', count(*) FROM cdc.clickstream
        UNION ALL SELECT 'cdc.reviews', count(*) FROM cdc.reviews;"

      echo ''
      echo '================================================'
      echo 'Data Generator setup complete!'
      echo '================================================'
      SCRIPT
    ]
  }
}

# ===============================
# Data Generator Outputs
# ===============================

output "datagen_enabled" {
  description = "Whether the workshop data generator is running"
  value       = var.enable_datagen
}

output "datagen_image" {
  description = "Workshop data generator Docker image used"
  value       = var.enable_datagen ? var.datagen_image : ""
}

output "datagen_ssh_command" {
  description = "SSH command to check Data Generator logs"
  value       = var.enable_datagen ? "ssh -i ${local_file.ssh_private_key.filename} ${var.vm_admin_username}@${azurerm_public_ip.postgres.ip_address} 'docker logs -f datagen'" : ""
}
