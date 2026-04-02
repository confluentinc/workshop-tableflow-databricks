#!/bin/bash

# Log everything to a file for debugging
exec > >(tee -a /var/log/postgres-setup.log)
exec 2>&1

set -euo pipefail

echo "================================================"
echo "PostgreSQL Workshop Instance Setup Started"
echo "Script PID: $$"
echo "Start Time: $(date)"
echo "================================================"

START_TIME=$(date +%s)

# Update system
echo "Updating system packages..."
apt-get update -y
apt-get upgrade -y || echo "WARNING: apt-get upgrade failed, continuing..."

# Install Docker
echo "Installing Docker..."
apt-get install -y docker.io docker-compose-v2
systemctl enable docker
systemctl start docker

docker --version
systemctl status docker --no-pager

# Create directory for PostgreSQL data and init scripts
echo "Creating PostgreSQL directories..."
mkdir -p /opt/postgres/data
mkdir -p /opt/postgres/init-scripts
chmod -R 777 /opt/postgres

# Create PostgreSQL initialization script
echo "Creating PostgreSQL init script..."
cat > /opt/postgres/init-scripts/01-init.sql <<'INIT_SQL'
CREATE SCHEMA IF NOT EXISTS cdc;

CREATE TABLE IF NOT EXISTS cdc.customer (
    customer_id VARCHAR(50),
    email VARCHAR(255) PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    birth_date VARCHAR(10),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cdc.hotel (
    hotel_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255),
    category VARCHAR(50),
    description TEXT,
    city VARCHAR(100),
    country VARCHAR(100),
    room_capacity INTEGER,
    available_rooms INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cdc.bookings (
    booking_id VARCHAR(50) PRIMARY KEY,
    customer_email VARCHAR(255),
    hotel_id VARCHAR(50),
    check_in TIMESTAMP,
    check_out TIMESTAMP,
    occupants INTEGER,
    price INTEGER,
    created_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cdc.clickstream (
    activity_id VARCHAR(50) PRIMARY KEY,
    customer_email VARCHAR(255),
    hotel_id VARCHAR(50),
    action VARCHAR(50),
    event_duration INTEGER,
    url VARCHAR(500),
    created_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cdc.hotel_reviews (
    review_id VARCHAR(50) PRIMARY KEY,
    booking_id VARCHAR(50),
    review_rating INTEGER,
    review_text TEXT,
    created_at TIMESTAMP
);

CREATE USER debezium WITH REPLICATION LOGIN PASSWORD '${debezium_password}';
GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO debezium;
GRANT ALL PRIVILEGES ON SCHEMA cdc TO debezium;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cdc TO debezium;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA cdc TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA cdc GRANT ALL PRIVILEGES ON TABLES TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA cdc GRANT ALL PRIVILEGES ON SEQUENCES TO debezium;

ALTER TABLE cdc.customer OWNER TO debezium;
ALTER TABLE cdc.hotel OWNER TO debezium;
ALTER TABLE cdc.bookings OWNER TO debezium;
ALTER TABLE cdc.clickstream OWNER TO debezium;
ALTER TABLE cdc.hotel_reviews OWNER TO debezium;

GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
ALTER USER debezium WITH REPLICATION;

CREATE PUBLICATION dbz_publication FOR ALL TABLES IN SCHEMA cdc;

\echo 'PostgreSQL initialization complete'
\echo 'Database: ${db_name}'
\echo 'Schema: cdc'
\echo 'CDC User: debezium'
\echo 'Publication: dbz_publication (FOR ALL TABLES IN SCHEMA cdc)'
INIT_SQL

# Create docker-compose.yml file
cat > /opt/postgres/docker-compose.yml <<'DOCKER_COMPOSE'
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres-workshop
    environment:
      POSTGRES_PASSWORD: ${db_password}
      POSTGRES_DB: ${db_name}
      POSTGRES_USER: ${db_username}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    command:
      - "postgres"
      - "-c"
      - "wal_level=logical"
      - "-c"
      - "max_replication_slots=${max_replication_slots}"
      - "-c"
      - "max_wal_senders=${max_wal_senders}"
      - "-c"
      - "max_connections=${max_connections}"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${db_username}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  postgres_data:
DOCKER_COMPOSE

# Start PostgreSQL container
echo "Starting PostgreSQL container..."
cd /opt/postgres
docker compose up -d

# Wait for PostgreSQL to be healthy
echo "Waiting for PostgreSQL to become healthy..."
MAX_RETRIES=60
COUNT=0
while [ $COUNT -lt $MAX_RETRIES ]; do
  STATUS=$(docker inspect -f '{{.State.Health.Status}}' postgres-workshop 2>/dev/null || echo "not_ready")
  if [ "$STATUS" = "healthy" ]; then
    echo "PostgreSQL is healthy!"
    break
  fi
  COUNT=$((COUNT + 1))
  echo "  Attempt $COUNT/$MAX_RETRIES (status: $STATUS) - waiting 10s..."
  sleep 10
done

if [ $COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: PostgreSQL did not become healthy after 10 minutes"
  exit 1
fi

HEALTHY_TIME=$(date +%s)
ELAPSED=$((HEALTHY_TIME - START_TIME))
echo "================================================"
echo "PostgreSQL is healthy! Time to healthy: $ELAPSED seconds"
echo "================================================"

# Verify setup
echo "Verifying PostgreSQL setup..."
docker exec postgres-workshop psql -U ${db_username} -d ${db_name} -c "SELECT version();"
docker exec postgres-workshop psql -U ${db_username} -d ${db_name} -c "SHOW wal_level;"
docker exec postgres-workshop psql -U ${db_username} -d ${db_name} -c "SELECT * FROM pg_publication;"
docker exec postgres-workshop psql -U ${db_username} -d ${db_name} -c "\dn"

echo "Verifying Debezium CDC user..."
docker exec postgres-workshop psql -U ${db_username} -d ${db_name} -c "\du debezium"

# Mark setup as complete
touch /opt/postgres/.setup-complete

END_TIME=$(date +%s)
TOTAL_ELAPSED=$((END_TIME - START_TIME))
echo "================================================"
echo "PostgreSQL workshop instance setup complete!"
echo "Total Duration: $TOTAL_ELAPSED seconds"
echo "================================================"

exit 0
