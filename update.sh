#!/bin/bash
# Update OpenEMR containers with backup

set -Eeuo pipefail

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [update] $*" >&2
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

log "Baixando ultimas imagens..."
$DC_CMD pull

log "Criando backup do banco de dados antes do update..."
"$(dirname "$0")/backup.sh"

log "Aplicando atualizacoes..."
$DC_CMD up -d --remove-orphans

log "Update completo."
