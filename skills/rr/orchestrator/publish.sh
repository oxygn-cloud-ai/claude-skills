#!/bin/bash
# publish.sh — Parallel Jira ticket creation (macOS-adapted)
#
# Usage: ./publish.sh
#
# Requires:
#   - JIRA_CLOUD_ID environment variable
#   - Jira payloads in $WORK_DIR/jira-payloads/
#   - Uses Atlassian MCP tools via orchestrator
#
# Note: This script generates the commands; actual execution happens via orchestrator

set -uo pipefail

WORK_DIR="${RR_WORK_DIR:-${HOME}/rr-work}"
JIRA_PAYLOADS_DIR="$WORK_DIR/jira-payloads"
PUBLISH_RESULTS_DIR="$WORK_DIR/publish-results"
PUBLISH_ERRORS_DIR="$WORK_DIR/publish-errors"
PUBLISH_LOG="$WORK_DIR/publish.log"

JIRA_CLOUD_ID="${JIRA_CLOUD_ID:-81a55da4-28c8-4a49-8a47-03a98a73f152}"
MAX_PARALLEL=50
MAX_RETRIES=3

mkdir -p "$PUBLISH_RESULTS_DIR" "$PUBLISH_ERRORS_DIR"
: > "$PUBLISH_LOG"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$PUBLISH_LOG"
}

# Note: Jira API calls will be made via the Atlassian MCP tool from the orchestrator
# This script prepares payloads and validates results

# Check for payloads
if [ ! -d "$JIRA_PAYLOADS_DIR" ] || [ -z "$(ls -A "$JIRA_PAYLOADS_DIR" 2>/dev/null)" ]; then
    echo "ERROR: No Jira payloads found in $JIRA_PAYLOADS_DIR"
    exit 1
fi

payload_count=$(ls "$JIRA_PAYLOADS_DIR" | grep -c '\.json$' || echo 0)
log "PUBLISH_START:PAYLOADS_${payload_count}"

# Generate manifest for orchestrator
manifest_file="$WORK_DIR/publish-manifest.json"

# Build manifest using jq for safe JSON construction
payloads_json="[]"
for payload_file in "$JIRA_PAYLOADS_DIR"/*.json; do
    [ -f "$payload_file" ] || continue
    risk_key=$(basename "$payload_file" .json | sed 's/jira_//')
    payloads_json=$(echo "$payloads_json" | jq --arg rk "$risk_key" --arg pf "$payload_file" '. + [{risk_key: $rk, payload_file: $pf}]')
done

jq -n \
    --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --arg cloud "$JIRA_CLOUD_ID" \
    --argjson count "$payload_count" \
    --argjson payloads "$payloads_json" \
    '{timestamp: $ts, cloud_id: $cloud, total_payloads: $count, payloads: $payloads}' \
    > "$manifest_file"

log "MANIFEST_CREATED:$manifest_file"

echo "PUBLISH_MANIFEST_READY:$manifest_file"
echo ""
echo "Orchestrator should now iterate through manifest and call Atlassian:createJiraIssue for each payload."
echo ""
echo "For each successful creation, save result to: $PUBLISH_RESULTS_DIR/<risk_key>.json"
echo "For each failure, save error to: $PUBLISH_ERRORS_DIR/<risk_key>.json"
