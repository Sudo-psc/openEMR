#!/bin/bash
# Setup script for Codex AI agent: install dependencies and start OpenEMR
set -Eeuo pipefail

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [setup] $*" >&2
}

abort() {
    log "ERROR: $*"
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    abort "Please run as root or with sudo"
fi

log "=== Codex OpenEMR Development Setup ==="

if ! command -v docker >/dev/null; then
    log "Installing Docker and docker-compose..."
    apt-get update -y
    apt-get install -y docker.io docker-compose
fi

get_dc_cmd() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        return 1
    fi
}

DC_CMD=$(get_dc_cmd) || abort "docker-compose installation failed"

if ! systemctl is-active --quiet docker; then
    log "Starting Docker service..."
    systemctl start docker
fi

if [ ! -f .env ]; then
    log "Configuring environment variables..."
    read -rp "Domain for OpenEMR: " DOMAIN
    read -rp "MySQL root password: " MYSQL_ROOT_PASSWORD
    read -rp "MySQL password for user openemr: " MYSQL_PASS
    read -rp "Initial OpenEMR user: " OE_USER
    read -rp "Initial OpenEMR password: " OE_PASS
    read -rp "CouchDB user (optional): " COUCHDB_USER
    if [ -n "$COUCHDB_USER" ]; then
        read -rp "CouchDB password: " COUCHDB_PASSWORD
    fi
    cat > .env <<EOF
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_USER=openemr
MYSQL_PASS=${MYSQL_PASS}
OE_USER=${OE_USER}
OE_PASS=${OE_PASS}
EOF
    if [ -n "${COUCHDB_USER:-}" ]; then
cat >> .env <<EOF
COUCHDB_USER=${COUCHDB_USER}
COUCHDB_PASSWORD=${COUCHDB_PASSWORD}
EOF
    fi
    for f in nginx/nginx.conf nginx/nginx-fallback.conf; do
        sed -i "s/__DOMAIN__/${DOMAIN}/g" "$f"
    done
else
    log ".env already exists - skipping configuration"
fi

log "Starting OpenEMR containers..."
$DC_CMD up -d

log "Waiting for containers to initialize..."
sleep 30

log "OpenEMR is now accessible at:"
log "- http://localhost"
log "- https://localhost (self-signed certificate)"
log "Default credentials: admin / pass"
log "To stop the environment run: $DC_CMD down"
