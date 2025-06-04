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

command -v docker-compose >/dev/null 2>&1 || abort "docker-compose nao encontrado"

log "Baixando ultimas imagens..."
docker-compose pull

log "Criando backup do banco de dados antes do update..."
"$(dirname "$0")/backup.sh"

log "Aplicando atualizacoes..."
docker-compose up -d --remove-orphans

log "Update completo."
