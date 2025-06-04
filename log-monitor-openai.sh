#!/bin/bash
# Monitor Docker logs and ask OpenAI's API for a summary of potential errors
set -e

if [ -z "$OPENAI_API_KEY" ]; then
  echo "OPENAI_API_KEY environment variable not set" >&2
  exit 1
fi
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

LOG_FILE="./logs/docker.log"
mkdir -p ./logs

get_dc_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    echo "docker-compose nao encontrado" >&2
    exit 1
  fi
}

DC_CMD=$(get_dc_cmd)

echo "Collecting container logs..."
$DC_CMD logs --no-color > "$LOG_FILE"

# Take the last 200 lines for analysis
LOG_DATA=$(tail -n 200 "$LOG_FILE" | sed 's/"/\\"/g')

read -r -d '' PAYLOAD <<JSON
{
  "model": "gpt-4o",
  "messages": [
    {"role": "user", "content": "Analise os logs a seguir e forne\u00e7a um resumo de poss\u00edveis erros:\n$LOG_DATA"}
  ]
}
JSON

echo "Enviando logs para OpenAI..."

curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$PAYLOAD" | jq -r '.choices[0].message.content'
