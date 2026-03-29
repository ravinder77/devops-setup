#!/usr/bin/env bash
# Description: Validate Prometheus alert rule YAML files using promtool
# Usage: ./validate-alerts.sh [rules-dir]
# Env vars: PROMETHEUS_URL (optional — also runs live check via API)

set -euo pipefail

RULES_DIR="${1:-./rules}"
PROMETHEUS_URL="${PROMETHEUS_URL:-}"
PASS=0
FAIL=0

log()   { echo "[$(date +%H:%M:%S)] $*"; }
ok()    { echo "  ✅ $*"; ((PASS++)); }
fail()  { echo "  ❌ $*"; ((FAIL++)); }

command -v promtool &>/dev/null || { echo "❌ promtool not found. Install prometheus package."; exit 1; }

[[ -d "${RULES_DIR}" ]] || { echo "❌ Rules directory not found: ${RULES_DIR}"; exit 1; }

log "🔍 Validating alert rules in: ${RULES_DIR}"
echo ""

while IFS= read -r -d '' RULEFILE; do
  echo "📄 ${RULEFILE}"
  if promtool check rules "${RULEFILE}" 2>&1 | grep -q "SUCCESS"; then
    ok "Syntax valid"
  else
    fail "Syntax error in ${RULEFILE}"
    promtool check rules "${RULEFILE}" || true
  fi
done < <(find "${RULES_DIR}" -name "*.yml" -o -name "*.yaml" -print0)

# Optional: check firing alerts via API
if [[ -n "${PROMETHEUS_URL}" ]]; then
  echo ""
  log "🔥 Currently firing alerts (${PROMETHEUS_URL}):"
  curl -s "${PROMETHEUS_URL}/api/v1/alerts" \
    | jq -r '.data.alerts[] | select(.state=="firing") | "  🔴 \(.labels.alertname) — \(.labels.severity // "unknown") — \(.annotations.summary // "")"' \
    || echo "  Could not reach Prometheus API"
fi

echo ""
echo "────────────────────────"
echo "  Passed: ${PASS}"
echo "  Failed: ${FAIL}"
echo "────────────────────────"

[[ "${FAIL}" -eq 0 ]] || exit 1
log "✅ All rules valid."