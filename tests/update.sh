#!/bin/bash
set -e
cd "$(dirname "$0")/.."

TMP=tmp/test-update
rm -rf "$TMP"
mkdir -p "$TMP/bin" "$TMP/backups"

# Test: fails when docker-compose is missing
if env -i PATH="/usr/bin" ./update.sh >"$TMP/out" 2>&1; then
  echo "Expected failure when docker-compose is missing"
  exit 1
fi
grep -q "docker-compose nao encontrado" "$TMP/out"

# Test: runs update with stubs
cat <<'STUB' > "$TMP/bin/docker-compose"
#!/bin/bash
exit 0
STUB
chmod +x "$TMP/bin/docker-compose"
cat <<'STUB' > "$TMP/bin/backup.sh"
#!/bin/bash
exit 0
STUB
chmod +x "$TMP/bin/backup.sh"
PATH="$(pwd)/$TMP/bin:$PATH" BACKUP_DIR="$(pwd)/$TMP/backups" ./update.sh >"$TMP/out" 2>&1
grep -q "Update completo" "$TMP/out"

echo "update.sh tests passed"
