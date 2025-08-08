#!/usr/bin/env bash
set -euo pipefail

# Usage: build_openrv_image.sh [-n]
#   -n    Disable Docker cache (pass --no-cache to docker build)

usage() {
  echo "Usage: $0 [-n]"
  exit 1
}

# Default settings
NO_CACHE=false
IMAGE_NAME="openrv_rocky9"
CONTAINER_NAME="openrv_container"

# Parse options
while getopts "n" opt; do
  case $opt in
    n) NO_CACHE=true ;;
    *) usage ;;
  esac
done

# Build the Docker image
BUILD_ARGS=()
if [[ "$NO_CACHE" == true ]]; then
  BUILD_ARGS+=(--no-cache)
fi
BUILD_ARGS+=(--load -t "$IMAGE_NAME" .)

echo "Building Docker image '$IMAGE_NAME'..."
docker build "${BUILD_ARGS[@]}"

# Remove any existing container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Removing old container '$CONTAINER_NAME'..."
  docker rm -f "$CONTAINER_NAME"
fi

# Run new container
echo "Starting container '$CONTAINER_NAME'..."
docker run --name "$CONTAINER_NAME" -d "$IMAGE_NAME" tail -f /dev/null

# Retrieve build name and copy artifact
echo "Retrieving build name from container environment..."
BUILD_NAME=$(docker exec "$CONTAINER_NAME" bash -lc 'source /home/rv/OpenRV/environment && echo "${BUILD_NAME}"')

echo "Copying ${BUILD_NAME}.tar.gz to current directory..."
docker cp "$CONTAINER_NAME:/home/rv/OpenRV/${BUILD_NAME}.tar.gz" "$PWD/"

# Verify copy succeeded
if [[ ! -f "$PWD/${BUILD_NAME}.tar.gz" ]]; then
  echo "Error: ${BUILD_NAME}.tar.gz not found in $PWD" >&2
  exit 1
fi

echo "Artifact copied successfully. Cleaning up container '$CONTAINER_NAME'..."
# Remove container
docker rm -f "$CONTAINER_NAME"

echo "Build completed: '$PWD/${BUILD_NAME}.tar.gz'"