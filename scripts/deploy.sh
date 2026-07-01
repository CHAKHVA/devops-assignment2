#!/usr/bin/env bash
# Local continuous-deployment script.
# Builds a versioned image, records the previously deployed tag so we can roll
# back, brings the stack up with the new image, and runs post-deploy verification.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  cp .env.example .env
fi
# shellcheck disable=SC1091
set -a && source .env && set +a

APP_IMAGE="${APP_IMAGE:-devops-final-app}"
NEW_TAG="${1:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"
STATE_DIR=".deploy"
mkdir -p "$STATE_DIR"

# Preserve the current tag as the rollback target before we overwrite it.
if [[ -f "$STATE_DIR/current_tag" ]]; then
  cp "$STATE_DIR/current_tag" "$STATE_DIR/previous_tag"
fi

echo "==> Building ${APP_IMAGE}:${NEW_TAG}"
docker build -t "${APP_IMAGE}:${NEW_TAG}" -t "${APP_IMAGE}:latest" ./app

echo "==> Deploying ${APP_IMAGE}:${NEW_TAG}"
APP_TAG="${NEW_TAG}" docker compose up -d

echo "${NEW_TAG}" > "$STATE_DIR/current_tag"

echo "==> Running post-deploy verification"
if ! ./scripts/verify.sh; then
  echo "Deployment verification FAILED. Consider running: make rollback" >&2
  exit 1
fi

echo "==> Deploy of ${APP_IMAGE}:${NEW_TAG} succeeded."
