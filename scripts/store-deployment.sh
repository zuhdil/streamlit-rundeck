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
DB_HOST=$(echo "$DB_HOST" | sed 's|jdbc:postgresql://||' | sed 's|:.*||')
DB_NAME="rundeck"
DB_USER="${RUNDECK_DATABASE_USERNAME:-rundeck}"
DB_PASS="${RUNDECK_DATABASE_PASSWORD:-rundeckpassword}"

# Get webhook ID if it exists
WEBHOOK_ID=""
if [[ -f "/tmp/webhook_id_$APP_NAME" ]]; then
    WEBHOOK_ID=$(cat "/tmp/webhook_id_$APP_NAME" || echo "")
fi

# Use a temporary SQL file to handle special characters properly
SQL_FILE="/tmp/store_deployment_$$.sql"

# Escape single quotes in text values
APP_NAME_ESCAPED=$(echo "$APP_NAME" | sed "s/'/''/g")
GITHUB_URL_ESCAPED=$(echo "$GITHUB_URL" | sed "s/'/''/g")
MAIN_FILE_ESCAPED=$(echo "$MAIN_FILE" | sed "s/'/''/g")
SECRETS_CONTENT_ESCAPED=$(echo "$SECRETS_CONTENT" | sed "s/'/''/g")
REGION_ESCAPED=$(echo "$REGION" | sed "s/'/''/g")
TARGET_BRANCH_ESCAPED=$(echo "$TARGET_BRANCH" | sed "s/'/''/g")
WEBHOOK_ID_ESCAPED=$(echo "$WEBHOOK_ID" | sed "s/'/''/g")
SERVICE_URL_ESCAPED=$(echo "$SERVICE_URL" | sed "s/'/''/g")

# Create SQL with proper escaping
cat > "$SQL_FILE" << EOF
INSERT INTO deployments (
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
    '$APP_NAME_ESCAPED',
    '$GITHUB_URL_ESCAPED',
    '$MAIN_FILE_ESCAPED',
    '$SECRETS_CONTENT_ESCAPED',
    '$REGION_ESCAPED',
    '$TARGET_BRANCH_ESCAPED',
    '$WEBHOOK_ID_ESCAPED',
    '$SERVICE_URL_ESCAPED',
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
    updated_at = NOW();
EOF

# Execute SQL using psql with better error reporting
export PGPASSWORD="$DB_PASS"
if ! psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$SQL_FILE" 2>&1; then
    log "ERROR: SQL execution failed. SQL content:"
    cat "$SQL_FILE"
    rm -f "$SQL_FILE"
    error "Failed to store deployment metadata"
fi

# Clean up temporary file
rm -f "$SQL_FILE"

log "Deployment metadata stored successfully"

# Cleanup temporary files
rm -f "/tmp/webhook_id_$APP_NAME" || true