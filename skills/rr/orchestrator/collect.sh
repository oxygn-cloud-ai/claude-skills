#!/bin/bash
# collect.sh — Collect and validate sub-agent results (macOS-adapted)
#
# Usage: ./collect.sh
#
# Reads results from $WORK_DIR/results/
# Outputs validated assessments to $WORK_DIR/assessments/
# Logs failures to $WORK_DIR/failures/

set -uo pipefail

WORK_DIR="${RR_WORK_DIR:-${HOME}/rr-work}"
RESULTS_DIR="$WORK_DIR/results"
ASSESSMENTS_DIR="$WORK_DIR/assessments"
INDIVIDUAL_DIR="$WORK_DIR/individual-assessments"
FAILURES_DIR="$WORK_DIR/failures"
COLLECT_LOG="$WORK_DIR/collect.log"

mkdir -p "$ASSESSMENTS_DIR" "$INDIVIDUAL_DIR" "$FAILURES_DIR"
: > "$COLLECT_LOG"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$COLLECT_LOG"
}

total_assessments=0
valid_assessments=0
failed_extractions=0
failed_validations=0

# Process each result file
for result_file in "$RESULTS_DIR"/result_*.json; do
    [ -f "$result_file" ] || continue

    batch_id=$(basename "$result_file" | sed 's/result_//;s/\.json//')
    log "Processing batch $batch_id"

    # Extract text content from API response
    # Extract text content (handles both tool-use and non-tool-use responses)
    content=$(jq -r '[.content[] | select(.type == "text")] | .[0].text // empty' "$result_file" 2>/dev/null \
        | sed 's/^```json[[:space:]]*//' | sed 's/^```[[:space:]]*//' | sed 's/[[:space:]]*```$//')

    if [ -z "$content" ]; then
        log "BATCH_${batch_id}:NO_CONTENT"
        cp "$result_file" "$FAILURES_DIR/batch_${batch_id}_no_content.json"
        failed_extractions=$((failed_extractions + 1))
        continue
    fi

    # Try to parse as JSON
    if ! echo "$content" | jq -e '.' >/dev/null 2>&1; then
        log "BATCH_${batch_id}:INVALID_JSON"
        echo "$content" > "$FAILURES_DIR/batch_${batch_id}_invalid_json.txt"
        failed_extractions=$((failed_extractions + 1))
        continue
    fi

    # Validate structure
    if ! echo "$content" | jq -e '.assessments | type == "array"' >/dev/null 2>&1; then
        log "BATCH_${batch_id}:MISSING_ASSESSMENTS_ARRAY"
        echo "$content" > "$FAILURES_DIR/batch_${batch_id}_invalid_structure.json"
        failed_validations=$((failed_validations + 1))
        continue
    fi

    # Extract assessments
    assessments_count=$(echo "$content" | jq '.assessments | length')
    log "BATCH_${batch_id}:FOUND_${assessments_count}_ASSESSMENTS"

    # Save batch assessments
    echo "$content" > "$ASSESSMENTS_DIR/batch_${batch_id}.json"

    # Extract individual assessments (C-style for loop instead of seq)
    for ((i=0; i<assessments_count; i++)); do
        assessment=$(echo "$content" | jq ".assessments[$i]")
        risk_key=$(echo "$assessment" | jq -r '.risk_key // empty')
        status=$(echo "$assessment" | jq -r '.status // empty')

        if [ -z "$risk_key" ]; then
            log "BATCH_${batch_id}:ASSESSMENT_${i}:MISSING_RISK_KEY"
            failed_validations=$((failed_validations + 1))
            continue
        fi

        total_assessments=$((total_assessments + 1))

        if [ "$status" = "error" ]; then
            error_msg=$(echo "$assessment" | jq -r '.error // "unknown"')
            log "BATCH_${batch_id}:${risk_key}:ERROR:${error_msg}"
            echo "$assessment" > "$FAILURES_DIR/${risk_key}_error.json"
            continue
        fi

        # Validate assessment structure
        if ! echo "$assessment" | jq -e '.assessment.metadata.ticket_key' >/dev/null 2>&1; then
            log "BATCH_${batch_id}:${risk_key}:INVALID_ASSESSMENT_STRUCTURE"
            echo "$assessment" > "$FAILURES_DIR/${risk_key}_invalid.json"
            failed_validations=$((failed_validations + 1))
            continue
        fi

        # Validate rating matrix
        inherent_likelihood=$(echo "$assessment" | jq -r '.assessment.sections.inherent_risk.likelihood // empty')
        inherent_impact=$(echo "$assessment" | jq -r '.assessment.sections.inherent_risk.impact // empty')
        inherent_rating=$(echo "$assessment" | jq -r '.assessment.sections.inherent_risk.rating // empty')

        # Check rating matrix compliance
        expected_rating=""
        case "${inherent_likelihood}_${inherent_impact}" in
            "High_High") expected_rating="Critical" ;;
            "High_Medium") expected_rating="High" ;;
            "High_Low") expected_rating="Medium" ;;
            "Medium_High") expected_rating="High" ;;
            "Medium_Medium") expected_rating="Medium" ;;
            "Medium_Low") expected_rating="Low" ;;
            "Low_High") expected_rating="Medium" ;;
            "Low_Medium") expected_rating="Low" ;;
            "Low_Low") expected_rating="Low" ;;
        esac

        if [ -n "$expected_rating" ] && [ "$inherent_rating" != "$expected_rating" ]; then
            log "BATCH_${batch_id}:${risk_key}:RATING_MISMATCH:EXPECTED_${expected_rating}:GOT_${inherent_rating}"
            # Fix the rating
            assessment=$(echo "$assessment" | jq --arg r "$expected_rating" '.assessment.sections.inherent_risk.rating = $r')
            log "BATCH_${batch_id}:${risk_key}:RATING_CORRECTED"
        fi

        # Save individual assessment
        echo "$assessment" | jq '.assessment' > "$INDIVIDUAL_DIR/${risk_key}_assessment.json"
        valid_assessments=$((valid_assessments + 1))
        log "BATCH_${batch_id}:${risk_key}:VALID"
    done
done

# Generate summary
summary=$(cat <<EOF
{
    "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "total_assessments": $total_assessments,
    "valid_assessments": $valid_assessments,
    "failed_extractions": $failed_extractions,
    "failed_validations": $failed_validations,
    "success_rate": $(echo "scale=2; $valid_assessments * 100 / ($total_assessments + 1)" | bc 2>/dev/null || echo "0")
}
EOF
)

echo "$summary" > "$WORK_DIR/collection-summary.json"
log "COLLECTION_COMPLETE:TOTAL_${total_assessments}:VALID_${valid_assessments}:FAILED_$((failed_extractions + failed_validations))"

echo "COLLECTION_COMPLETE:TOTAL_${total_assessments}:VALID_${valid_assessments}:FAILED_$((failed_extractions + failed_validations))"
