#!/usr/bin/env bash
# Description: Trigger a Jenkins job via REST API and tail its console output
# Usage: ./jenkins-trigger.sh <job-name> [param1=val1 param2=val2 ...]
# Env vars: JENKINS_URL, JENKINS_USER, JENKINS_TOKEN (all required)

set -euo pipefail

JOB="${1:?Usage: $0 <job-name> [key=value ...]}"
shift
PARAMS=("$@")

: "${JENKINS_URL:?JENKINS_URL is required (e.g. https://jenkins.example.com)}"
: "${JENKINS_USER:?JENKINS_USER is required}"
: "${JENKINS_TOKEN:?JENKINS_TOKEN is required}"

AUTH="${JENKINS_USER}:${JENKINS_TOKEN}"
log() { echo "[$(date +%H:%M:%S)] $*"; }

# Build query string from params
QUERY=""
for P in "${PARAMS[@]+"${PARAMS[@]}"}"; do
  QUERY+="&${P}"
done

# Trigger the job
TRIGGER_URL="${JENKINS_URL}/job/${JOB}/buildWithParameters?token=trigger${QUERY}"
log "🚀 Triggering job: ${JOB}"
QUEUE_RESP=$(curl -s -i -X POST "${TRIGGER_URL}" -u "${AUTH}")
QUEUE_LOCATION=$(echo "${QUEUE_RESP}" | grep -i "^Location:" | tr -d '\r' | awk '{print $2}')
[[ -z "${QUEUE_LOCATION}" ]] && { echo "❌ Failed to queue job. Response:"; echo "${QUEUE_RESP}"; exit 1; }

log "📥 Queued at: ${QUEUE_LOCATION}"
log "⏳ Waiting for build to start..."

BUILD_URL=""
for i in $(seq 1 30); do
  QUEUE_INFO=$(curl -s -u "${AUTH}" "${QUEUE_LOCATION}api/json")
  BUILD_URL=$(echo "${QUEUE_INFO}" | jq -r '.executable.url // empty')
  [[ -n "${BUILD_URL}" ]] && break
  sleep 3
done

[[ -z "${BUILD_URL}" ]] && { echo "❌ Build did not start within 90s"; exit 1; }
log "🏗️  Build started: ${BUILD_URL}"

# Poll for completion
log "📺 Tailing console output..."
LOG_START=0
while true; do
  CONSOLE=$(curl -s -u "${AUTH}" "${BUILD_URL}logText/progressiveText?start=${LOG_START}")
  echo -n "${CONSOLE}" | head -c -1  # strip trailing newline weirdness
  LOG_START=$(curl -s -I -u "${AUTH}" "${BUILD_URL}logText/progressiveText?start=${LOG_START}" \
              | grep -i "X-Text-Size" | tr -d '\r' | awk '{print $2}')

  BUILD_INFO=$(curl -s -u "${AUTH}" "${BUILD_URL}api/json")
  BUILDING=$(echo "${BUILD_INFO}" | jq -r '.building')
  [[ "${BUILDING}" == "false" ]] && break
  sleep 5
done

RESULT=$(curl -s -u "${AUTH}" "${BUILD_URL}api/json" | jq -r '.result')
log "🏁 Build result: ${RESULT}"
[[ "${RESULT}" == "SUCCESS" ]] || exit 1