#!/usr/bin/env bash
# Rollback procedure.
# Redeploys the previously recorded image tag (written by deploy.sh) and
# re-verifies. Use when a deployment fails verification or misbehaves.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  cp .env.example .env
fi
# shellcheck disable=SC1091
set -a && source .env && set +a

APP_IMAGE="${APP_IMAGE:-devops-final-app}"
STATE_DIR=".deploy"
PREV_FILE="$STATE_DIR/previous_tag"

if [[ ! -f "$PREV_FILE" ]]; then
  echo "ERROR: no previous deployment recorded ($PREV_FILE missing)." >&2
  echo "Cannot roll back automatically." >&2
  exit 1
fi

PREV_TAG="$(cat "$PREV_FILE")"
echo "==> Rolling back to ${APP_IMAGE}:${PREV_TAG}"

if ! docker image inspect "${APP_IMAGE}:${PREV_TAG}" >/dev/null 2>&1; then
  echo "ERROR: image ${APP_IMAGE}:${PREV_TAG} is not available locally." >&2
  exit 1
fi

APP_TAG="${PREV_TAG}" docker compose up -d
echo "${PREV_TAG}" > "$STATE_DIR/current_tag"

echo "==> Verifying rolled-back deployment"
./scripts/verify.sh
echo "==> Rollback to ${PREV_TAG} complete."
