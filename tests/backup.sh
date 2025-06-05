#!/bin/bash
set -e
cd "$(dirname "$0")/.."

TMP=tmp/test-backup
rm -rf "$TMP"
mkdir -p "$TMP/bin" "$TMP/backups"

# Test: fails when docker-compose is missing
if env -i PATH="/usr/bin" ./backup.sh >"$TMP/out" 2>&1; then
  echo "Expected failure when docker-compose is missing"
  exit 1
fi
grep -q "docker-compose nao encontrado" "$TMP/out"

# Test: creates backup with docker-compose stub
cat <<'STUB' > "$TMP/bin/docker-compose"
#!/bin/bash
if [ "$1" = "exec" ]; then
  exit 0
fi
exit 0
STUB
chmod +x "$TMP/bin/docker-compose"
PATH="$(pwd)/$TMP/bin:$PATH" BACKUP_DIR="$(pwd)/$TMP/backups" MYSQL_USER=u MYSQL_PASS=p ./backup.sh >"$TMP/out" 2>&1
[ -n "$(ls -A "$TMP/backups")" ]

# Test: uploads backup when RCLONE_REMOTE is set
cat <<STUB > "$TMP/bin/rclone"
#!/bin/bash
echo "\$@" > "$TMP/rclone_args"
exit 0
STUB
chmod +x "$TMP/bin/rclone"
PATH="$(pwd)/$TMP/bin:$PATH" BACKUP_DIR="$(pwd)/$TMP/backups" MYSQL_USER=u MYSQL_PASS=p RCLONE_REMOTE="remote:dest" ./backup.sh >"$TMP/out" 2>&1
grep -q "remote:dest" "$TMP/rclone_args"

echo "backup.sh tests passed"
