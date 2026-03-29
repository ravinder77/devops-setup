#!/usr/bin/env bash
# Description: Manage Terraform workspaces — list, create, switch, delete
# Usage: ./tf-workspace.sh <list|create|switch|delete> [workspace-name]

set -euo pipefail

ACTION="${1:?Usage: $0 <list|create|switch|delete> [workspace-name]}"
NAME="${2:-}"

log()  { echo "[$(date +%H:%M:%S)] $*"; }
abort(){ echo "❌ $*" >&2; exit 1; }

case "${ACTION}" in
  list)
    log "📋 Terraform workspaces:"
    terraform workspace list
    ;;

  create)
    [[ -z "${NAME}" ]] && abort "Workspace name required for create"
    log "➕ Creating workspace: ${NAME}"
    terraform workspace new "${NAME}"
    log "✅ Workspace '${NAME}' created and selected."
    ;;

  switch)
    [[ -z "${NAME}" ]] && abort "Workspace name required for switch"
    log "🔀 Switching to workspace: ${NAME}"
    terraform workspace select "${NAME}"
    log "✅ Now in workspace: $(terraform workspace show)"
    ;;

  delete)
    [[ -z "${NAME}" ]] && abort "Workspace name required for delete"
    [[ "${NAME}" == "default" ]] && abort "Cannot delete the 'default' workspace."
    CURRENT=$(terraform workspace show)
    [[ "${CURRENT}" == "${NAME}" ]] && {
      log "Switching to default before deletion..."
      terraform workspace select default
    }
    log "🗑️  Deleting workspace: ${NAME}"
    terraform workspace delete "${NAME}"
    log "✅ Workspace '${NAME}' deleted."
    ;;

  *)
    abort "Unknown action: ${ACTION}. Use: list | create | switch | delete"
    ;;
esac