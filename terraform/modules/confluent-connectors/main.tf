# ===============================
# Confluent Connectors Module
# ===============================
# Creates PostgreSQL CDC Source Connector

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.32.0"
    }
  }
}

# ===============================
# Wait for PostgreSQL Ready
# ===============================
# Uses multiple methods to verify PostgreSQL is accessible:
# 1. TCP port check (fast, no SSH required)
# 2. SSH + pg_isready for full verification (if SSH key available)

resource "null_resource" "wait_for_postgres" {
  count = var.create_connector ? 1 : 0

  triggers = {
    postgres_hostname = var.postgres_hostname
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "⏳ Waiting for PostgreSQL to start..."
      echo ""

      echo "🔧 Debug info:"
      echo "   Hostname: ${var.postgres_hostname}"
      echo "   Port: ${var.postgres_port}"
      echo "   SSH Key: ${var.ssh_key_path}"
      echo "   SSH User: ${var.ssh_username}"
      echo "   Key exists: $([ -f '${var.ssh_key_path}' ] && echo 'YES' || echo 'NO')"
      echo ""

      if [ ${var.initial_wait_seconds} -gt 0 ]; then
        echo "⏳ Waiting ${var.initial_wait_seconds} seconds for instance boot..."
        sleep ${var.initial_wait_seconds}
      fi

      echo ""
      echo "🔍 Checking PostgreSQL availability (port ${var.postgres_port})..."

      max_retries=30
      count=0

      while [ $count -lt $max_retries ]; do
        # Method 1: Simple TCP port check (works without SSH)
        if nc -z -w5 ${var.postgres_hostname} ${var.postgres_port} 2>/dev/null; then
          echo ""
          echo "✅ PostgreSQL port is open! Verifying database is ready..."

          # Method 2: Try SSH + pg_isready for full verification (optional)
          if [ -f '${var.ssh_key_path}' ]; then
            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes \
              -i '${var.ssh_key_path}' \
              ${var.ssh_username}@${var.postgres_hostname} \
              "sudo docker exec postgres-workshop pg_isready -U postgres -d workshop" 2>&1; then
              echo ""
              echo "✅ PostgreSQL is fully ready (verified via pg_isready)!"
            else
              echo "   ⚠️ pg_isready check failed, but port 5432 is open."
              echo "   Proceeding - the connector will verify the connection."
            fi
          else
            echo "   ⚠️ SSH key not found, skipping pg_isready verification."
          fi

          # Port is open - PostgreSQL is accepting connections
          echo ""
          echo "✅ PostgreSQL is ready!"
          echo "   Connection: ${var.postgres_hostname}:${var.postgres_port}"
          exit 0
        fi

        count=$((count + 1))
        echo "   Attempt $count/$max_retries - PostgreSQL not ready yet, waiting 20s..."
        sleep 20
      done

      echo ""
      echo "❌ ERROR: PostgreSQL did not become ready after 10+ minutes"
      echo ""
      echo "🔧 Debugging info:"
      echo "   SSH Key path: ${var.ssh_key_path}"
      echo "   SSH Key exists: $([ -f '${var.ssh_key_path}' ] && echo 'YES' || echo 'NO')"
      ls -la '${var.ssh_key_path}' 2>&1 || echo "   Cannot list SSH key"
      echo ""
      echo "   Testing SSH connection (verbose):"
      ssh -v -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        -i '${var.ssh_key_path}' \
        ${var.ssh_username}@${var.postgres_hostname} "echo SSH works" 2>&1 | head -20
      echo ""
      echo "📋 Manual debugging steps:"
      echo "   1. From your HOST machine (not Docker), try:"
      echo "      ssh -i terraform/sshkey-*.pem ec2-user@${var.postgres_hostname}"
      echo "   2. Check if PostgreSQL container is running:"
      echo "      docker ps"
      echo "   3. Check cloud-init logs:"
      echo "      sudo tail -100 /var/log/cloud-init-output.log"
      exit 1
    EOT
  }
}

# ===============================
# PostgreSQL CDC Source V2 Connector
# ===============================
# Upgraded from deprecated PostgresCdcSource (V1) to PostgresCdcSourceV2.
# V2 includes before-state in change events by default (after.state.only=false),
# which enables proper UPDATE/DELETE processing in Flink SQL and Tableflow.

resource "confluent_connector" "postgres_cdc" {
  count = var.create_connector ? 1 : 0

  environment {
    id = var.environment_id
  }

  kafka_cluster {
    id = var.kafka_cluster_id
  }

  config_sensitive = {
    "database.password" = var.debezium_password
  }

  config_nonsensitive = {
    "name"                     = "${var.prefix}-postgres-cdc-source"
    "connector.class"          = "PostgresCdcSourceV2"
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = var.service_account_id

    # Database Connection
    "database.hostname" = var.postgres_hostname
    "database.port"     = tostring(var.postgres_port)
    "database.user"     = var.debezium_username
    "database.dbname"   = var.database_name
    "database.sslmode"  = "disable"

    # Table Selection
    "table.include.list" = var.table_include_list

    # Logical Replication
    "plugin.name"                 = "pgoutput"
    "publication.name"            = "dbz_publication_${replace(var.prefix, "-", "_")}"
    "publication.autocreate.mode" = "filtered"
    "slot.name"                   = "debezium_slot_${replace(var.prefix, "-", "_")}"
    "slot.drop.on.stop"           = "false"

    # Snapshot Configuration
    "snapshot.mode"           = "initial"
    "snapshot.isolation.mode" = "READ_COMMITTED"

    # Output Configuration
    "tasks.max"           = "1"
    "output.data.format"  = "AVRO"
    "schema.context.name" = "default"

    # Topic Configuration
    "topic.prefix"                              = "riverhotel"
    "topic.heartbeat.prefix"                    = "__debezium-heartbeat"
    "topic.creation.default.replication.factor" = "3"
    "topic.creation.default.partitions"         = "6"
    "topic.creation.default.cleanup.policy"     = "delete"
    "topic.creation.default.retention.ms"       = "604800000"
    "topic.creation.enable"                     = "true"

    # Change Event Configuration
    "decimal.handling.mode"   = "double"
    "time.precision.mode"     = "connect"
    "include.schema.changes"  = "false"
    "include.schema.comments" = "true"
    "tombstones.on.delete"    = "true"

    # Heartbeat
    "heartbeat.interval.ms" = "60000"

    # Performance
    "max.batch.size"   = "2048"
    "poll.interval.ms" = "5000"
    "max.queue.size"   = "8192"

    # Error Handling
    "errors.tolerance"            = "none"
    "errors.log.enable"           = "true"
    "errors.log.include.messages" = "true"

    # Advanced
    "unavailable.value.placeholder" = "__debezium_unavailable_value"
    "skip.messages.without.change"  = "false"
    "skipped.operations"            = "t"
    "status.update.interval.ms"     = "10000"
    "provide.transaction.metadata"  = "false"
  }

  depends_on = [null_resource.wait_for_postgres]

  lifecycle {
    prevent_destroy = false
  }
}
