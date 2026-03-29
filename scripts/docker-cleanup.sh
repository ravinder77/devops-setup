#!/usr/bin/env bash
# Description: Clean up Docker resources — dangling images, stopped containers, unused volumes
# Usage: ./docker-cleanup.sh [--all] [--dry-run]
# Flags: --all (also removes unused networks and build cache), --dry-run (show what would be removed)

set -euo pipefail

ALL=false
DRY_RUN=false

for ARG in "$@"; do
  case "${ARG}" in
    --all)     ALL=true ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

log()     { echo "[$(date +%H:%M:%S)] $*"; }
execute() { "${DRY_RUN}" && echo "  [DRY-RUN] $*" || eval "$*"; }

log "🐳 Docker Cleanup $(${DRY_RUN} && echo "(DRY RUN)" || true)"
echo ""

log "🧹 Stopped containers:"
STOPPED=$(docker ps -aq --filter "status=exited" --filter "status=created")
if [[ -n "${STOPPED}" ]]; then
  echo "${STOPPED}" | xargs -r docker inspect --format '  {{.Name}} ({{.State.Status}})' 2>/dev/null || true
  execute "echo '${STOPPED}' | xargs -r docker rm"
else
  echo "  None found."
fi

log "🗑️  Dangling images:"
DANGLING=$(docker images -qf "dangling=true")
if [[ -n "${DANGLING}" ]]; then
  docker images --filter "dangling=true" --format "  {{.Repository}}:{{.Tag}} ({{.Size}})"
  execute "echo '${DANGLING}' | xargs -r docker rmi"
else
  echo "  None found."
fi

log "💾 Unused volumes:"
execute "docker volume prune -f"

if "${ALL}"; then
  log "🌐 Unused networks:"
  execute "docker network prune -f"

  log "🏗️  Build cache:"
  execute "docker buildx prune -f"
fi

log "✅ Cleanup complete."
docker system df