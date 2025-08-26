#!/bin/bash

# Shared Database Connection Utility
# Sources this file to get consistent database connection parameters
# Usage: source /scripts/db-connection.sh

# Database connection parameters with robust fallbacks
# Environment variables may not be available in all execution contexts
export DB_HOST="${DB_HOST:-db}"
export DB_NAME="${DB_NAME:-rundeck}"
export DB_USER="${DB_USER:-rundeck}"
export DB_PASS="${DB_PASSWORD:-${DB_PASS:-rundeckpassword}}"

# Helper function for database connection logging
db_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DB: $*" >&2
}

# Validate database connection parameters
validate_db_connection() {
    local missing=()
    
    [[ -z "$DB_HOST" ]] && missing+=("DB_HOST")
    [[ -z "$DB_NAME" ]] && missing+=("DB_NAME")
    [[ -z "$DB_USER" ]] && missing+=("DB_USER")
    [[ -z "$DB_PASS" ]] && missing+=("DB_PASSWORD")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        db_log "ERROR: Missing database configuration: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Test database connectivity (optional)
test_db_connection() {
    db_log "Testing database connection to $DB_HOST:5432/$DB_NAME"
    export PGPASSWORD="$DB_PASS"
    
    if echo "SELECT 1;" | psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A >/dev/null 2>&1; then
        db_log "Database connection successful"
        return 0
    else
        db_log "ERROR: Database connection failed"
        return 1
    fi
}

# Automatically validate connection parameters when sourced
if ! validate_db_connection; then
    echo "ERROR: Database connection validation failed" >&2
    return 1 2>/dev/null || exit 1
fi