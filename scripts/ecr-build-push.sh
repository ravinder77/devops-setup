#!/usr/bin/env bash
# Description: Build a Docker image, push to ECR, and run Trivy scan
# Usage: ./ecr-build-push.sh <image-name> <tag> [dockerfile-path]
# Env vars: AWS_REGION, AWS_ACCOUNT_ID, AWS_PROFILE (optional)

set -euo pipefail

IMAGE="${1:?Usage: $0 <image-name> <tag> [dockerfile-path]}"
TAG="${2:?Tag is required (e.g. git SHA or semver)}"
DOCKERFILE="${3:-.}"

: "${AWS_REGION:?AWS_REGION is required}"
: "${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID is required}"

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE="${ECR_REGISTRY}/${IMAGE}:${TAG}"
PROFILE_ARG="${AWS_PROFILE:+--profile ${AWS_PROFILE}}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

log "🔐 Logging into ECR: ${ECR_REGISTRY}"
aws ecr get-login-password --region "${AWS_REGION}" ${PROFILE_ARG} \
  | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

log "🏗️  Building image: ${FULL_IMAGE}"
docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  -t "${FULL_IMAGE}" \
  -f "${DOCKERFILE}/Dockerfile" \
  "${DOCKERFILE}" \
  --push

log "📦 Image pushed: ${FULL_IMAGE}"

# Run Trivy scan if available
if command -v trivy &>/dev/null; then
  log "🔍 Running Trivy vulnerability scan..."
  trivy image \
    --exit-code 1 \
    --severity HIGH,CRITICAL \
    --no-progress \
    "${FULL_IMAGE}" || {
      echo "❌ Trivy found HIGH/CRITICAL vulnerabilities. Review before deploying."
      exit 1
    }
  log "✅ Trivy scan passed."
else
  echo "⚠️  trivy not found — skipping vulnerability scan"
fi

log "✅ Done: ${FULL_IMAGE}"