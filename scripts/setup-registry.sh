#!/bin/bash
# =============================================================================
# Local Registry Setup Script
# =============================================================================
# Setup a simple local container registry for air-gapped deployment
#
# Usage: ./setup-registry.sh [port]
# Example: ./setup-registry.sh 5000
#
# Environment Variables:
#   REGISTRY_DATA - Data directory (default: /var/lib/registry)
#
# After setup, run:
#   ./mirror-all-images.sh localhost:5000
# =============================================================================

set -e

PORT="${1:-5000}"
DATA_DIR="${REGISTRY_DATA:-/var/lib/registry}"
CONTAINER_NAME="registry"

echo "============================================"
echo "Local Registry Setup"
echo "============================================"
echo "Port: ${PORT}"
echo "Data Directory: ${DATA_DIR}"
echo "============================================"
echo ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
  echo "Error: Docker is not installed"
  exit 1
fi

# Stop existing registry if running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Stopping existing registry container..."
  docker stop ${CONTAINER_NAME} || true
  docker rm ${CONTAINER_NAME} || true
fi

# Create data directory
mkdir -p ${DATA_DIR}

# Run registry
echo "Starting registry container..."
docker run -d \
  -p ${PORT}:5000 \
  --restart=always \
  --name ${CONTAINER_NAME} \
  -v ${DATA_DIR}:/var/lib/registry \
  registry:2

# Wait for registry to be ready
echo "Waiting for registry to be ready..."
sleep 3

# Test registry
if curl -f http://localhost:${PORT}/v2/ > /dev/null 2>&1; then
  echo ""
  echo "============================================"
  echo "✓ Registry is running successfully!"
  echo "============================================"
  echo "URL: http://localhost:${PORT}"
  echo "Data: ${DATA_DIR}"
  echo ""
  echo "Test with:"
  echo "  curl http://localhost:${PORT}/v2/_catalog"
  echo ""
  echo "To stop:"
  echo "  docker stop ${CONTAINER_NAME}"
  echo "============================================"
else
  echo ""
  echo "✗ Registry failed to start properly"
  docker logs ${CONTAINER_NAME}
  exit 1
fi
