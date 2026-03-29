#!/usr/bin/env bash
# Description: Sync an ArgoCD application and wait for healthy status
# Usage: ./argocd-sync.sh <app-name> [--force] [--prune]
# Env vars: ARGOCD_SERVER (required), ARGOCD_AUTH_TOKEN (required)

set -euo pipefail

APP="${1:?Usage: $0 <app-name> [--force] [--prune]}"
FORCE=""
PRUNE=""
TIMEOUT=300

shift
for ARG in "$@"; do
  case "${ARG}" in
    --force) FORCE="--force" ;;
    --prune) PRUNE="--prune" ;;
  esac
done

: "${ARGOCD_SERVER:?ARGOCD_SERVER env var is required}"
: "${ARGOCD_AUTH_TOKEN:?ARGOCD_AUTH_TOKEN env var is required}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

log "🔁 Syncing ArgoCD app: ${APP}"
argocd app sync "${APP}" \
  --server "${ARGOCD_SERVER}" \
  --auth-token "${ARGOCD_AUTH_TOKEN}" \
  --insecure \
  ${FORCE} ${PRUNE}

log "⏳ Waiting for app to become Healthy (timeout: ${TIMEOUT}s)..."
argocd app wait "${APP}" \
  --server "${ARGOCD_SERVER}" \
  --auth-token "${ARGOCD_AUTH_TOKEN}" \
  --insecure \
  --health \
  --timeout "${TIMEOUT}"

log "📊 App status:"
argocd app get "${APP}" \
  --server "${ARGOCD_SERVER}" \
  --auth-token "${ARGOCD_AUTH_TOKEN}" \
  --insecure

log "✅ Sync and health check complete for: ${APP}"