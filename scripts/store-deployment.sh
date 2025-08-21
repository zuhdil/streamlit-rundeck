#!/bin/bash

# Deployment Metadata Storage Script
# Stores deployment information in PostgreSQL database

set -euo pipefail

# Arguments
APP_NAME="$1"
GITHUB_URL="$2"
MAIN_FILE="$3"
TARGET_BRANCH="$4"
REGION="$5"
SERVICE_URL="$6"
SECRETS_CONTENT="${7:-}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STORE-DEPLOY: $*"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "Storing deployment metadata for: $APP_NAME"

# Database connection parameters
DB_HOST="${RUNDECK_DATABASE_URL:-jdbc:postgresql://db:5432/rundeck}"
DB_HOST=$(echo "$DB_HOST" | sed 's|jdbc:postgresql://||' | sed 's|/.*||')
DB_NAME="rundeck"
DB_USER="${RUNDECK_DATABASE_USERNAME:-rundeck}"
DB_PASS="${RUNDECK_DATABASE_PASSWORD:-rundeckpassword}"

# Get webhook ID if it exists
WEBHOOK_ID=""
if [[ -f "/tmp/webhook_id_$APP_NAME" ]]; then
    WEBHOOK_ID=$(cat "/tmp/webhook_id_$APP_NAME" || echo "")
fi

# Prepare SQL
SQL="INSERT INTO deployments (
    app_name, 
    github_url, 
    main_file, 
    secrets_content, 
    region, 
    target_branch, 
    webhook_id, 
    cloud_run_url, 
    created_at, 
    updated_at
) VALUES (
    '$APP_NAME',
    '$GITHUB_URL',
    '$MAIN_FILE',
    '$SECRETS_CONTENT',
    '$REGION',
    '$TARGET_BRANCH',
    '$WEBHOOK_ID',
    '$SERVICE_URL',
    NOW(),
    NOW()
) ON CONFLICT (app_name) DO UPDATE SET
    github_url = EXCLUDED.github_url,
    main_file = EXCLUDED.main_file,
    secrets_content = EXCLUDED.secrets_content,
    region = EXCLUDED.region,
    target_branch = EXCLUDED.target_branch,
    webhook_id = EXCLUDED.webhook_id,
    cloud_run_url = EXCLUDED.cloud_run_url,
    updated_at = NOW();"

# Execute SQL using psql
export PGPASSWORD="$DB_PASS"
echo "$SQL" | psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 || error "Failed to store deployment metadata"

log "Deployment metadata stored successfully"

# Cleanup temporary files
rm -f "/tmp/webhook_id_$APP_NAME" || true