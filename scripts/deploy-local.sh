#!/usr/bin/env bash
set -Eeuo pipefail

command -v docker >/dev/null || {
  echo "Docker não encontrado." >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

export APP_VERSION="${APP_VERSION:-local-$(date -u +%Y%m%d%H%M%S)}"
docker compose up --build --detach

if ! ./scripts/smoke-test.sh "${TASKFLOW_URL:-http://localhost:8000}"; then
  docker compose logs api
  exit 1
fi

echo "Deploy local concluído. Para encerrar: docker compose down"
