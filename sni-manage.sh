#!/bin/bash
set -euo pipefail

DOMAIN_FILE="${SNI_DOMAIN_FILE:-sni-domains.txt}"
CONFIG_FILES="${NGINX_CONFIGS:-nginx/nginx.conf nginx/nginx-fallback.conf}"

usage() {
  cat <<'USAGE'
Uso: $0 adicionar|remover|listar dominio1 [dominio2 ...]
Gerencia os dominios SNI configurados no Nginx.

Variaveis de ambiente:
  SNI_DOMAIN_FILE  Arquivo que armazena os dominios (padrao: sni-domains.txt)
  NGINX_CONFIGS    Arquivos de configuracao do Nginx a atualizar
USAGE
  exit 1
}

cmd=${1:-}
shift || true

case "$cmd" in
  adicionar)
    [ $# -ge 1 ] || usage
    mkdir -p "$(dirname "$DOMAIN_FILE")" 2>/dev/null || true
    touch "$DOMAIN_FILE"
    for d in "$@"; do
      grep -Fxq "$d" "$DOMAIN_FILE" || echo "$d" >> "$DOMAIN_FILE"
    done
    ;;
  remover)
    [ $# -ge 1 ] || usage
    if [ -f "$DOMAIN_FILE" ]; then
      for d in "$@"; do
        grep -Fxv "$d" "$DOMAIN_FILE" > "$DOMAIN_FILE.tmp" && mv "$DOMAIN_FILE.tmp" "$DOMAIN_FILE"
      done
    fi
    ;;
  listar)
    if [ -f "$DOMAIN_FILE" ]; then
      cat "$DOMAIN_FILE"
    fi
    exit 0
    ;;
  *)
    usage
    ;;
esac

[ -s "$DOMAIN_FILE" ] || { echo "Nenhum dominio configurado."; exit 0; }

DOMAINS=$(paste -sd' ' "$DOMAIN_FILE")

for conf in $CONFIG_FILES; do
  [ -f "$conf" ] || continue
  sed -E '/^\s*server_name localhost;/! s/^\s*server_name .*;/        server_name '"$DOMAINS"' localhost;/' "$conf" > "$conf.tmp"
  mv "$conf.tmp" "$conf"
done

if docker compose version >/dev/null 2>&1; then
  docker compose exec nginx nginx -s reload >/dev/null 2>&1 || true
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose exec nginx nginx -s reload >/dev/null 2>&1 || true
fi

echo "Dominios atuais:" && cat "$DOMAIN_FILE"
