#!/bin/bash
# Collects PostgreSQL and Docker health metrics and logs them.
# Runs every 5 minutes via cron.

LOG=/var/log/wsa-monitor.log
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# PostgreSQL metrics
PG_CONNECTIONS=$(sudo docker exec postgres-workshop psql -U postgres -d workshop -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | tr -d ' ' || echo "-1")
PG_REP_SLOTS=$(sudo docker exec postgres-workshop psql -U postgres -d workshop -t -c "SELECT count(*) FROM pg_replication_slots;" 2>/dev/null | tr -d ' ' || echo "-1")
PG_WAL_SIZE=$(sudo docker exec postgres-workshop psql -U postgres -d workshop -t -c "SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0');" 2>/dev/null | tr -d ' ' || echo "-1")

# Docker health
PG_STATUS=$(sudo docker inspect -f '{{.State.Health.Status}}' postgres-workshop 2>/dev/null || echo "unknown")
ST_STATUS=$(sudo docker inspect -f '{{.State.Status}}' datagen 2>/dev/null || echo "unknown")

# Disk usage
DISK_USED_PCT=$(df / --output=pcent | tail -1 | tr -d ' %')

echo "$TS pg_connections=$PG_CONNECTIONS pg_rep_slots=$PG_REP_SLOTS pg_wal_bytes=$PG_WAL_SIZE pg_health=$PG_STATUS st_status=$ST_STATUS disk_pct=$DISK_USED_PCT" >> $LOG

# Rotate log at 10MB
LOG_SIZE=$(stat -c%s "$LOG" 2>/dev/null || echo "0")
if [ "$LOG_SIZE" -gt 10485760 ]; then
  mv "$LOG" "${LOG}.1"
fi
