#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="workshop-datagen:latest"
DATA_DIR="$(cd "$(dirname "$0")/../data" && pwd)"

# Auto-detect container runtime
if command -v docker &>/dev/null; then
    RUNTIME=docker
elif command -v podman &>/dev/null; then
    RUNTIME=podman
else
    echo "Error: Neither docker nor podman found. Install one and retry."
    exit 1
fi

echo "Using runtime: $RUNTIME"
echo "Data directory: $DATA_DIR"

# Build image if it doesn't exist
if ! $RUNTIME image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "Building image $IMAGE_NAME..."
    $RUNTIME build -t "$IMAGE_NAME" "$(dirname "$0")"
fi

CONFIG_FILE="${1:-/home/data/java-datagen-configuration.json}"

# Load .datagen.env if it exists
ENV_FILE_FLAG=""
if [ -f "$(dirname "$0")/../data/.datagen.env" ]; then
    ENV_FILE_FLAG="--env-file $(dirname "$0")/../data/.datagen.env"
fi

exec $RUNTIME run --rm \
    -v "$DATA_DIR:/home/data" \
    -p 9400:9400 \
    $ENV_FILE_FLAG \
    "$IMAGE_NAME" \
    --config "$CONFIG_FILE"
