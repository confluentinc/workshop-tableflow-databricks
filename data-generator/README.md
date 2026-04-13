# Data Generator

Custom Java application that interprets Java Datagen JSON DSL configuration files to generate data for the Tableflow workshop. Supports both Postgres and Kafka (Avro/Schema Registry) sinks.

## Build

```bash
docker build -t workshop-datagen:latest .
```

Multi-platform build:

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t workshop-datagen:latest .
```

## Run Locally

### Using run script (auto-detects Docker/Podman)

```bash
# Self-service mode (Postgres + Kafka)
./run.sh /home/data/java-datagen-configuration.json

# Workshop/instructor-led mode (Postgres only)
./run.sh /home/data/java-datagen-configuration-workshop.json
```

### Using Docker directly

```bash
docker run --rm \
  -v "$(pwd)/../data:/home/data" \
  -p 9400:9400 \
  workshop-datagen:latest \
  --config /home/data/java-datagen-configuration-workshop.json
```

### With connection credentials (.datagen.env)

For self-service mode, create `../data/.datagen.env` with Kafka/Schema Registry credentials. The `run.sh` script will automatically load it.

## Configuration

The application reads the same Java Datagen JSON configuration files located in the `../data/` directory. No modifications are needed to the existing generator JSON files.

### Supported modes

| Mode | Config file | Sinks | Use case |
|------|-------------|-------|----------|
| Workshop | `java-datagen-configuration-workshop.json` | Postgres | Instructor-led path (shared infra) |
| Self-service | `java-datagen-configuration.json` | Postgres + Kafka | Self-service path (attendee laptop) |

## Health Endpoint

Prometheus-compatible metrics are exposed on port 9400:

```
datagen_events_sent_total <count>
datagen_events_failed_total <count>
```
