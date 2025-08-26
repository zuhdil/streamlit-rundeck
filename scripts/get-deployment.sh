#!/bin/bash

# Get Deployment Metadata Script
# Retrieves deployment information from PostgreSQL database

set -euo pipefail

# Arguments
GITHUB_URL="$1"
TARGET_BRANCH="$2"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] GET-DEPLOY: $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

# Load database connection parameters
source "$(dirname "${BASH_SOURCE[0]}")/db-connection.sh"

# Normalize GitHub URL (handle both with and without .git suffix)
NORMALIZED_URL="${GITHUB_URL%%.git}"
NORMALIZED_URL_WITH_GIT="${NORMALIZED_URL}.git"

# Prepare SQL with compound key filter (check both URL formats)
SQL="SELECT app_name, github_url, main_file, target_branch, region, secrets_content, webhook_id, cloud_run_url 
     FROM deployments 
     WHERE (github_url = '$GITHUB_URL' OR github_url = '$NORMALIZED_URL' OR github_url = '$NORMALIZED_URL_WITH_GIT')
       AND target_branch = '$TARGET_BRANCH'
     LIMIT 1;"

# Execute SQL
export PGPASSWORD="$DB_PASS"
RESULT=$(echo "$SQL" | psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -F "|" 2>/dev/null || echo "")

if [[ -z "$RESULT" ]]; then
    error "No deployment found for: $GITHUB_URL (branch: $TARGET_BRANCH)"
fi

# Parse result and output as environment variables
IFS="|" read -r APP_NAME GITHUB_URL MAIN_FILE TARGET_BRANCH REGION SECRETS_CONTENT WEBHOOK_ID CLOUD_RUN_URL <<< "$RESULT"

echo "APP_NAME=$APP_NAME"
echo "GITHUB_URL=$GITHUB_URL"
echo "MAIN_FILE=$MAIN_FILE"
echo "TARGET_BRANCH=$TARGET_BRANCH"
echo "REGION=$REGION"
echo "SECRETS_CONTENT=$SECRETS_CONTENT"
echo "WEBHOOK_ID=$WEBHOOK_ID"
echo "CLOUD_RUN_URL=$CLOUD_RUN_URL"