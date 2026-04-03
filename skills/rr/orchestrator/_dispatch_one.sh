#!/bin/bash
# _dispatch_one.sh — Standalone wrapper for dispatching a single sub-agent batch
#
# Replaces the export -f dispatch_subagent pattern for macOS compatibility.
# Called by rr-batch.sh and dispatch.sh via xargs -P.
#
# Usage: _dispatch_one.sh <batch_id>
#
# Required environment variables:
#   WORK_DIR             — Working directory
#   ANTHROPIC_API_KEY    — API key for Claude
#
# Optional environment variables:
#   RR_MODEL             — Claude model (default: claude-sonnet-4-20250514)
#   ANTHROPIC_API_VERSION — API version (default: 2023-06-01)
#   SUBAGENT_TIMEOUT     — Initial timeout in seconds (default: 300)
#   SUBAGENT_MAX_RETRIES — Max retry attempts (default: 3)
#   MAX_RETRIES          — Alternative to SUBAGENT_MAX_RETRIES (for dispatch.sh compat)
#   INITIAL_TIMEOUT      — Alternative to SUBAGENT_TIMEOUT (for dispatch.sh compat)
#   RATE_LIMIT_BACKOFF   — Base backoff for rate limits (default: 30)

set -uo pipefail

batch_id="${1:?Usage: _dispatch_one.sh <batch_id>}"

# Source config from env vars with defaults
WORK_DIR="${WORK_DIR:?WORK_DIR must be set}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY must be set}"

MODEL="${RR_MODEL:-${MODEL:-claude-sonnet-4-20250514}}"
API_VERSION="${ANTHROPIC_API_VERSION:-2023-06-01}"
TIMEOUT="${SUBAGENT_TIMEOUT:-${INITIAL_TIMEOUT:-300}}"
MAX_RETRIES="${SUBAGENT_MAX_RETRIES:-${MAX_RETRIES:-3}}"
RATE_LIMIT_BACKOFF="${RATE_LIMIT_BACKOFF:-30}"

# File paths
payload_file="$WORK_DIR/payloads/payload_${batch_id}.json"
result_file="$WORK_DIR/results/result_${batch_id}.json"
error_file="$WORK_DIR/errors/error_${batch_id}.json"
log_file="$WORK_DIR/logs/dispatch_${batch_id}.log"
retry_queue="$WORK_DIR/retry-queue.txt"

# Ensure directories exist
mkdir -p "$WORK_DIR/results" "$WORK_DIR/errors" "$WORK_DIR/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$log_file"
}

# Verify payload exists
if [ ! -f "$payload_file" ]; then
    log "BATCH_${batch_id}:ERROR:PAYLOAD_NOT_FOUND"
    echo "{\"batch_id\": $batch_id, \"status\": \"error\", \"error\": \"payload_not_found\"}" > "$error_file"
    echo "BATCH_${batch_id}:ERROR:PAYLOAD_NOT_FOUND"
    exit 1
fi

attempt=0
timeout=$TIMEOUT

while [ $attempt -lt $MAX_RETRIES ]; do
    attempt=$((attempt + 1))
    log "BATCH_${batch_id}:ATTEMPT_${attempt}:TIMEOUT_${timeout}s"

    # Make API call
    http_response=$(curl -s -w "\n%{http_code}" \
        -X POST "https://api.anthropic.com/v1/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: $API_VERSION" \
        -d @"$payload_file" \
        --max-time "$timeout" \
        2>&1)

    curl_exit=$?

    # Extract HTTP code (last line) and body (everything else)
    # tr -d '\r' fixes CRLF from curl on some platforms
    http_code=$(echo "$http_response" | tail -n1 | tr -d '\r')
    http_body=$(echo "$http_response" | sed '$d')

    # Handle curl errors
    if [ $curl_exit -ne 0 ]; then
        if [ $curl_exit -eq 28 ]; then
            # Timeout
            if [ $attempt -lt $MAX_RETRIES ]; then
                timeout=$((timeout + 120))
                log "BATCH_${batch_id}:TIMEOUT:RETRY_${attempt}:NEW_TIMEOUT_${timeout}s"
                sleep 5
                continue
            else
                log "BATCH_${batch_id}:FAILED:TIMEOUT_AFTER_RETRIES"
                echo "{\"batch_id\": $batch_id, \"status\": \"error\", \"error\": \"timeout_after_retries\", \"attempts\": $attempt}" > "$error_file"
                echo "BATCH_${batch_id}:FAILED:TIMEOUT"
                exit 1
            fi
        else
            log "BATCH_${batch_id}:FAILED:CURL_ERROR_${curl_exit}"
            echo "{\"batch_id\": $batch_id, \"status\": \"error\", \"error\": \"curl_error_$curl_exit\", \"attempts\": $attempt}" > "$error_file"
            echo "BATCH_${batch_id}:FAILED:CURL_ERROR_$curl_exit"
            exit 1
        fi
    fi

    # Handle HTTP responses
    case "$http_code" in
        200)
            echo "$http_body" > "$result_file"
            log "BATCH_${batch_id}:SUCCESS"
            echo "BATCH_${batch_id}:SUCCESS"
            exit 0
            ;;
        429)
            # Rate limited
            if [ $attempt -lt $MAX_RETRIES ]; then
                sleep_time=$((RATE_LIMIT_BACKOFF * attempt))
                log "BATCH_${batch_id}:RATE_LIMITED:RETRY_${attempt}:SLEEPING_${sleep_time}s"
                sleep $sleep_time
                continue
            else
                log "BATCH_${batch_id}:FAILED:RATE_LIMITED"
                echo "{\"batch_id\": $batch_id, \"status\": \"error\", \"error\": \"rate_limited\", \"attempts\": $attempt}" > "$error_file"
                echo "$batch_id" >> "$retry_queue" 2>/dev/null || true
                echo "BATCH_${batch_id}:FAILED:RATE_LIMITED"
                exit 1
            fi
            ;;
        529|503)
            # Overloaded
            if [ $attempt -lt $MAX_RETRIES ]; then
                sleep_time=$((15 * attempt))
                log "BATCH_${batch_id}:OVERLOADED:RETRY_${attempt}:SLEEPING_${sleep_time}s"
                sleep $sleep_time
                timeout=$((timeout + 60))
                continue
            else
                log "BATCH_${batch_id}:FAILED:OVERLOADED:HTTP_${http_code}"
                echo "{\"batch_id\": $batch_id, \"status\": \"error\", \"error\": \"overloaded\", \"http_code\": $http_code, \"attempts\": $attempt}" > "$error_file"
                echo "$batch_id" >> "$retry_queue" 2>/dev/null || true
                echo "BATCH_${batch_id}:FAILED:OVERLOADED"
                exit 1
            fi
            ;;
        400)
            # Bad request - don't retry
            log "BATCH_${batch_id}:FAILED:BAD_REQUEST"
            echo "{\"batch_id\": $batch_id, \"status\": \"error\", \"error\": \"bad_request\", \"response\": $(echo "$http_body" | jq -c '.' 2>/dev/null || echo "\"$http_body\"")}" > "$error_file"
            echo "BATCH_${batch_id}:FAILED:BAD_REQUEST"
            exit 1
            ;;
        401)
            # Auth error - don't retry
            log "BATCH_${batch_id}:FAILED:AUTH_ERROR"
            echo "{\"batch_id\": $batch_id, \"status\": \"error\", \"error\": \"authentication_failed\"}" > "$error_file"
            echo "BATCH_${batch_id}:FAILED:AUTH_ERROR"
            exit 1
            ;;
        *)
            # Other error
            if [ $attempt -lt $MAX_RETRIES ]; then
                log "BATCH_${batch_id}:HTTP_${http_code}:RETRY_${attempt}"
                sleep 5
                continue
            else
                log "BATCH_${batch_id}:FAILED:HTTP_${http_code}"
                echo "{\"batch_id\": $batch_id, \"status\": \"error\", \"error\": \"http_error\", \"http_code\": $http_code, \"attempts\": $attempt}" > "$error_file"
                echo "BATCH_${batch_id}:FAILED:HTTP_${http_code}"
                exit 1
            fi
            ;;
    esac
done

log "BATCH_${batch_id}:FAILED:MAX_RETRIES"
echo "BATCH_${batch_id}:FAILED:MAX_RETRIES"
exit 1
