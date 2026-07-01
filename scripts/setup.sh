#!/usr/bin/env bash
# One-command environment bootstrap.
# Creates .env from the template if needed, then builds and starts the stack
# and waits for it to become healthy. Reproducible on any machine with Docker.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed or not on PATH." >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  echo "==> Creating .env from .env.example"
  cp .env.example .env
  echo "    A default .env was created. Edit it to change the Grafana password."
fi

echo "==> Building and starting the stack"
docker compose up -d --build

echo "==> Waiting for services to become healthy"
./scripts/verify.sh

echo ""
echo "Setup complete. Grafana: http://localhost:3000  |  Prometheus: http://localhost:9090"
