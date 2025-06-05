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
