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

# Run diagnostics to ensure prerequisites and free required ports
diagnostics() {
    log "Executando diagnóstico do sistema..."

    if ! command -v docker >/dev/null 2>&1; then
        abort "Docker não encontrado"
    fi

    if ! systemctl is-active --quiet docker; then
        log "Iniciando serviço Docker..."
        systemctl start docker
    fi

    local ports=(80 443)
    [[ -n "${COUCHDB_USER:-}" ]] && ports+=(5984)

    for port in "${ports[@]}"; do
        if ss -tulpn | grep -q ":$port " ; then
            log "Porta $port em uso. Tentando liberar..."

            local containers
            containers=$(docker ps --filter "publish=$port" -q) || true
            if [ -n "$containers" ]; then
                docker stop "$containers"
                log "Containers Docker parados: $containers"
            fi

            if command -v lsof >/dev/null 2>&1; then
                local pids
                pids=$(lsof -t -i :"$port" || true)
                if [ -n "$pids" ]; then
                    kill -9 "$pids" || true
                    log "Processos finalizados na porta $port: $pids"
                fi
            fi
        fi
    done

    log "Diagnóstico concluído"
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

REQUIRED_PKGS=(docker.io docker-compose lsof iproute2)
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

# Run diagnostics to check dependencies and free ports
diagnostics

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

# Download and install ophthalmology modules (Eye Exam)
install_ophthalmology_modules() {
    if ! command -v docker >/dev/null 2>&1; then
        log "docker não encontrado; ignorando instalação do Eye Exam"
        return
    fi
    log "Baixando módulo Eye Exam..."
    local tmpdir
    tmpdir=$(mktemp -d)
    curl -fsSL https://github.com/openemr/openemr/archive/refs/heads/master.zip -o "$tmpdir/openemr.zip"
    unzip -q "$tmpdir/openemr.zip" "openemr-master/interface/forms/eye_mag/*" -d "$tmpdir"
    local container
    container=$($DC_CMD ps -q openemr)
    docker cp "$tmpdir/openemr-master/interface/forms/eye_mag" "$container":/var/www/localhost/htdocs/openemr/interface/forms/
    docker exec "$container" chown -R www-data:www-data /var/www/localhost/htdocs/openemr/interface/forms/eye_mag
    rm -rf "$tmpdir"
    log "Módulo Eye Exam instalado"
}


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

# Install Eye Exam and related ophthalmology templates
install_ophthalmology_modules

log "Setup complete. Access OpenEMR at:"
log "- HTTP:  http://$DOMAIN"
log "- HTTPS: https://$DOMAIN (certificado autoassinado inicialmente)"

# Install openemr-cmd utilities locally for easier management
if [ -f utilities/openemr-cmd ]; then
    TARGET_DIR="$HOME/.local/bin"
    mkdir -p "$TARGET_DIR"
    cp utilities/openemr-cmd "$TARGET_DIR/"
    cp utilities/openemr-cmd-h "$TARGET_DIR/"
    chmod +x "$TARGET_DIR/openemr-cmd" "$TARGET_DIR/openemr-cmd-h"
    log "Utilitários 'openemr-cmd' instalados em $TARGET_DIR"
fi

# Install health_monitor.sh for system monitoring
if [ -f health_monitor.sh ]; then
    TARGET_DIR="$HOME/.local/bin"
    mkdir -p "$TARGET_DIR"
    cp health_monitor.sh "$TARGET_DIR/"
    chmod +x "$TARGET_DIR/health_monitor.sh"
    log "Script 'health_monitor.sh' instalado em $TARGET_DIR"
fi

