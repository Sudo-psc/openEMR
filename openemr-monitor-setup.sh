#!/bin/bash
set -Eeuo pipefail

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [monitor-setup] $*" >&2
}

abort() {
    log "ERROR: $*"
    exit 1
}

usage() {
    cat >&2 <<USAGE
Usage: $0 <install_dir> <host_ip> <smtp_server:port> <sender_email> <sender_password> <receiver_email>
Installs the OpenEMR Monitor stack using the official monitor-installer script.
USAGE
    exit 1
}

[ $# -eq 6 ] || usage

INSTALL_DIR=$1
HOST_IP=$2
SMTP_SERVER=$3
SENDER_EMAIL=$4
SENDER_PASS=$5
RECEIVER_EMAIL=$6

# Check for Docker and docker-compose
get_dc_cmd() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        return 1
    fi
}

DC_CMD=$(get_dc_cmd) || abort "Docker compose not found. Please install Docker and Compose."

log "Downloading monitor-installer script..."
curl -fsSL https://raw.githubusercontent.com/openemr/openemr-devops/master/utilities/openemr-monitor/monitor-installer -o monitor-installer
chmod +x monitor-installer

log "Running monitor-installer..."
./monitor-installer "$INSTALL_DIR" "$HOST_IP" "$SMTP_SERVER" "$SENDER_EMAIL" "$SENDER_PASS" "$RECEIVER_EMAIL"

log "Starting monitor containers..."
cd "$INSTALL_DIR"
$DC_CMD up -d

log "Setup complete. Web interfaces:" 
log "- Grafana:     http://$HOST_IP:3000 (admin/admin)"
log "- Prometheus:  http://$HOST_IP:3001"
log "- cAdvisor:    http://$HOST_IP:3002/metrics"
log "- AlertManager:http://$HOST_IP:3003"
