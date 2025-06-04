#!/bin/bash
# Update OpenEMR containers with backup
set -e

echo "Pulling latest images..."
docker-compose pull

echo "Creating database backup before update..."
./backup.sh

echo "Applying updates..."
docker-compose up -d --remove-orphans

echo "Update complete."
