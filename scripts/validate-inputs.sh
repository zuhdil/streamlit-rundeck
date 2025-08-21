#!/bin/bash

# Input Validation Script
# Validates user inputs for Streamlit deployment

set -euo pipefail

# Arguments
GITHUB_URL="$1"
MAIN_FILE="$2"
APP_NAME="$3"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] VALIDATE: $*"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "Starting input validation"

# Validate GitHub URL
log "Validating GitHub URL: $GITHUB_URL"
if [[ ! "$GITHUB_URL" =~ ^https://github\.com/.+/.+$ ]]; then
    error "Invalid GitHub URL format. Must be https://github.com/user/repo"
fi

# Check if repository is public (basic check)
REPO_PATH=$(echo "$GITHUB_URL" | sed 's|https://github.com/||' | sed 's|\.git$||')
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    log "Checking repository accessibility with API token"
    REPO_INFO=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO_PATH" || echo "")
    
    if [[ -z "$REPO_INFO" ]] || [[ "$(echo "$REPO_INFO" | jq -r '.message // empty')" == "Not Found" ]]; then
        error "Repository not found or not accessible: $GITHUB_URL"
    fi
    
    # Check if repository has the main file
    DEFAULT_BRANCH=$(echo "$REPO_INFO" | jq -r '.default_branch // "main"')
    FILE_CHECK=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO_PATH/contents/$MAIN_FILE?ref=$DEFAULT_BRANCH" || echo "")
    
    if [[ "$(echo "$FILE_CHECK" | jq -r '.message // empty')" == "Not Found" ]]; then
        log "WARNING: Main file '$MAIN_FILE' not found in default branch '$DEFAULT_BRANCH'"
        log "This may cause deployment to fail if file doesn't exist"
    fi
else
    log "No GitHub token provided, skipping repository accessibility check"
fi

# Validate main file
log "Validating main file: $MAIN_FILE"
if [[ ! "$MAIN_FILE" =~ \.py$ ]]; then
    error "Main file must be a Python file with .py extension"
fi

if [[ "$MAIN_FILE" =~ ^/ ]] || [[ "$MAIN_FILE" =~ \.\. ]]; then
    error "Main file path contains invalid characters (absolute path or parent directory references)"
fi

# Validate app name
log "Validating app name: $APP_NAME"
if [[ ! "$APP_NAME" =~ ^[a-z0-9-]+$ ]]; then
    error "App name must contain only lowercase letters, numbers, and hyphens"
fi

if [[ ${#APP_NAME} -lt 3 ]] || [[ ${#APP_NAME} -gt 63 ]]; then
    error "App name must be between 3 and 63 characters long"
fi

if [[ "$APP_NAME" =~ ^- ]] || [[ "$APP_NAME" =~ -$ ]]; then
    error "App name cannot start or end with a hyphen"
fi

# Validate required environment variables
log "Checking required environment variables"
: "${PROJECT_ID:?PROJECT_ID environment variable is required}"
: "${ARTIFACT_REGISTRY:?ARTIFACT_REGISTRY environment variable is required}"

# Validate GCP project ID format
if [[ ! "$PROJECT_ID" =~ ^[a-z0-9-]+$ ]]; then
    error "Invalid PROJECT_ID format"
fi

# Validate artifact registry URL format
if [[ ! "$ARTIFACT_REGISTRY" =~ ^[a-z0-9-]+-docker\.pkg\.dev/.+/.+$ ]]; then
    error "Invalid ARTIFACT_REGISTRY URL format"
fi

log "All validations passed successfully"