#!/usr/bin/env bash
# Description: Manage Kubernetes deployment rollouts — status, rollback, history
# Usage: ./rollout-manager.sh <action> <deployment> [namespace] [revision]
# Actions: status | rollback | history | restart

set -euo pipefail

ACTION="${1:?Usage: $0 <status|rollback|history|restart> <deployment> [namespace] [revision]}"
DEPLOY="${2:?Deployment name required}"
NS="${3:-default}"
REVISION="${4:-}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

case "${ACTION}" in
  status)
    log "📋 Rollout status for ${DEPLOY} (ns: ${NS})"
    kubectl rollout status deployment/"${DEPLOY}" -n "${NS}" --timeout=120s
    echo ""
    kubectl get deployment "${DEPLOY}" -n "${NS}" \
      -o custom-columns="NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image"
    ;;

  rollback)
    if [[ -n "${REVISION}" ]]; then
      log "⏪ Rolling back ${DEPLOY} to revision ${REVISION}..."
      kubectl rollout undo deployment/"${DEPLOY}" -n "${NS}" --to-revision="${REVISION}"
    else
      log "⏪ Rolling back ${DEPLOY} to previous revision..."
      kubectl rollout undo deployment/"${DEPLOY}" -n "${NS}"
    fi
    kubectl rollout status deployment/"${DEPLOY}" -n "${NS}" --timeout=120s
    log "✅ Rollback complete."
    ;;

  history)
    log "📜 Rollout history for ${DEPLOY}:"
    kubectl rollout history deployment/"${DEPLOY}" -n "${NS}"
    ;;

  restart)
    log "🔄 Restarting ${DEPLOY} (rolling restart)..."
    kubectl rollout restart deployment/"${DEPLOY}" -n "${NS}"
    kubectl rollout status deployment/"${DEPLOY}" -n "${NS}" --timeout=180s
    log "✅ Restart complete."
    ;;

  *)
    echo "❌ Unknown action: ${ACTION}. Use: status | rollback | history | restart"
    exit 1
    ;;
esac