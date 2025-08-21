#!/bin/bash

# GitHub Webhook Creation Script
# Creates webhooks for automatic redeployment on push events

set -euo pipefail

# Arguments
GITHUB_URL="$1"
TARGET_BRANCH="$2"
WEBHOOK_URL="$3"
WEBHOOK_SECRET="$4"

# Extract repository path from URL
REPO_PATH=$(echo "$GITHUB_URL" | sed 's|https://github.com/||' | sed 's|\.git$||')

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WEBHOOK: $*"
}

error() {
    log "ERROR: $*"
    exit 1
}

# Validate inputs
[[ -n "${GITHUB_TOKEN:-}" ]] || error "GITHUB_TOKEN environment variable is required"
[[ "$GITHUB_URL" =~ ^https://github\.com/.+/.+ ]] || error "Invalid GitHub URL format"

log "Creating webhook for repository: $REPO_PATH"
log "Target branch: $TARGET_BRANCH"
log "Webhook URL: $WEBHOOK_URL"

# Create webhook payload
WEBHOOK_PAYLOAD=$(cat << EOF
{
  "name": "web",
  "active": true,
  "events": ["push"],
  "config": {
    "url": "$WEBHOOK_URL",
    "content_type": "json",
    "secret": "$WEBHOOK_SECRET",
    "insecure_ssl": "0"
  }
}
EOF
)

# Check if webhook already exists
log "Checking for existing webhooks..."
EXISTING_WEBHOOKS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_PATH/hooks" || error "Failed to fetch existing webhooks")

# Check if our webhook URL already exists
WEBHOOK_EXISTS=$(echo "$EXISTING_WEBHOOKS" | jq -r --arg url "$WEBHOOK_URL" \
    '.[] | select(.config.url == $url) | .id' || echo "")

if [[ -n "$WEBHOOK_EXISTS" ]]; then
    log "Webhook already exists with ID: $WEBHOOK_EXISTS"
    log "Updating existing webhook..."
    
    # Update existing webhook
    RESPONSE=$(curl -s -X PATCH \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "$WEBHOOK_PAYLOAD" \
        "https://api.github.com/repos/$REPO_PATH/hooks/$WEBHOOK_EXISTS" || error "Failed to update webhook")
    
    WEBHOOK_ID="$WEBHOOK_EXISTS"
else
    log "Creating new webhook..."
    
    # Create new webhook
    RESPONSE=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "$WEBHOOK_PAYLOAD" \
        "https://api.github.com/repos/$REPO_PATH/hooks" || error "Failed to create webhook")
    
    # Extract webhook ID from response
    WEBHOOK_ID=$(echo "$RESPONSE" | jq -r '.id // empty')
    
    if [[ -z "$WEBHOOK_ID" ]]; then
        log "Response: $RESPONSE"
        error "Failed to extract webhook ID from response"
    fi
fi

log "Webhook created/updated successfully with ID: $WEBHOOK_ID"

# Test webhook (ping)
log "Testing webhook..."
curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO_PATH/hooks/$WEBHOOK_ID/pings" || {
    log "WARNING: Failed to ping webhook, but creation succeeded"
}

# Store webhook ID for later use
echo "$WEBHOOK_ID" > "/tmp/webhook_id_${APP_NAME:-unknown}"

log "Webhook setup completed successfully"
echo "WEBHOOK_ID=$WEBHOOK_ID"