#!/bin/bash
# Setup script for Codex AI agent: install dependencies and start OpenEMR
set -euo pipefail

echo "=== Codex OpenEMR Development Setup ==="

# Install Docker and docker-compose if missing
if ! command -v docker >/dev/null; then
  echo "Installing Docker and docker-compose..."
  apt-get update
  apt-get install -y docker.io docker-compose
fi

# Ensure .env exists
if [ ! -f .env ]; then
  echo "Creating .env from example"
  cp .env.example .env
fi

# Start services
echo "Starting OpenEMR containers..."
docker-compose up -d

echo "Waiting for containers to initialize..."
sleep 30

echo "OpenEMR is now accessible at:"
echo "- http://localhost"
echo "- https://localhost (self-signed certificate)"
echo "Default credentials: admin / pass"
echo "To stop the environment run: docker-compose down"
