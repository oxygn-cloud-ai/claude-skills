#!/bin/bash
# _publish_one.sh — Standalone wrapper for publishing a single review to Jira
#
# Replaces the export -f publish_review pattern for macOS compatibility.
# Called by rr-batch.sh via xargs -P.
#
# Usage: _publish_one.sh <risk_key>
#
# Required environment variables:
#   WORK_DIR         — Working directory
#   JIRA_BASE_URL    — Jira instance URL
#   JIRA_AUTH        — Base64-encoded Jira auth (email:token)
#   PROJECT_KEY      — Jira project key (e.g. RR)

set -uo pipefail

risk_key="${1:?Usage: _publish_one.sh <risk_key>}"

# Source config from env vars
WORK_DIR="${WORK_DIR:?WORK_DIR must be set}"
JIRA_BASE_URL="${JIRA_BASE_URL:?JIRA_BASE_URL must be set}"
JIRA_AUTH="${JIRA_AUTH:?JIRA_AUTH must be set}"
PROJECT_KEY="${PROJECT_KEY:?PROJECT_KEY must be set}"

# File paths
assessment_file="$WORK_DIR/individual/${risk_key}.json"
result_file="$WORK_DIR/jira-results/${risk_key}.json"
error_file="$WORK_DIR/jira-errors/${risk_key}.json"
log_file="$WORK_DIR/logs/publish_${risk_key}.log"

# Ensure directories exist
mkdir -p "$WORK_DIR/jira-results" "$WORK_DIR/jira-errors" "$WORK_DIR/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$log_file"
}

# Check assessment exists
if [ ! -f "$assessment_file" ]; then
    log "${risk_key}:SKIP:NO_ASSESSMENT"
    echo "${risk_key}:SKIP:NO_ASSESSMENT"
    exit 1
fi

log "${risk_key}:PUBLISHING"

# Extract Jira description from assessment
jira_desc=$(jq -r '.jira_description // .assessment.sections.context.narrative // "Assessment completed"' "$assessment_file")
summary="Risk Review -- $(date +%Y-%m-%d)"

# Create ADF description
adf_desc=$(jq -n --arg text "$jira_desc" '{
    type: "doc",
    version: 1,
    content: [{
        type: "paragraph",
        content: [{type: "text", text: $text}]
    }]
}')

# Build Jira payload
payload=$(jq -n \
    --arg project "$PROJECT_KEY" \
    --arg parent "$risk_key" \
    --arg summary "$summary" \
    --argjson desc "$adf_desc" \
    '{
        fields: {
            project: {key: $project},
            issuetype: {name: "Review"},
            parent: {key: $parent},
            summary: $summary,
            description: $desc
        }
    }')

# Create Jira issue
response=$(curl -s -w "\n%{http_code}" -X POST "$JIRA_BASE_URL/rest/api/3/issue" \
    -H "Authorization: Basic $JIRA_AUTH" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    --max-time 30 2>&1)

# Extract HTTP code and body (tr -d '\r' for CRLF fix)
http_code=$(echo "$response" | tail -n1 | tr -d '\r')
http_body=$(echo "$response" | sed '$d')

if [ "$http_code" = "201" ]; then
    echo "$http_body" > "$result_file"
    new_key=$(echo "$http_body" | jq -r '.key')
    log "${risk_key}:SUCCESS:${new_key}"
    echo "${risk_key}:SUCCESS:${new_key}"
    exit 0
else
    jq -n --arg code "http_$http_code" --arg body "$http_body" '{error: $code, response: $body}' > "$error_file" 2>/dev/null || \
        echo "{\"error\": \"http_$http_code\", \"response\": \"parse_error\"}" > "$error_file"
    log "${risk_key}:FAILED:HTTP_$http_code"
    echo "${risk_key}:FAILED:HTTP_$http_code"
    exit 1
fi
