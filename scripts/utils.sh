#!/usr/bin/env bash
# Description: Reusable bash utility functions — source this file in other scripts
# Usage: source ./utils.sh
# Available: retry, wait_for_url, wait_for_pod, require_tools, confirm, hr

# ─── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${BLUE}[$(date +%H:%M:%S)]${RESET} $*"; }
success() { echo -e "${GREEN}✅ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠️  $*${RESET}"; }
error()   { echo -e "${RED}❌ $*${RESET}" >&2; }
hr()      { echo "────────────────────────────────────────"; }

# ─── retry <attempts> <delay_seconds> <command...> ─────────────────────────────
retry() {
  local attempts="${1}"; local delay="${2}"; shift 2
  local i=0
  until "$@"; do
    ((i++))
    [[ "${i}" -ge "${attempts}" ]] && { error "Command failed after ${attempts} attempts: $*"; return 1; }
    warn "Attempt ${i}/${attempts} failed. Retrying in ${delay}s..."
    sleep "${delay}"
  done
}

# ─── wait_for_url <url> [timeout_seconds] ──────────────────────────────────────
wait_for_url() {
  local url="${1}"; local timeout="${2:-60}"; local elapsed=0
  log "Waiting for ${url} (timeout: ${timeout}s)..."
  until curl -sf --max-time 5 "${url}" &>/dev/null; do
    sleep 5; elapsed=$((elapsed + 5))
    [[ "${elapsed}" -ge "${timeout}" ]] && { error "Timed out waiting for ${url}"; return 1; }
    echo -n "."
  done
  echo ""; success "${url} is reachable."
}

# ─── wait_for_pod <name-or-partial> <namespace> [timeout_seconds] ──────────────
wait_for_pod() {
  local search="${1}"; local ns="${2:-default}"; local timeout="${3:-120}"
  log "Waiting for pod matching '${search}' in ns '${ns}' to be Ready..."
  kubectl wait pod \
    --for=condition=Ready \
    --selector="$(kubectl get pod -n "${ns}" --no-headers -o custom-columns=":metadata.name" \
      | grep "${search}" | head -1 | xargs -I{} kubectl get pod {} -n "${ns}" \
      -o jsonpath='{.metadata.labels}' | jq -r 'to_entries[0] | "\(.key)=\(.value)"')" \
    -n "${ns}" \
    --timeout="${timeout}s"
}

# ─── require_tools <tool1> [tool2 ...] ────────────────────────────────────────
require_tools() {
  local missing=()
  for tool in "$@"; do
    command -v "${tool}" &>/dev/null || missing+=("${tool}")
  done
  if [[ "${#missing[@]}" -gt 0 ]]; then
    error "Missing required tools: ${missing[*]}"
    exit 1
  fi
}

# ─── confirm <message> ────────────────────────────────────────────────────────
confirm() {
  local msg="${1:-Are you sure?}"
  echo -e "${YELLOW}${msg}${RESET}"
  read -rp "Type 'yes' to continue: " REPLY
  [[ "${REPLY}" == "yes" ]] || { warn "Aborted."; exit 0; }
}

# ─── elapsed_time <start_epoch> ───────────────────────────────────────────────
elapsed_time() {
  local start="${1}"; local end; end=$(date +%s)
  local secs=$(( end - start ))
  printf "%dm %ds" $(( secs / 60 )) $(( secs % 60 ))
}