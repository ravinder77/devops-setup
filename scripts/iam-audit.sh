#!/usr/bin/env bash
# Description: Audit IAM roles for wildcard actions (*) and admin-level policies
# Usage: ./iam-audit.sh [role-name-prefix]
# Env vars: AWS_PROFILE (optional), AWS_REGION (optional)

set -euo pipefail

PREFIX="${1:-}"
PROFILE_ARG="${AWS_PROFILE:+--profile ${AWS_PROFILE}}"
REGION="${AWS_REGION:-ap-south-1}"
RISKY_FOUND=false

log()   { echo "[$(date +%H:%M:%S)] $*"; }
warn()  { echo "  ⚠️  $*"; RISKY_FOUND=true; }

log "🔍 Fetching IAM roles${PREFIX:+ matching prefix: ${PREFIX}}..."

ROLES=$(aws iam list-roles ${PROFILE_ARG} \
  --query "Roles[?starts_with(RoleName, '${PREFIX}')].RoleName" \
  --output text)

[[ -z "${ROLES}" ]] && { echo "No roles found."; exit 0; }

echo ""
for ROLE in ${ROLES}; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔐 Role: ${ROLE}"

  # Attached managed policies
  ATTACHED=$(aws iam list-attached-role-policies ${PROFILE_ARG} \
    --role-name "${ROLE}" \
    --query "AttachedPolicies[*].PolicyName" --output text)

  for POLICY in ${ATTACHED}; do
    [[ "${POLICY}" == "AdministratorAccess" ]] && warn "${ROLE} has AdministratorAccess!"
    [[ "${POLICY}" == "PowerUserAccess" ]]     && warn "${ROLE} has PowerUserAccess!"
    echo "    📎 Managed: ${POLICY}"
  done

  # Inline policies — check for wildcard actions
  INLINE_POLICIES=$(aws iam list-role-policies ${PROFILE_ARG} \
    --role-name "${ROLE}" --query "PolicyNames" --output text)

  for IPOLICY in ${INLINE_POLICIES}; do
    echo "    📝 Inline: ${IPOLICY}"
    DOC=$(aws iam get-role-policy ${PROFILE_ARG} \
      --role-name "${ROLE}" --policy-name "${IPOLICY}" \
      --query "PolicyDocument" --output json)

    WILDCARDS=$(echo "${DOC}" | jq -r '.Statement[] | select(.Effect=="Allow") | .Action | if type=="array" then .[] else . end | select(. == "*" or test("^[a-z]+:\\*$"))')
    [[ -n "${WILDCARDS}" ]] && warn "Wildcard actions in ${IPOLICY}: ${WILDCARDS}"
  done
done

echo ""
if "${RISKY_FOUND}"; then
  log "⚠  Risky permissions found — review roles above."
  exit 1
else
  log "✅ No obvious over-permissive policies found."
fi