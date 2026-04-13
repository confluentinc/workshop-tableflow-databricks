#!/bin/bash
# Custom metrics collection for WSA shared infrastructure (Azure).
# Pushes PostgreSQL stats, Docker container health, disk usage, and
# data generator Prometheus metrics to Azure Monitor every 60 seconds via cron.
#
# Authenticates using the VM's system-assigned managed identity (IMDS).

REGION="${region}"
RESOURCE_URI="${resource_uri}"
NAMESPACE="WSA/SharedInfra"
DB_NAME="${db_name}"
DB_USERNAME="${db_username}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Acquire an access token for Azure Monitor via IMDS
TOKEN_RESPONSE=$(curl -sf -H "Metadata:true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://monitoring.azure.com/" 2>/dev/null)

if [ -z "$TOKEN_RESPONSE" ]; then
  echo "[$TIMESTAMP] ERROR: failed to acquire IMDS token"
  exit 1
fi

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "[$TIMESTAMP] ERROR: failed to parse access token"
  exit 1
fi

ENDPOINT="https://$REGION.monitoring.azure.com$RESOURCE_URI/metrics"

# Helper: push a single metric value to Azure Monitor custom metrics API
push_metric() {
  local metric_name="$1"
  local value="$2"

  curl -sf -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "{
      \"time\": \"$TIMESTAMP\",
      \"data\": {
        \"baseData\": {
          \"metric\": \"$metric_name\",
          \"namespace\": \"$NAMESPACE\",
          \"dimValues\": [],
          \"series\": [{
            \"dimValues\": [],
            \"min\": $value,
            \"max\": $value,
            \"sum\": $value,
            \"count\": 1
          }]
        }
      }
    }" 2>/dev/null
}

# --- Memory usage ---

MEM_TOTAL=$(free | awk '/^Mem:/ {print $2}')
MEM_AVAILABLE=$(free | awk '/^Mem:/ {print $7}')
MEM_USED_PCT=$(( (MEM_TOTAL - MEM_AVAILABLE) * 100 / MEM_TOTAL ))
push_metric "MemoryUsedPercent" "$${MEM_USED_PCT:-0}"

# --- Disk usage ---

DISK_USED_PCT=$(df / --output=pcent | tail -1 | tr -d ' %')
push_metric "DiskUsedPercent" "$${DISK_USED_PCT:-0}"

# --- PostgreSQL metrics ---

PG_CONTAINER="postgres-workshop"
CONNECTIONS="0"
SLOT_COUNT="0"
MAX_LAG="0"
PG_VALUE=0

if sudo docker ps --filter name=$PG_CONTAINER --format '{{.Names}}' | grep -q $PG_CONTAINER; then
  CONNECTIONS=$(sudo docker exec $PG_CONTAINER psql -U "$DB_USERNAME" -d "$DB_NAME" -t -A -c \
    "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null || echo "0")
  CONNECTIONS=$(echo "$CONNECTIONS" | tr -d '[:space:]')
  push_metric "ActiveConnections" "$${CONNECTIONS:-0}"

  SLOT_COUNT=$(sudo docker exec $PG_CONTAINER psql -U "$DB_USERNAME" -d "$DB_NAME" -t -A -c \
    "SELECT count(*) FROM pg_replication_slots;" 2>/dev/null || echo "0")
  SLOT_COUNT=$(echo "$SLOT_COUNT" | tr -d '[:space:]')
  push_metric "ReplicationSlotCount" "$${SLOT_COUNT:-0}"

  MAX_LAG=$(sudo docker exec $PG_CONTAINER psql -U "$DB_USERNAME" -d "$DB_NAME" -t -A -c \
    "SELECT COALESCE(MAX(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)), 0)
     FROM pg_replication_slots
     WHERE active = true;" 2>/dev/null || echo "0")
  MAX_LAG=$(echo "$MAX_LAG" | tr -d '[:space:]')
  push_metric "ReplicationLagBytes" "$${MAX_LAG:-0}"
fi

# --- Docker container health ---

PG_RUNNING=$(sudo docker inspect --format '{{.State.Running}}' $PG_CONTAINER 2>/dev/null || echo "false")
if [ "$PG_RUNNING" = "true" ]; then
  PG_VALUE=1
fi
push_metric "ContainerRunning_postgres" "$PG_VALUE"

ST_CONTAINER="datagen"
ST_HEALTH=$(sudo docker inspect --format '{{.State.Health.Status}}' $ST_CONTAINER 2>/dev/null || echo "none")
ST_VALUE=0
if [ "$ST_HEALTH" = "healthy" ]; then
  ST_VALUE=1
elif [ "$ST_HEALTH" = "none" ]; then
  ST_RUNNING=$(sudo docker inspect --format '{{.State.Running}}' $ST_CONTAINER 2>/dev/null || echo "false")
  if [ "$ST_RUNNING" = "true" ]; then
    ST_VALUE=1
  fi
fi
push_metric "ContainerHealthy_datagen" "$ST_VALUE"

# --- Data generator Prometheus metrics ---

WRITE_ERRORS="0"
EVENTS_TOTAL="0"
PROM_RESPONSE=$(curl -sf http://localhost:9400 2>/dev/null || echo "")

if [ -n "$PROM_RESPONSE" ]; then
  WRITE_ERRORS=$(echo "$PROM_RESPONSE" | grep '^datagen_events_failed_total' | awk '{sum += $2} END {print sum+0}')
  push_metric "DatagenWriteErrors" "$${WRITE_ERRORS:-0}"

  EVENTS_TOTAL=$(echo "$PROM_RESPONSE" | grep '^datagen_events_sent_total' | awk '{sum += $2} END {print sum+0}')
  push_metric "DatagenEventsTotal" "$${EVENTS_TOTAL:-0}"
fi

echo "[$TIMESTAMP] Metrics pushed: mem=$MEM_USED_PCT% disk=$DISK_USED_PCT% connections=$CONNECTIONS slots=$SLOT_COUNT lag=$MAX_LAG pg=$PG_VALUE st=$ST_VALUE errors=$WRITE_ERRORS events=$EVENTS_TOTAL"
