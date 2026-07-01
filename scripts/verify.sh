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

# Exercise the root endpoint before checking /metrics. Under prometheus_client
# multiprocess mode a metric series is only emitted once a worker has observed
# it, so we generate one request to guarantee app_requests_total exists.
curl -fsS "http://localhost:${APP_PORT}/" >/dev/null 2>&1 \
  && echo "    / OK" \
  || { echo "FAIL: / did not respond" >&2; exit 1; }

curl -fsS "http://localhost:${APP_PORT}/metrics" | grep -q "app_requests_total" \
  && echo "    /metrics OK" \
  || { echo "FAIL: /metrics missing expected data" >&2; exit 1; }

echo "==> Waiting for container health to settle"
health_deadline=$((SECONDS + TIMEOUT))
while true; do
  starting=0
  unhealthy=0
  statuses=""
  while read -r name status; do
    statuses+="    ${name}: ${status:-no healthcheck}"$'\n'
    case "$status" in
      healthy|"") ;;
      starting) starting=1 ;;
      *) unhealthy=1 ;;
    esac
  done < <(docker compose ps --format '{{.Service}} {{.Health}}')

  if (( unhealthy == 1 )); then
    printf "%s" "$statuses" >&2
    echo "FAIL: one or more containers reported unhealthy" >&2
    exit 1
  fi

  if (( starting == 0 )); then
    printf "%s" "$statuses"
    break
  fi

  if (( SECONDS >= health_deadline )); then
    printf "%s" "$statuses" >&2
    echo "FAIL: containers did not become healthy within ${TIMEOUT}s" >&2
    exit 1
  fi
  sleep "$INTERVAL"
done

echo "==> Verification passed. Stack is healthy."
