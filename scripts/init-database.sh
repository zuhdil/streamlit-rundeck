#!/bin/bash

# Database Initialization Script
# Sets up the deployment tracking schema

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INIT-DB: $*"
}

error() {
    log "ERROR: $*"
    exit 1
}

# Database connection parameters
DB_HOST="${RUNDECK_DATABASE_URL:-jdbc:postgresql://db:5432/rundeck}"
DB_HOST=$(echo "$DB_HOST" | sed 's|jdbc:postgresql://||' | sed 's|/.*||')
DB_NAME="rundeck"
DB_USER="${RUNDECK_DATABASE_USERNAME:-rundeck}"
DB_PASS="${RUNDECK_DATABASE_PASSWORD:-rundeckpassword}"

log "Initializing deployment tracking database schema"
log "Database host: $DB_HOST"

# Wait for database to be ready
log "Waiting for database to be ready..."
for i in {1..30}; do
    if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
        log "Database is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        error "Database not ready after 30 attempts"
    fi
    sleep 2
done

# Execute schema creation
log "Creating deployment tracking schema..."
export PGPASSWORD="$DB_PASS"
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f "$SCRIPT_DIR/../sql/deployment-schema.sql" || error "Failed to create schema"

log "Database initialization completed successfully"

# Verify tables were created
log "Verifying table creation..."
TABLES=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN ('deployments', 'deployment_history');" | wc -l)

if [ "$TABLES" -eq 2 ]; then
    log "All tables created successfully"
else
    error "Table creation verification failed"
fi