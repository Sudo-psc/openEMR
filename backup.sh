#!/bin/bash
# Script simples para gerar backups do banco de dados OpenEMR
# Uso: ./backup.sh
# Os arquivos de backup serao armazenados em ./backups
set -e
BACKUP_DIR="$(dirname "$0")/backups"
mkdir -p "$BACKUP_DIR"
DATE=$(date +%F-%H%M%S)
FILE="$BACKUP_DIR/openemr-$DATE.sql"
COUCHFILE="$BACKUP_DIR/couchdb-$DATE.tar.gz"
REDISFILE="$BACKUP_DIR/redis-$DATE.rdb"

docker-compose exec -T mysql mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASS" openemr > "$FILE"
echo "Backup criado em $FILE"
docker-compose exec couchdb tar -czf - /opt/couchdb/data > "$COUCHFILE"
echo "Backup CouchDB criado em $COUCHFILE"
docker-compose exec -T redis sh -c 'redis-cli SAVE && cat /data/dump.rdb' > "$REDISFILE"
echo "Backup Redis criado em $REDISFILE"

