#!/bin/bash

# Webhook Payload Validation Script
# Validates GitHub webhook payloads and signatures

set -euo pipefail

# Arguments
PAYLOAD="$1"
SIGNATURE="${2:-}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] VALIDATE-WEBHOOK: $*"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "Starting webhook validation"

# Validate payload is valid JSON
log "Validating JSON payload"
if ! echo "$PAYLOAD" | jq . >/dev/null 2>&1; then
    error "Invalid JSON payload"
fi

# Validate signature if webhook secret is provided
if [[ -n "${WEBHOOK_SECRET:-}" ]] && [[ -n "$SIGNATURE" ]]; then
    log "Validating webhook signature"
    
    # Remove 'sha256=' prefix if present
    SIGNATURE=$(echo "$SIGNATURE" | sed 's/^sha256=//')
    
    # Calculate expected signature
    EXPECTED_SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" -binary | xxd -p -c 256)
    
    if [[ "$SIGNATURE" != "$EXPECTED_SIGNATURE" ]]; then
        error "Invalid webhook signature"
    fi
    
    log "Webhook signature validated successfully"
else
    log "WARNING: Webhook signature validation skipped (missing secret or signature)"
fi

# Validate required GitHub webhook fields
log "Validating webhook payload structure"

# Check if it's a push event
EVENT_TYPE=$(echo "$PAYLOAD" | jq -r '.action // .zen // empty')
if [[ -n "$EVENT_TYPE" ]]; then
    # This might be a test webhook or other event type
    log "Non-push event detected, checking if it's a valid webhook test"
fi

# Validate repository information
REPO_URL=$(echo "$PAYLOAD" | jq -r '.repository.clone_url // empty')
REPO_NAME=$(echo "$PAYLOAD" | jq -r '.repository.full_name // empty')

if [[ -z "$REPO_URL" ]] || [[ -z "$REPO_NAME" ]]; then
    error "Missing repository information in webhook payload"
fi

# Validate ref (branch) information for push events
REF=$(echo "$PAYLOAD" | jq -r '.ref // empty')
if [[ -n "$REF" ]]; then
    if [[ ! "$REF" =~ ^refs/heads/ ]]; then
        log "Non-branch ref detected: $REF (ignoring)"
        exit 0
    fi
    
    BRANCH=$(echo "$REF" | sed 's|refs/heads/||')
    log "Push event for branch: $BRANCH"
else
    log "No ref information (possibly a test webhook)"
fi

# Validate commits information
COMMITS=$(echo "$PAYLOAD" | jq -r '.commits // empty')
if [[ -n "$COMMITS" ]] && [[ "$COMMITS" != "null" ]]; then
    COMMIT_COUNT=$(echo "$COMMITS" | jq 'length')
    log "Webhook contains $COMMIT_COUNT commits"
else
    log "No commits information (possibly a test webhook)"
fi

# Check for force push
FORCED=$(echo "$PAYLOAD" | jq -r '.forced // false')
if [[ "$FORCED" == "true" ]]; then
    log "WARNING: Force push detected"
fi

# Validate pusher information
PUSHER=$(echo "$PAYLOAD" | jq -r '.pusher.name // .pusher.login // empty')
if [[ -n "$PUSHER" ]]; then
    log "Push by: $PUSHER"
fi

log "Webhook validation completed successfully"

# Output parsed information for use by other scripts
cat << EOF
REPO_URL=$REPO_URL
REPO_NAME=$REPO_NAME
BRANCH=${BRANCH:-}
PUSHER=${PUSHER:-}
FORCED=$FORCED
EOF