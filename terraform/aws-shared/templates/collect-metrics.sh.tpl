#!/bin/bash
# Custom metrics collection for WSA shared infrastructure.
# Pushes PostgreSQL stats, Docker container health, and data generator
# Prometheus metrics to CloudWatch every 60 seconds via cron.

REGION="${region}"
NAMESPACE="${namespace}"
INSTANCE_ID="${instance_id}"
DB_NAME="${db_name}"
DB_USERNAME="${db_username}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# --- PostgreSQL metrics ---

PG_CONTAINER="postgres-workshop"

if sudo docker ps --filter name=$PG_CONTAINER --format '{{.Names}}' | grep -q $PG_CONTAINER; then
  # Active connections
  CONNECTIONS=$(sudo docker exec $PG_CONTAINER psql -U "$DB_USERNAME" -d "$DB_NAME" -t -A -c \
    "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null || echo "0")
  CONNECTIONS=$(echo "$CONNECTIONS" | tr -d '[:space:]')

  aws cloudwatch put-metric-data \
    --region "$REGION" \
    --namespace "$NAMESPACE" \
    --metric-name "ActiveConnections" \
    --dimensions "InstanceId=$INSTANCE_ID" \
    --value "$CONNECTIONS" \
    --unit "Count" \
    --timestamp "$TIMESTAMP" 2>/dev/null

  # Replication slot count
  SLOT_COUNT=$(sudo docker exec $PG_CONTAINER psql -U "$DB_USERNAME" -d "$DB_NAME" -t -A -c \
    "SELECT count(*) FROM pg_replication_slots;" 2>/dev/null || echo "0")
  SLOT_COUNT=$(echo "$SLOT_COUNT" | tr -d '[:space:]')

  aws cloudwatch put-metric-data \
    --region "$REGION" \
    --namespace "$NAMESPACE" \
    --metric-name "ReplicationSlotCount" \
    --dimensions "InstanceId=$INSTANCE_ID" \
    --value "$SLOT_COUNT" \
    --unit "Count" \
    --timestamp "$TIMESTAMP" 2>/dev/null

  # Max replication lag (bytes behind across all slots)
  MAX_LAG=$(sudo docker exec $PG_CONTAINER psql -U "$DB_USERNAME" -d "$DB_NAME" -t -A -c \
    "SELECT COALESCE(MAX(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)), 0)
     FROM pg_replication_slots
     WHERE active = true;" 2>/dev/null || echo "0")
  MAX_LAG=$(echo "$MAX_LAG" | tr -d '[:space:]')

  aws cloudwatch put-metric-data \
    --region "$REGION" \
    --namespace "$NAMESPACE" \
    --metric-name "ReplicationLagBytes" \
    --dimensions "InstanceId=$INSTANCE_ID" \
    --value "$MAX_LAG" \
    --unit "Bytes" \
    --timestamp "$TIMESTAMP" 2>/dev/null
fi

# --- Docker container health ---

# PostgreSQL container (no Docker health check, just check if running)
PG_RUNNING=$(sudo docker inspect --format '{{.State.Running}}' $PG_CONTAINER 2>/dev/null || echo "false")
PG_VALUE=0
if [ "$PG_RUNNING" = "true" ]; then
  PG_VALUE=1
fi

aws cloudwatch put-metric-data \
  --region "$REGION" \
  --namespace "$NAMESPACE" \
  --metric-name "ContainerRunning_postgres" \
  --dimensions "InstanceId=$INSTANCE_ID" \
  --value "$PG_VALUE" \
  --unit "None" \
  --timestamp "$TIMESTAMP" 2>/dev/null

# Data generator container (has Docker health check via Prometheus endpoint)
ST_CONTAINER="datagen"
ST_HEALTH=$(sudo docker inspect --format '{{.State.Health.Status}}' $ST_CONTAINER 2>/dev/null || echo "none")
ST_VALUE=0
if [ "$ST_HEALTH" = "healthy" ]; then
  ST_VALUE=1
elif [ "$ST_HEALTH" = "none" ]; then
  # No health check configured; fall back to checking if running
  ST_RUNNING=$(sudo docker inspect --format '{{.State.Running}}' $ST_CONTAINER 2>/dev/null || echo "false")
  if [ "$ST_RUNNING" = "true" ]; then
    ST_VALUE=1
  fi
fi

aws cloudwatch put-metric-data \
  --region "$REGION" \
  --namespace "$NAMESPACE" \
  --metric-name "ContainerHealthy_datagen" \
  --dimensions "InstanceId=$INSTANCE_ID" \
  --value "$ST_VALUE" \
  --unit "None" \
  --timestamp "$TIMESTAMP" 2>/dev/null

# --- Data generator Prometheus metrics ---

PROM_RESPONSE=$(curl -sf http://localhost:9400 2>/dev/null || echo "")

if [ -n "$PROM_RESPONSE" ]; then
  WRITE_ERRORS=$(echo "$PROM_RESPONSE" | grep '^datagen_events_failed_total' | awk '{sum += $2} END {print sum+0}')

  aws cloudwatch put-metric-data \
    --region "$REGION" \
    --namespace "$NAMESPACE" \
    --metric-name "DatagenWriteErrors" \
    --dimensions "InstanceId=$INSTANCE_ID" \
    --value "$WRITE_ERRORS" \
    --unit "Count" \
    --timestamp "$TIMESTAMP" 2>/dev/null

  EVENTS_TOTAL=$(echo "$PROM_RESPONSE" | grep '^datagen_events_sent_total' | awk '{sum += $2} END {print sum+0}')

  aws cloudwatch put-metric-data \
    --region "$REGION" \
    --namespace "$NAMESPACE" \
    --metric-name "DatagenEventsTotal" \
    --dimensions "InstanceId=$INSTANCE_ID" \
    --value "$EVENTS_TOTAL" \
    --unit "Count" \
    --timestamp "$TIMESTAMP" 2>/dev/null
fi

echo "[$TIMESTAMP] Metrics collected: connections=$CONNECTIONS slots=$SLOT_COUNT lag=$MAX_LAG pg=$PG_VALUE st=$ST_VALUE errors=$WRITE_ERRORS events=$EVENTS_TOTAL"
