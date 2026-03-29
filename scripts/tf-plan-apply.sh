#!/usr/bin/env bash
# Description: Run terraform plan and optionally apply with a confirmation gate
# Usage: ./tf-plan-apply.sh <workspace> [apply]
# Env vars: TF_VAR_FILE (optional), AWS_PROFILE (optional)

set -euo pipefail

WORKSPACE="${1:-default}"
ACTION="${2:-plan}"
VAR_FILE="${TF_VAR_FILE:-terraform.tfvars}"
PLAN_FILE="/tmp/tf-${WORKSPACE}-$(date +%Y%m%d%H%M%S).plan"

log()  { echo "[$(date +%H:%M:%S)] $*"; }
abort(){ echo "❌ $*" >&2; exit 1; }

[[ -f "$(which terraform)" ]] || abort "terraform not found in PATH"

log "🔧 Initializing Terraform..."
terraform init -upgrade -reconfigure

log "🔀 Selecting workspace: ${WORKSPACE}"
terraform workspace select "${WORKSPACE}" 2>/dev/null || terraform workspace new "${WORKSPACE}"

EXTRA_ARGS=()
[[ -f "${VAR_FILE}" ]] && EXTRA_ARGS+=("-var-file=${VAR_FILE}")

log "📋 Running terraform plan..."
terraform plan "${EXTRA_ARGS[@]}" -out="${PLAN_FILE}"

if [[ "${ACTION}" == "apply" ]]; then
  echo ""
  echo "⚠️  You are about to apply the above plan to workspace: ${WORKSPACE}"
  read -rp "Type 'yes' to confirm: " CONFIRM
  [[ "${CONFIRM}" == "yes" ]] || abort "Apply cancelled by user."

  log "🚀 Applying plan..."
  terraform apply "${PLAN_FILE}"
  log "✅ Apply complete."
else
  log "ℹ️  Plan saved to ${PLAN_FILE}. Pass 'apply' as second arg to apply."
fi