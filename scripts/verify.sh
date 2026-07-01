#!/usr/bin/env bash
# Deployment verification / post-deploy health checks.
# Polls the app health + metrics endpoints and confirms every container that
# declares a healthcheck reports "healthy". Exits non-zero on failure so it can
# gate a deployment.
set -euo pipefail

cd "$(dirname "$0")/.."

# Load APP_PORT if present, default to 5001.
if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a && source .env && set +a
fi
APP_PORT="${APP_PORT:-5001}"

TIMEOUT="${VERIFY_TIMEOUT:-90}"
INTERVAL=3

echo "==> Verifying app endpoints on http://localhost:${APP_PORT}"
deadline=$((SECONDS + TIMEOUT))
until curl -fsS "http://localhost:${APP_PORT}/health" >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    echo "FAIL: /health did not respond within ${TIMEOUT}s" >&2
    docker compose ps || true
    exit 1
  fi
  sleep "$INTERVAL"
done
echo "    /health OK"

curl -fsS "http://localhost:${APP_PORT}/metrics" | grep -q "app_requests_total" \
  && echo "    /metrics OK" \
  || { echo "FAIL: /metrics missing expected data" >&2; exit 1; }

echo "==> Checking container health status"
unhealthy=0
while read -r name status; do
  case "$status" in
    healthy|"") echo "    ${name}: ${status:-no healthcheck}" ;;
    *) echo "    ${name}: ${status}" >&2; unhealthy=1 ;;
  esac
done < <(docker compose ps --format '{{.Service}} {{.Health}}')

if (( unhealthy != 0 )); then
  echo "FAIL: one or more containers are not healthy" >&2
  exit 1
fi

echo "==> Verification passed. Stack is healthy."
