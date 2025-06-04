#!/bin/bash
# Setup script for Ubuntu to run OpenEMR with Docker
set -Eeuo pipefail

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [setup] $*" >&2
}

abort() {
    log "ERROR: $*"
    exit 1
}

# Require root privileges
if [ "$(id -u)" -ne 0 ]; then
    abort "Please run as root or with sudo"
fi

log "Updating package index..."
apt-get update -y

REQUIRED_PKGS=(docker.io docker-compose)
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        log "Installing $pkg..."
        apt-get install -y "$pkg"
    fi
done

# Ensure Docker service is running
if ! systemctl is-active --quiet docker; then
    log "Starting Docker service..."
    systemctl start docker
fi

command -v docker-compose >/dev/null 2>&1 || abort "docker-compose not found"

# Ensure .env exists
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        log "Creating .env from example"
        cp .env.example .env
    else
        abort ".env.example not found"
    fi
fi

# Apply basic firewall rules
if [ -x ./firewall-setup.sh ]; then
    log "Applying firewall rules..."
    ./firewall-setup.sh
fi

log "Starting OpenEMR containers..."
docker-compose up -d

log "Setup complete. Access OpenEMR at http://localhost"
