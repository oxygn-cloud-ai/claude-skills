#!/bin/bash
# dispatch.sh — Parallel sub-agent dispatch with robust error handling (macOS-adapted)
#
# Usage: ./dispatch.sh
#
# Requires:
#   - ANTHROPIC_API_KEY environment variable
#   - Payload files in $WORK_DIR/payloads/
#
# Outputs:
#   - Results in $WORK_DIR/results/
#   - Errors in $WORK_DIR/errors/
#   - Summary to stdout

set -uo pipefail

# Configuration
WORK_DIR="${RR_WORK_DIR:-${HOME}/rr-work}"
PAYLOADS_DIR="$WORK_DIR/payloads"
RESULTS_DIR="$WORK_DIR/results"
ERRORS_DIR="$WORK_DIR/errors"
RETRY_QUEUE="$WORK_DIR/retry-queue.txt"
DISPATCH_LOG="$WORK_DIR/dispatch.log"

# Resolve the directory this script lives in (follows symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MAX_PARALLEL=20
MAX_RETRIES=3
INITIAL_TIMEOUT=300
MAX_TIMEOUT=600
RATE_LIMIT_BACKOFF=30

# Ensure directories exist
mkdir -p "$RESULTS_DIR" "$ERRORS_DIR" "$WORK_DIR/logs"
: > "$DISPATCH_LOG"
: > "$RETRY_QUEUE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$DISPATCH_LOG"
}

# Verify API key
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "ERROR: ANTHROPIC_API_KEY not set"
    exit 1
fi

# Get batch IDs
if [ ! -d "$PAYLOADS_DIR" ] || [ -z "$(ls -A "$PAYLOADS_DIR" 2>/dev/null)" ]; then
    echo "ERROR: No payloads found in $PAYLOADS_DIR"
    exit 1
fi

batch_ids=$(ls "$PAYLOADS_DIR" | grep -E '^payload_[0-9]+\.json$' | sed 's/payload_//;s/\.json//' | sort -n)
total_batches=$(echo "$batch_ids" | wc -w | tr -d ' ')

log "DISPATCH_START:TOTAL_BATCHES_${total_batches}:MAX_PARALLEL_${MAX_PARALLEL}"

# Export env vars needed by _dispatch_one.sh
export WORK_DIR ANTHROPIC_API_KEY
export RR_MODEL="${RR_MODEL:-claude-sonnet-4-20250514}"
export ANTHROPIC_API_VERSION="${ANTHROPIC_API_VERSION:-2023-06-01}"
export MAX_RETRIES INITIAL_TIMEOUT MAX_TIMEOUT RATE_LIMIT_BACKOFF

# Dispatch in parallel using standalone wrapper script (replaces export -f pattern)
echo "$batch_ids" | tr ' ' '\n' | xargs -P "$MAX_PARALLEL" -I {} "$SCRIPT_DIR/_dispatch_one.sh" {}

# Merge per-process logs into dispatch log
cat "$WORK_DIR/logs"/dispatch_*.log >> "$DISPATCH_LOG" 2>/dev/null

# Count results
succeeded=$(ls "$RESULTS_DIR" 2>/dev/null | grep -c '^result_' || echo 0)
failed=$((total_batches - succeeded))

log "DISPATCH_COMPLETE:TOTAL_${total_batches}:SUCCESS_${succeeded}:FAILED_${failed}"

# Report retry queue
if [ -s "$RETRY_QUEUE" ]; then
    retry_count=$(wc -l < "$RETRY_QUEUE" | tr -d ' ')
    log "RETRY_QUEUE:${retry_count}_BATCHES"
fi

echo "DISPATCH_COMPLETE:TOTAL_${total_batches}:SUCCESS_${succeeded}:FAILED_${failed}"
