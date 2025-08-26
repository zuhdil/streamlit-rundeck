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

# Webhook payload should be passed as environment variable, option, or stdin
PAYLOAD="${WEBHOOK_PAYLOAD:-${RD_OPTION_WEBHOOK_PAYLOAD:-}}"

# Skip null values
if [[ "$PAYLOAD" == "null" ]]; then
    PAYLOAD=""
fi

if [[ -z "$PAYLOAD" ]] && [[ ! -t 0 ]]; then
    PAYLOAD=$(cat 2>/dev/null || echo "")
fi

# Try to get payload from webhook context files if available
if [[ -z "$PAYLOAD" ]] && [[ -f "/tmp/webhook_data.json" ]]; then
    PAYLOAD=$(cat "/tmp/webhook_data.json")
fi

# If we still don't have payload, try to construct a minimal one from environment
if [[ -z "$PAYLOAD" ]]; then
    log "WARNING: No webhook payload found, attempting to construct minimal payload from environment"
    # This is a fallback - webhook won't work without proper repository info
    PAYLOAD='{"repository":{"clone_url":"unknown"},"ref":"refs/heads/main"}'
fi

log "Payload status: ${#PAYLOAD} characters received"

log "Processing webhook payload"

# Step 1: Parse payload and detect event type
log "Step 1: Parsing webhook payload"

# Check for GitHub ping event
ZEN_MESSAGE=$(echo "$PAYLOAD" | jq -r '.zen // empty')
if [[ -n "$ZEN_MESSAGE" ]]; then
    log "GitHub ping event detected: $ZEN_MESSAGE"
    log "Webhook endpoint is alive and responding correctly"
    echo '{"status": "success", "message": "Webhook ping acknowledged", "zen": "'"$ZEN_MESSAGE"'"}'
    exit 0
fi

REPO_URL=$(echo "$PAYLOAD" | jq -r '.repository.clone_url // empty')
REPO_FULL_NAME=$(echo "$PAYLOAD" | jq -r '.repository.full_name // empty')
PUSHED_BRANCH=$(echo "$PAYLOAD" | jq -r '.ref // empty' | sed 's|refs/heads/||')
COMMIT_SHA=$(echo "$PAYLOAD" | jq -r '.head_commit.id // .after // empty')
PUSHER_NAME=$(echo "$PAYLOAD" | jq -r '.pusher.name // empty')

log "Repository: $REPO_FULL_NAME"
log "Branch: $PUSHED_BRANCH"
log "Commit: $COMMIT_SHA"
log "Pusher: $PUSHER_NAME"

# Validate required fields for push events
[[ -n "$REPO_URL" ]] || error "Missing repository URL in payload"
[[ -n "$PUSHED_BRANCH" ]] || error "Missing branch information in payload"

# Step 2: Lookup deployment metadata
log "Step 2: Looking up deployment metadata"
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

# Step 3: Filter by branch
log "Step 3: Checking branch filter"
if [[ "$PUSHED_BRANCH" != "$TARGET_BRANCH" ]]; then
    log "Push to branch '$PUSHED_BRANCH' does not match target branch '$TARGET_BRANCH'"
    log "Ignoring this webhook"
    exit 0
fi

log "Branch matches target, proceeding with redeployment"

# Step 4: Execute redeployment
log "Step 4: Starting automatic redeployment"
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