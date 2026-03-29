#!/usr/bin/env bash
# Description: Run Trivy scans on an image or local filesystem path, output JSON + table
# Usage: ./trivy-scan.sh <image|fs> <target> [--fail-on-critical]
# Env vars: TRIVY_REPORT_DIR (default: /tmp/trivy-reports)

set -euo pipefail

MODE="${1:?Usage: $0 <image|fs> <target> [--fail-on-critical]}"
TARGET="${2:?Target is required (image name or directory path)}"
FAIL_ON_CRITICAL=false
[[ "${3:-}" == "--fail-on-critical" ]] && FAIL_ON_CRITICAL=true

REPORT_DIR="${TRIVY_REPORT_DIR:-/tmp/trivy-reports}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SAFE_TARGET=$(echo "${TARGET}" | tr '/:' '--')
JSON_OUT="${REPORT_DIR}/trivy-${SAFE_TARGET}-${TIMESTAMP}.json"

mkdir -p "${REPORT_DIR}"
log() { echo "[$(date +%H:%M:%S)] $*"; }

log "🔍 Trivy ${MODE} scan: ${TARGET}"

case "${MODE}" in
  image)
    trivy image \
      --format table \
      --severity LOW,MEDIUM,HIGH,CRITICAL \
      "${TARGET}"

    trivy image \
      --format json \
      --output "${JSON_OUT}" \
      --severity LOW,MEDIUM,HIGH,CRITICAL \
      "${TARGET}"
    ;;

  fs)
    trivy fs \
      --format table \
      --severity LOW,MEDIUM,HIGH,CRITICAL \
      "${TARGET}"

    trivy fs \
      --format json \
      --output "${JSON_OUT}" \
      --severity LOW,MEDIUM,HIGH,CRITICAL \
      "${TARGET}"
    ;;

  *)
    echo "❌ Invalid mode. Use 'image' or 'fs'"
    exit 1
    ;;
esac

log "📄 JSON report saved: ${JSON_OUT}"

# Summary
CRITICAL_COUNT=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "${JSON_OUT}" 2>/dev/null || echo 0)
HIGH_COUNT=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "${JSON_OUT}" 2>/dev/null || echo 0)

echo ""
echo "────────────────────────────"
echo "  CRITICAL: ${CRITICAL_COUNT}"
echo "  HIGH:     ${HIGH_COUNT}"
echo "────────────────────────────"

if "${FAIL_ON_CRITICAL}" && [[ "${CRITICAL_COUNT}" -gt 0 ]]; then
  echo "❌ Failing pipeline: ${CRITICAL_COUNT} CRITICAL vulnerabilities found."
  exit 1
fi

log "✅ Scan complete."