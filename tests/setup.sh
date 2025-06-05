#!/bin/bash
set -e
cd "$(dirname "$0")/.."

TMP=tmp/test-setup
rm -rf "$TMP"
mkdir -p "$TMP/bin"

# Test: fails when docker-compose is missing
if env -i PATH="/usr/bin" ./setup.sh <<<"" >"$TMP/out" 2>&1; then
  echo "Expected failure when docker-compose is missing"
  exit 1
fi
grep -q "docker-compose nao encontrado" "$TMP/out"

# Test: runs setup with stub
cat <<'STUB' > "$TMP/bin/docker-compose"
#!/bin/bash
if [ "$1" = "up" ]; then
  shift
  exit 0
fi
exit 0
STUB
chmod +x "$TMP/bin/docker-compose"
PATH="$(pwd)/$TMP/bin:$PATH" ./setup.sh <<EOF >"$TMP/out" 2>&1
openemr.test
root
dbpass
admin
adminpass

EOF
grep -q "Containers iniciados" "$TMP/out"

echo "setup.sh tests passed"
