#!/bin/bash
# Script simples para gerar backups do banco de dados OpenEMR
# Uso: ./backup.sh
# Os arquivos de backup serao armazenados em ./backups

set -Eeuo pipefail

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [backup] $*" >&2
}

abort() {
    log "ERRO: $*"
    exit 1
}

command -v docker-compose >/dev/null 2>&1 || abort "docker-compose nao encontrado"

BACKUP_DIR="${BACKUP_DIR:-$(dirname "$0")/backups}"
mkdir -p "$BACKUP_DIR"
DATE=$(date +%F-%H%M%S)
FILE="$BACKUP_DIR/openemr-$DATE.sql"

if docker-compose exec -T mysql mysqldump -u"${MYSQL_USER:-openemr}" -p"${MYSQL_PASS:-openemr}" openemr > "$FILE"; then
    log "Backup criado em $FILE"
else
    abort "Falha ao criar backup"
fi
