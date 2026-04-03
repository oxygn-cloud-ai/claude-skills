#!/bin/bash
# _dispatch_one.sh — Dispatch a single sub-agent batch with tool-use progress reporting
#
# Implements a tool-use loop: the sub-agent calls report_progress after each risk,
# we write a progress file and send tool_result back. Loop until end_turn.
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

# Tool-use loop settings
MAX_TOOL_ITERATIONS=15
LOOP_TIMEOUT=900
CONTINUATION_TIMEOUT=120

# File paths
payload_file="$WORK_DIR/payloads/payload_${batch_id}.json"
result_file="$WORK_DIR/results/result_${batch_id}.json"
error_file="$WORK_DIR/errors/error_${batch_id}.json"
log_file="$WORK_DIR/logs/dispatch_${batch_id}.log"
progress_dir="$WORK_DIR/progress"
retry_queue="$WORK_DIR/retry-queue.txt"

# Ensure directories exist
mkdir -p "$WORK_DIR/results" "$WORK_DIR/errors" "$WORK_DIR/logs" "$progress_dir"

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

#=============================================================================
# API CALL WITH RETRY
#=============================================================================

api_call() {
    local payload="$1"
    local timeout="$2"
    local attempt=0

    while [ $attempt -lt $MAX_RETRIES ]; do
        attempt=$((attempt + 1))

        http_response=$(curl -s -w "\n%{http_code}" \
            -X POST "https://api.anthropic.com/v1/messages" \
            -H "Content-Type: application/json" \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: $API_VERSION" \
            -d @"$payload" \
            --max-time "$timeout" \
            2>&1)

        curl_exit=$?
        http_code=$(echo "$http_response" | tail -n1 | tr -d '\r')
        http_body=$(echo "$http_response" | sed '$d')

        # Handle curl errors
        if [ $curl_exit -ne 0 ]; then
            if [ $curl_exit -eq 28 ] && [ $attempt -lt $MAX_RETRIES ]; then
                timeout=$((timeout + 120))
                log "BATCH_${batch_id}:TIMEOUT:RETRY_${attempt}:NEW_TIMEOUT_${timeout}s"
                sleep 5
                continue
            fi
            echo "CURL_ERROR:$curl_exit"
            return 1
        fi

        case "$http_code" in
            200)
                echo "$http_body"
                return 0
                ;;
            429)
                if [ $attempt -lt $MAX_RETRIES ]; then
                    sleep_time=$((RATE_LIMIT_BACKOFF * attempt))
                    log "BATCH_${batch_id}:RATE_LIMITED:RETRY_${attempt}:SLEEPING_${sleep_time}s"
                    sleep $sleep_time
                    continue
                fi
                echo "RATE_LIMITED"
                return 1
                ;;
            529|503)
                if [ $attempt -lt $MAX_RETRIES ]; then
                    sleep_time=$((15 * attempt))
                    log "BATCH_${batch_id}:OVERLOADED:RETRY_${attempt}:SLEEPING_${sleep_time}s"
                    sleep $sleep_time
                    continue
                fi
                echo "OVERLOADED:$http_code"
                return 1
                ;;
            400|401)
                echo "HTTP_ERROR:$http_code:$http_body"
                return 1
                ;;
            *)
                if [ $attempt -lt $MAX_RETRIES ]; then
                    log "BATCH_${batch_id}:HTTP_${http_code}:RETRY_${attempt}"
                    sleep 5
                    continue
                fi
                echo "HTTP_ERROR:$http_code"
                return 1
                ;;
        esac
    done
    echo "MAX_RETRIES"
    return 1
}

#=============================================================================
# TOOL-USE LOOP
#=============================================================================

current_payload="$payload_file"
tool_iteration=0
loop_start=$(date +%s)

log "BATCH_${batch_id}:DISPATCH_START"

while true; do
    tool_iteration=$((tool_iteration + 1))

    # Guard: max iterations
    if [ $tool_iteration -gt $MAX_TOOL_ITERATIONS ]; then
        log "BATCH_${batch_id}:TOOL_LOOP_EXCEEDED:${MAX_TOOL_ITERATIONS}"
        break
    fi

    # Guard: total loop timeout
    elapsed=$(( $(date +%s) - loop_start ))
    if [ $elapsed -gt $LOOP_TIMEOUT ]; then
        log "BATCH_${batch_id}:LOOP_TIMEOUT:${elapsed}s"
        break
    fi

    # Choose timeout: full for first turn, shorter for continuations
    if [ $tool_iteration -eq 1 ]; then
        turn_timeout=$TIMEOUT
    else
        turn_timeout=$CONTINUATION_TIMEOUT
    fi

    log "BATCH_${batch_id}:TURN_${tool_iteration}:TIMEOUT_${turn_timeout}s"

    # Make API call
    response=$(api_call "$current_payload" "$turn_timeout")
    api_exit=$?

    if [ $api_exit -ne 0 ]; then
        log "BATCH_${batch_id}:FAILED:${response}"
        echo "{\"batch_id\": $batch_id, \"status\": \"error\", \"error\": \"$response\", \"turn\": $tool_iteration}" > "$error_file"
        echo "$batch_id" >> "$retry_queue" 2>/dev/null || true
        echo "BATCH_${batch_id}:FAILED"
        exit 1
    fi

    # Check stop_reason
    stop_reason=$(echo "$response" | jq -r '.stop_reason')

    if [ "$stop_reason" = "end_turn" ]; then
        # Final response — store result
        echo "$response" > "$result_file"
        log "BATCH_${batch_id}:SUCCESS:TURNS_${tool_iteration}"
        echo "BATCH_${batch_id}:SUCCESS"

        # Cleanup intermediate turn payloads
        rm -f "$WORK_DIR/payloads/payload_${batch_id}_turn"*.json 2>/dev/null
        exit 0
    fi

    if [ "$stop_reason" = "tool_use" ]; then
        # Extract and process tool_use blocks
        tool_results="[]"

        while IFS= read -r tool_block; do
            [ -z "$tool_block" ] && continue

            tool_id=$(echo "$tool_block" | jq -r '.id')
            tool_name=$(echo "$tool_block" | jq -r '.name')
            tool_input=$(echo "$tool_block" | jq -c '.input')

            if [ "$tool_name" = "report_progress" ]; then
                risk_key=$(echo "$tool_input" | jq -r '.risk_key')
                risk_status=$(echo "$tool_input" | jq -r '.status')

                log "BATCH_${batch_id}:PROGRESS:${risk_key}:${risk_status}"

                # Write progress file
                echo "$tool_input" | jq \
                    --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
                    --argjson bid "$batch_id" \
                    '. + {timestamp: $ts, batch_id: $bid}' \
                    > "$progress_dir/${risk_key}.json" 2>/dev/null

                # Add tool_result
                tool_results=$(echo "$tool_results" | jq \
                    --arg id "$tool_id" \
                    '. + [{type: "tool_result", tool_use_id: $id, content: "OK"}]')
            fi
        done < <(echo "$response" | jq -c '.content[] | select(.type == "tool_use")')

        # Build next payload: append assistant message + tool_results
        assistant_content=$(echo "$response" | jq -c '.content')

        # Read current messages, append assistant turn and tool results
        next_payload_file="$WORK_DIR/payloads/payload_${batch_id}_turn${tool_iteration}.json"
        jq --argjson ac "$assistant_content" \
           --argjson tr "$tool_results" \
           '.messages = .messages + [{role: "assistant", content: $ac}, {role: "user", content: $tr}]' \
           "$current_payload" > "$next_payload_file"

        current_payload="$next_payload_file"
        continue
    fi

    # Unexpected stop_reason — treat as final
    log "BATCH_${batch_id}:UNEXPECTED_STOP:${stop_reason}"
    echo "$response" > "$result_file"
    rm -f "$WORK_DIR/payloads/payload_${batch_id}_turn"*.json 2>/dev/null
    echo "BATCH_${batch_id}:SUCCESS"
    exit 0
done

# Loop exited via guard — save whatever we have
if [ -n "${response:-}" ]; then
    echo "$response" > "$result_file"
    log "BATCH_${batch_id}:PARTIAL_SUCCESS:TURNS_${tool_iteration}"
    echo "BATCH_${batch_id}:PARTIAL"
    exit 0
fi

log "BATCH_${batch_id}:FAILED:NO_RESPONSE"
echo "{\"batch_id\": $batch_id, \"status\": \"error\", \"error\": \"no_response\", \"turns\": $tool_iteration}" > "$error_file"
echo "BATCH_${batch_id}:FAILED"
exit 1
