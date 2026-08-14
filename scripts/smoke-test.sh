#!/usr/bin/env bash
set -Eeuo pipefail

base_url="${1:?Uso: ./scripts/smoke-test.sh URL_BASE}"
base_url="${base_url%/}"
attempts="${SMOKE_ATTEMPTS:-20}"

for ((attempt = 1; attempt <= attempts; attempt++)); do
  if health_payload="$(curl --fail --silent --show-error --max-time 5 "${base_url}/health" 2>/dev/null)"; then
    if python3 -c 'import json,sys; assert json.load(sys.stdin) == {"status": "ok"}' <<<"$health_payload"; then
      break
    fi
  fi

  if [[ "$attempt" -eq "$attempts" ]]; then
    echo "Falha: ${base_url}/health não ficou saudável após ${attempts} tentativas." >&2
    exit 1
  fi
  sleep 3
done

version_payload="$(curl --fail --silent --show-error --max-time 5 "${base_url}/version")"
python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["service"] == "taskflow-api"; assert payload["version"]' <<<"$version_payload"

created_payload="$(curl --fail --silent --show-error --max-time 5 \
  --request POST "${base_url}/tasks" \
  --header 'Content-Type: application/json' \
  --data '{"title":"Validar entrega contínua"}')"
python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["title"] == "Validar entrega contínua"' <<<"$created_payload"

curl --fail --silent --show-error --max-time 5 "${base_url}/tasks" >/dev/null
echo "Smoke test aprovado em ${base_url}."
