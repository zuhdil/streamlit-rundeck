#!/bin/bash

# Webhook-Triggered Redeployment Script
# Handles GitHub webhook payloads and triggers redeployment

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/webhook-deployment.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WEBHOOK-DEPLOY: $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

# Webhook payload should be passed as environment variable or stdin
PAYLOAD="${WEBHOOK_PAYLOAD:-}"
if [[ -z "$PAYLOAD" ]] && [[ ! -t 0 ]]; then
    PAYLOAD=$(cat)
fi

[[ -n "$PAYLOAD" ]] || error "No webhook payload provided"

log "Processing webhook payload"

# Step 1: Validate webhook signature
log "Step 1: Validating webhook signature"
if [[ -n "${WEBHOOK_SECRET:-}" ]] && [[ -n "${HTTP_X_HUB_SIGNATURE_256:-}" ]]; then
    EXPECTED_SIGNATURE="sha256=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" -binary | xxd -p -c 256)"
    if [[ "$HTTP_X_HUB_SIGNATURE_256" != "$EXPECTED_SIGNATURE" ]]; then
        error "Invalid webhook signature"
    fi
    log "Webhook signature validated"
else
    log "WARNING: Webhook signature validation skipped (missing secret or signature)"
fi

# Step 2: Parse payload
log "Step 2: Parsing webhook payload"
REPO_URL=$(echo "$PAYLOAD" | jq -r '.repository.clone_url // empty')
REPO_FULL_NAME=$(echo "$PAYLOAD" | jq -r '.repository.full_name // empty')
PUSHED_BRANCH=$(echo "$PAYLOAD" | jq -r '.ref // empty' | sed 's|refs/heads/||')
COMMIT_SHA=$(echo "$PAYLOAD" | jq -r '.head_commit.id // .after // empty')
PUSHER_NAME=$(echo "$PAYLOAD" | jq -r '.pusher.name // empty')

log "Repository: $REPO_FULL_NAME"
log "Branch: $PUSHED_BRANCH"
log "Commit: $COMMIT_SHA"
log "Pusher: $PUSHER_NAME"

# Validate required fields
[[ -n "$REPO_URL" ]] || error "Missing repository URL in payload"
[[ -n "$PUSHED_BRANCH" ]] || error "Missing branch information in payload"

# Step 3: Lookup deployment metadata
log "Step 3: Looking up deployment metadata"
DEPLOYMENT_INFO=$("$SCRIPT_DIR/get-deployment.sh" "$REPO_URL" "$PUSHED_BRANCH" 2>/dev/null || echo "")

if [[ -z "$DEPLOYMENT_INFO" ]]; then
    log "No deployment found for repository: $REPO_URL (branch: $PUSHED_BRANCH)"
    log "This webhook will be ignored"
    exit 0
fi

# Parse deployment info
APP_NAME=$(echo "$DEPLOYMENT_INFO" | grep "^APP_NAME=" | cut -d= -f2)
TARGET_BRANCH=$(echo "$DEPLOYMENT_INFO" | grep "^TARGET_BRANCH=" | cut -d= -f2)
MAIN_FILE=$(echo "$DEPLOYMENT_INFO" | grep "^MAIN_FILE=" | cut -d= -f2)
REGION=$(echo "$DEPLOYMENT_INFO" | grep "^REGION=" | cut -d= -f2)
SECRETS_CONTENT=$(echo "$DEPLOYMENT_INFO" | grep "^SECRETS_CONTENT=" | cut -d= -f2-)

log "Found deployment: $APP_NAME"
log "Target branch: $TARGET_BRANCH"

# Step 4: Filter by branch
log "Step 4: Checking branch filter"
if [[ "$PUSHED_BRANCH" != "$TARGET_BRANCH" ]]; then
    log "Push to branch '$PUSHED_BRANCH' does not match target branch '$TARGET_BRANCH'"
    log "Ignoring this webhook"
    exit 0
fi

log "Branch matches target, proceeding with redeployment"

# Step 5: Execute redeployment
log "Step 5: Starting automatic redeployment"
log "Triggering redeployment for $APP_NAME from commit $COMMIT_SHA"

export GITHUB_URL="$REPO_URL"
export MAIN_FILE="$MAIN_FILE"
export APP_NAME="$APP_NAME"
export TARGET_BRANCH="$TARGET_BRANCH"
export REGION="$REGION"
export SECRETS_CONTENT="$SECRETS_CONTENT"
export MEMORY="${MEMORY:-1Gi}"
export CPU="${CPU:-1}"

# Call main deployment script
"$SCRIPT_DIR/deploy-streamlit.sh" || error "Redeployment failed"

log "Automatic redeployment completed successfully"
log "Triggered by: $PUSHER_NAME"
log "Commit: $COMMIT_SHA"

# Output for webhook response
cat << EOF
{
  "status": "success",
  "message": "Automatic redeployment completed",
  "app_name": "$APP_NAME",
  "commit": "$COMMIT_SHA",
  "branch": "$PUSHED_BRANCH",
  "pusher": "$PUSHER_NAME"
}
EOF