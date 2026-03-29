#!/usr/bin/env bash
# Description: Sign and verify container images using Cosign (keyless or key-based)
# Usage: ./cosign-sign-verify.sh <sign|verify> <image-with-digest>
# Env vars: COSIGN_KEY (optional, path to .key file — uses keyless OIDC if unset)
#           COSIGN_PASSWORD (required if COSIGN_KEY is set)

set -euo pipefail

ACTION="${1:?Usage: $0 <sign|verify> <image>}"
IMAGE="${2:?Image (with digest) is required — e.g. 123456.dkr.ecr.us-east-1.amazonaws.com/app@sha256:abc}"

COSIGN_KEY="${COSIGN_KEY:-}"
log() { echo "[$(date +%H:%M:%S)] $*"; }

case "${ACTION}" in
  sign)
    if [[ -n "${COSIGN_KEY}" ]]; then
      log "🔏 Signing image with key: ${COSIGN_KEY}"
      : "${COSIGN_PASSWORD:?COSIGN_PASSWORD is required when using key-based signing}"
      COSIGN_PASSWORD="${COSIGN_PASSWORD}" cosign sign \
        --key "${COSIGN_KEY}" \
        --yes \
        "${IMAGE}"
    else
      log "🔏 Signing image (keyless / OIDC)..."
      cosign sign \
        --yes \
        "${IMAGE}"
    fi
    log "✅ Image signed: ${IMAGE}"
    ;;

  verify)
    if [[ -n "${COSIGN_KEY}" ]]; then
      log "🔎 Verifying signature with key: ${COSIGN_KEY}"
      cosign verify \
        --key "${COSIGN_KEY}" \
        "${IMAGE}" | jq '.[0] | {subject: .critical.identity, image: .critical.image}'
    else
      CERT_IDENTITY="${COSIGN_CERT_IDENTITY:?Set COSIGN_CERT_IDENTITY for keyless verify}"
      CERT_OIDC_ISSUER="${COSIGN_CERT_OIDC_ISSUER:?Set COSIGN_CERT_OIDC_ISSUER for keyless verify}"
      log "🔎 Verifying image (keyless)..."
      cosign verify \
        --certificate-identity "${CERT_IDENTITY}" \
        --certificate-oidc-issuer "${CERT_OIDC_ISSUER}" \
        "${IMAGE}" | jq '.[0] | {subject: .critical.identity, image: .critical.image}'
    fi
    log "✅ Signature verified."
    ;;

  *)
    echo "❌ Unknown action. Use: sign | verify"
    exit 1
    ;;
esac