#!/usr/bin/env bash
# Description: Update kubeconfig for an EKS cluster and optionally switch context
# Usage: ./eks-kubeconfig.sh <cluster-name> <region> [aws-profile]
# Env vars: AWS_PROFILE (optional, overridden by arg3)

set -euo pipefail

CLUSTER="${1:?Usage: $0 <cluster-name> <region> [aws-profile]}"
REGION="${2:?Usage: $0 <cluster-name> <region> [aws-profile]}"
AWS_PROFILE="${3:-${AWS_PROFILE:-default}}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

log "🔐 Using AWS profile: ${AWS_PROFILE}"
log "📡 Updating kubeconfig for cluster: ${CLUSTER} in ${REGION}..."

aws eks update-kubeconfig \
  --name "${CLUSTER}" \
  --region "${REGION}" \
  --profile "${AWS_PROFILE}" \
  --alias "${CLUSTER}"

log "🔀 Switching kubectl context to: ${CLUSTER}"
kubectl config use-context "${CLUSTER}"

log "✅ Context switched. Cluster info:"
kubectl cluster-info
echo ""
log "🖥️  Nodes:"
kubectl get nodes -o wide