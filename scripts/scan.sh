#!/usr/bin/env bash
# Local security scan suite. Mirrors the checks that run in CI so developers
# can reproduce them before pushing. Uses only free/open-source tools.
#
#   1. pip-audit  - dependency vulnerability scanning
#   2. Trivy fs   - filesystem/config + Dockerfile scanning (IaC/config)
#   3. Trivy image- container image vulnerability scanning
#   4. gitleaks   - secrets scanning
#   5. hadolint   - Dockerfile best-practice/security linting
#
# Missing tools are reported and skipped rather than failing hard, so the
# script is usable on a fresh machine. CI installs all of them.
set -uo pipefail

cd "$(dirname "$0")/.."

APP_IMAGE="${APP_IMAGE:-devops-final-app}"
APP_TAG="${APP_TAG:-latest}"
rc=0

section() { echo ""; echo "=====> $1"; }

section "1/5 Dependency scan (pip-audit)"
if command -v pip-audit >/dev/null 2>&1; then
  pip-audit -r app/requirements.txt || rc=1
else
  echo "SKIP: pip-audit not installed (pip install pip-audit)"
fi

section "2/5 Config / IaC scan (trivy config)"
if command -v trivy >/dev/null 2>&1; then
  trivy config --exit-code 0 . || rc=1
else
  echo "SKIP: trivy not installed (https://aquasecurity.github.io/trivy)"
fi

section "3/5 Container image scan (trivy image)"
if command -v trivy >/dev/null 2>&1; then
  if docker image inspect "${APP_IMAGE}:${APP_TAG}" >/dev/null 2>&1; then
    trivy image --exit-code 0 --severity HIGH,CRITICAL "${APP_IMAGE}:${APP_TAG}" || rc=1
  else
    echo "SKIP: image ${APP_IMAGE}:${APP_TAG} not built yet (run: make up)"
  fi
else
  echo "SKIP: trivy not installed"
fi

section "4/5 Secrets scan (gitleaks)"
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --no-banner --redact || rc=1
else
  echo "SKIP: gitleaks not installed (https://github.com/gitleaks/gitleaks)"
fi

section "5/5 Dockerfile lint (hadolint)"
if command -v hadolint >/dev/null 2>&1; then
  hadolint app/Dockerfile || rc=1
else
  echo "SKIP: hadolint not installed (https://github.com/hadolint/hadolint)"
fi

echo ""
if (( rc == 0 )); then
  echo "Security scan suite completed with no blocking findings."
else
  echo "Security scan suite reported findings above." >&2
fi
exit "$rc"
