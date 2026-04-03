#!/bin/bash
# retry.sh — Retry failed batches with increased timeout (macOS-adapted)
#
# Usage: ./retry.sh [max_timeout]
#
# Reads retry queue from $WORK_DIR/retry-queue.txt
# Uses increased timeout and sequential execution to avoid rate limits

set -uo pipefail

WORK_DIR="${RR_WORK_DIR:-${HOME}/rr-work}"
RETRY_QUEUE="$WORK_DIR/retry-queue.txt"
PAYLOADS_DIR="$WORK_DIR/payloads"
RESULTS_DIR="$WORK_DIR/results"
ERRORS_DIR="$WORK_DIR/errors"
RETRY_LOG="$WORK_DIR/retry.log"

MAX_TIMEOUT=${1:-600}
RETRY_DELAY=30

MODEL="${RR_MODEL:-claude-sonnet-4-20250514}"
API_VERSION="${ANTHROPIC_API_VERSION:-2023-06-01}"

: > "$RETRY_LOG"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$RETRY_LOG"
}

if [ ! -f "$RETRY_QUEUE" ] || [ ! -s "$RETRY_QUEUE" ]; then
    echo "No batches in retry queue"
    exit 0
fi

retry_count=$(wc -l < "$RETRY_QUEUE" | tr -d ' ')
log "RETRY_START:BATCHES_${retry_count}:MAX_TIMEOUT_${MAX_TIMEOUT}s"

succeeded=0
failed=0

while read -r batch_id; do
    [ -z "$batch_id" ] && continue

    payload_file="$PAYLOADS_DIR/payload_${batch_id}.json"
    result_file="$RESULTS_DIR/result_${batch_id}.json"
    error_file="$ERRORS_DIR/error_${batch_id}.json"

    if [ ! -f "$payload_file" ]; then
        log "BATCH_${batch_id}:SKIP:PAYLOAD_NOT_FOUND"
        failed=$((failed + 1))
        continue
    fi

    log "BATCH_${batch_id}:RETRY:TIMEOUT_${MAX_TIMEOUT}s"

    # Remove previous error file
    rm -f "$error_file"

    http_response=$(curl -s -w "\n%{http_code}" \
        -X POST "https://api.anthropic.com/v1/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: $API_VERSION" \
        -d @"$payload_file" \
        --max-time "$MAX_TIMEOUT" \
        2>&1)

    curl_exit=$?
    http_code=$(echo "$http_response" | tail -n1 | tr -d '\r')
    http_body=$(echo "$http_response" | sed '$d')

    if [ $curl_exit -eq 0 ] && [ "$http_code" = "200" ]; then
        echo "$http_body" > "$result_file"
        log "BATCH_${batch_id}:RETRY_SUCCESS"
        succeeded=$((succeeded + 1))
    else
        log "BATCH_${batch_id}:RETRY_FAILED:CURL_${curl_exit}:HTTP_${http_code}"
        echo "{\"batch_id\": $batch_id, \"status\": \"error\", \"error\": \"retry_failed\", \"curl_exit\": $curl_exit, \"http_code\": \"$http_code\"}" > "$error_file"
        failed=$((failed + 1))
    fi

    # Delay between retries to avoid rate limits
    log "SLEEPING_${RETRY_DELAY}s"
    sleep "$RETRY_DELAY"

done < "$RETRY_QUEUE"

log "RETRY_COMPLETE:SUCCEEDED_${succeeded}:FAILED_${failed}"

# Clear retry queue if all succeeded
if [ $failed -eq 0 ]; then
    : > "$RETRY_QUEUE"
    log "RETRY_QUEUE_CLEARED"
fi

echo "RETRY_COMPLETE:SUCCEEDED_${succeeded}:FAILED_${failed}"
