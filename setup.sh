#!/bin/bash
set -Eeuo pipefail

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [setup] $*" >&2
}

abort() {
    log "ERRO: $*"
    exit 1
}

get_dc_cmd() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        return 1
    fi
}


DC_CMD=$(get_dc_cmd) || abort "docker-compose nao encontrado"

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


# Solicitar dados ao usuario
read -rp "Domínio do OpenEMR (ex: openemr.example.com): " DOMAIN
read -rp "Senha do MySQL root: " MYSQL_ROOT_PASSWORD
read -rp "Senha do MySQL para o usuário openemr: " MYSQL_PASS
read -rp "Usuário inicial do OpenEMR: " OE_USER
read -rp "Senha inicial do OpenEMR: " OE_PASS
read -rp "Usuário do CouchDB (opcional): " COUCHDB_USER
if [ -n "$COUCHDB_USER" ]; then
    read -rp "Senha do CouchDB: " COUCHDB_PASSWORD
fi

MYSQL_USER="openemr"

cat > .env <<EOFENV
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASS=${MYSQL_PASS}
OE_USER=${OE_USER}
OE_PASS=${OE_PASS}
EOFENV

if [ -n "${COUCHDB_USER:-}" ]; then
cat >> .env <<EOFENV
COUCHDB_USER=${COUCHDB_USER}
COUCHDB_PASSWORD=${COUCHDB_PASSWORD}
EOFENV
fi

for f in nginx/nginx.conf nginx/nginx-fallback.conf; do
    sed -i "s/openemr.example.com/${DOMAIN}/g" "$f"
done

log "Iniciando containers..."
$DC_CMD up -d

log "Aguardando inicializacao dos containers..."
sleep 30

log "Containers iniciados! Acesse:"
log "- OpenEMR HTTP (Local): http://localhost"
log "- OpenEMR HTTP (Producao): http://${DOMAIN}"
log "- OpenEMR HTTPS (Local): https://localhost (certificado autoassinado - avisos do navegador)"
log "- OpenEMR HTTPS (Producao): https://${DOMAIN} (certificado autoassinado - avisos do navegador)"
log ""
log "Para parar os containers: $DC_CMD down"
log "Para ver logs: $DC_CMD logs -f"
log "Para ver logs do nginx: $DC_CMD logs -f nginx"

# Install Eye Exam and related ophthalmology templates
install_ophthalmology_modules

# Install openemr-cmd utilities for convenience
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
