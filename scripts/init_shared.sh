#!/usr/bin/env bash
set -euo pipefail

echo "Initializing shared volume with content from ./shared/"

# Check if source directory exists
if [ ! -d "./shared" ]; then
  echo "Error: ./shared directory not found"
  exit 1
fi

# Copy content to the volume using a temporary container
docker run --rm \
  -v "$(pwd)/shared:/source:ro" \
  -v "jupyterhub-shared:/dest" \
  alpine sh -c '
    echo "Copying files from /source to /dest..."
    cp -a /source/. /dest/
    echo "✓ Files copied successfully"
    ls -la /dest/
  '

echo "✓ Shared volume initialized"

