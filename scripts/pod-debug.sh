#!/usr/bin/env bash
# Description: One-shot pod debugger — describe, events, logs, and resource usage
# Usage: ./pod-debug.sh <pod-name-or-partial> [namespace]
# Tip: Partial name works — script finds the first matching pod

set -euo pipefail

SEARCH="${1:?Usage: $0 <pod-name-or-partial> [namespace]}"
NS="${2:-default}"
DIVIDER="─────────────────────────────────────────────"

log()     { echo -e "\n\033[1;34m${DIVIDER}\n  $*\n${DIVIDER}\033[0m"; }
warning() { echo -e "\033[1;33m⚠️  $*\033[0m"; }

# Resolve partial pod name
POD=$(kubectl get pods -n "${NS}" --no-headers -o custom-columns=":metadata.name" \
      | grep "${SEARCH}" | head -1)

[[ -z "${POD}" ]] && { echo "❌ No pod matching '${SEARCH}' in namespace '${NS}'"; exit 1; }
echo "🔍 Debugging pod: ${POD} (namespace: ${NS})"

log "📋 DESCRIBE"
kubectl describe pod "${POD}" -n "${NS}"

log "📜 EVENTS (last 20)"
kubectl get events -n "${NS}" --field-selector involvedObject.name="${POD}" \
  --sort-by='.lastTimestamp' | tail -20

log "📦 CONTAINERS"
CONTAINERS=$(kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.spec.containers[*].name}')
echo "Containers: ${CONTAINERS}"

for CONTAINER in ${CONTAINERS}; do
  log "📄 LOGS — ${CONTAINER} (last 50 lines)"
  kubectl logs "${POD}" -n "${NS}" -c "${CONTAINER}" --tail=50 || warning "Could not fetch logs for ${CONTAINER}"

  PREV_LOGS=$(kubectl logs "${POD}" -n "${NS}" -c "${CONTAINER}" --previous --tail=20 2>/dev/null || true)
  if [[ -n "${PREV_LOGS}" ]]; then
    log "💀 PREVIOUS CONTAINER LOGS — ${CONTAINER}"
    echo "${PREV_LOGS}"
  fi
done

log "📊 RESOURCE USAGE"
kubectl top pod "${POD}" -n "${NS}" --containers 2>/dev/null || warning "metrics-server not available"