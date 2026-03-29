#!/usr/bin/env bash
# Description: Detect drift between Terraform state and actual cloud resources
# Usage: ./tf-drift-detect.sh [workspace]
# Env vars: SLACK_WEBHOOK_URL (optional — posts alert on drift detected)

set -euo pipefail

WORKSPACE="${1:-default}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
DRIFT_FOUND=false

log()  { echo "[$(date +%H:%M:%S)] $*"; }
warn() { echo "⚠️  $*"; }

log "🔧 Initializing..."
terraform init -upgrade -reconfigure -input=false > /dev/null

terraform workspace select "${WORKSPACE}" 2>/dev/null || true

log "🔍 Running terraform plan to check for drift (workspace: ${WORKSPACE})..."

PLAN_OUTPUT=$(terraform plan -detailed-exitcode -refresh=true 2>&1) || EXIT_CODE=$?
EXIT_CODE=${EXIT_CODE:-0}

case "${EXIT_CODE}" in
  0) log "✅ No drift detected. Infrastructure matches state." ;;
  1) echo "❌ Terraform plan failed:" && echo "${PLAN_OUTPUT}" && exit 1 ;;
  2)
    warn "DRIFT DETECTED in workspace: ${WORKSPACE}"
    DRIFT_FOUND=true
    echo "${PLAN_OUTPUT}" | grep -E "^  [+~-]|will be|must be" || true
    ;;
esac

if [[ "${DRIFT_FOUND}" == "true" && -n "${SLACK_WEBHOOK}" ]]; then
  log "📣 Sending Slack alert..."
  curl -s -X POST "${SLACK_WEBHOOK}" \
    -H 'Content-type: application/json' \
    --data "{\"text\":\"⚠️ *Terraform Drift Detected* in workspace \`${WORKSPACE}\`. Run \`terraform plan\` to review changes.\"}"
fi

[[ "${DRIFT_FOUND}" == "true" ]] && exit 2 || exit 0