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

# Load database connection parameters
source "$(dirname "${BASH_SOURCE[0]}")/db-connection.sh"

log "Initializing deployment tracking database schema"
log "Database host: $DB_HOST"

# Wait for database to be ready
log "Waiting for database to be ready..."
for i in {1..60}; do
    if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
        log "Database is ready"
        break
    fi
    if [ $i -eq 60 ]; then
        error "Database not ready after 60 attempts (2 minutes)"
    fi
    if [ $((i % 10)) -eq 0 ]; then
        log "Still waiting for database... (attempt $i/60)"
    fi
    sleep 2
done

# Check if schema already exists
log "Checking if deployment schema already exists..."
export PGPASSWORD="$DB_PASS"
EXISTING_TABLES=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN ('deployments', 'deployment_history');" 2>/dev/null | grep -cE "^\s*(deployments|deployment_history)\s*$" || echo "0")

if [ "$EXISTING_TABLES" -eq 2 ]; then
    log "Deployment schema already exists, skipping creation"
else
    log "Creating deployment tracking schema..."
    psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -f "/sql/deployment-schema.sql" || error "Failed to create schema"
    
    # Verify tables were created
    log "Verifying table creation..."
    TABLES=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN ('deployments', 'deployment_history');" | grep -c -E "^\s*(deployments|deployment_history)\s*$")
    
    if [ "$TABLES" -eq 2 ]; then
        log "All tables created successfully"
    else
        error "Table creation verification failed"
    fi
fi

log "Database initialization completed successfully"