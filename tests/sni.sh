#!/bin/bash
set -e
cd "$(dirname "$0")/.."

TMP=tmp/test-sni
rm -rf "$TMP"
mkdir -p "$TMP"
cp nginx/nginx.conf "$TMP/nginx.conf"
cp nginx/nginx-fallback.conf "$TMP/nginx-fallback.conf"

export SNI_DOMAIN_FILE="$TMP/domains"
export NGINX_CONFIGS="$TMP/nginx.conf $TMP/nginx-fallback.conf"

# Add first domain
./sni-manage.sh adicionar exemplo.com >"$TMP/out"
grep -q "exemplo.com" "$TMP/domains"
grep -q "server_name exemplo.com localhost;" "$TMP/nginx.conf"

# Add second domain
./sni-manage.sh adicionar teste.com >"$TMP/out"
grep -q "teste.com" "$TMP/domains"
grep -q "server_name exemplo.com teste.com localhost;" "$TMP/nginx.conf"

# Remove first domain
./sni-manage.sh remover exemplo.com >"$TMP/out"
! grep -q "exemplo.com" "$TMP/domains"
grep -q "server_name teste.com localhost;" "$TMP/nginx.conf"

echo "sni-manage.sh tests passed"
