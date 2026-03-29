#!/usr/bin/env bash
# Description: Dump all key resources in a namespace to a local directory (useful for incident reports)
# Usage: ./ns-dump.sh <namespace> [output-dir]

set -euo pipefail

NS="${1:?Usage: $0 <namespace> [output-dir]}"
OUT_DIR="${2:-/tmp/k8s-dump-${NS}-$(date +%Y%m%d-%H%M%S)}"

RESOURCES=(
  pods deployments replicasets statefulsets daemonsets
  services ingresses configmaps secrets
  persistentvolumeclaims horizontalpodautoscalers
  serviceaccounts rolebindings roles
  events
)

log() { echo "[$(date +%H:%M:%S)] $*"; }

mkdir -p "${OUT_DIR}"
log "📦 Dumping namespace: ${NS} → ${OUT_DIR}"

for RESOURCE in "${RESOURCES[@]}"; do
  FILE="${OUT_DIR}/${RESOURCE}.yaml"
  kubectl get "${RESOURCE}" -n "${NS}" -o yaml > "${FILE}" 2>/dev/null \
    && echo "  ✅ ${RESOURCE}" \
    || echo "  ⚠️  ${RESOURCE} (skipped or empty)"
done

# Pod logs
log "📄 Fetching pod logs..."
PODS=$(kubectl get pods -n "${NS}" --no-headers -o custom-columns=":metadata.name")
mkdir -p "${OUT_DIR}/logs"
for POD in ${PODS}; do
  kubectl logs "${POD}" -n "${NS}" --all-containers --tail=200 \
    > "${OUT_DIR}/logs/${POD}.log" 2>/dev/null || true
done

# Summary
log "📊 Resource counts:"
kubectl get all -n "${NS}" 2>/dev/null | awk 'NR>1 {print "  "$0}'

log "✅ Dump complete: ${OUT_DIR}"
echo "  Total files: $(find "${OUT_DIR}" -type f | wc -l)"