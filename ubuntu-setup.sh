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

# Prompt for configuration values
read -rp "Domínio do OpenEMR (ex: openemr.example.com): " DOMAIN
read -rp "Senha do MySQL root: " MYSQL_ROOT_PASSWORD
read -rp "Senha do MySQL para o usuário openemr: " MYSQL_PASS
read -rp "Usuário inicial do OpenEMR: " OE_USER
read -rp "Senha inicial do OpenEMR: " OE_PASS
read -rp "Usuário do CouchDB (opcional): " COUCHDB_USER
if [ -n "$COUCHDB_USER" ]; then
    read -rp "Senha do CouchDB: " COUCHDB_PASSWORD
fi
read -rp "Destino rclone para backups (opcional): " RCLONE_REMOTE

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

get_dc_cmd() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        return 1
    fi
}

DC_CMD=$(get_dc_cmd) || abort "docker-compose not found"


# Create .env file from provided values
log "Generating .env file..."
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
if [ -n "${RCLONE_REMOTE}" ]; then
    echo "RCLONE_REMOTE=${RCLONE_REMOTE}" >> .env
fi

# Replace domain in Nginx configs
for f in nginx/nginx.conf nginx/nginx-fallback.conf; do
    sed -i "s/openemr.example.com/${DOMAIN}/g" "$f"
done

# Apply basic firewall rules if requested
if [ -x ./firewall-setup.sh ]; then
    read -rp "Configurar firewall para liberar portas 80 e 443? [s/N] " FW_CHOICE
    if [[ $FW_CHOICE =~ ^[sSyY]$ ]]; then
        log "Applying firewall rules..."
        ./firewall-setup.sh
    fi
fi

log "Starting OpenEMR containers..."
$DC_CMD up -d

log "Setup complete. Access OpenEMR at:"
log "- HTTP:  http://$DOMAIN"
log "- HTTPS: https://$DOMAIN (certificado autoassinado inicialmente)"

