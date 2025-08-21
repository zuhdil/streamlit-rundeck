#!/bin/bash

# Workspace Cleanup Script
# Cleans up temporary files and workspaces

set -euo pipefail

# Arguments (optional)
JOB_ID="${1:-}"
EXEC_ID="${2:-}"

WORKSPACE_BASE="/tmp/workspace"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CLEANUP: $*"
}

if [[ -n "$JOB_ID" ]] && [[ -n "$EXEC_ID" ]]; then
    # Clean specific workspace
    WORKSPACE="$WORKSPACE_BASE/${JOB_ID}-${EXEC_ID}"
    log "Cleaning specific workspace: $WORKSPACE"
    
    if [[ -d "$WORKSPACE" ]]; then
        rm -rf "$WORKSPACE" || log "WARNING: Failed to remove workspace $WORKSPACE"
        log "Workspace cleaned: $WORKSPACE"
    else
        log "Workspace not found: $WORKSPACE"
    fi
    
    # Clean environment file
    ENV_FILE="/tmp/workspace_${JOB_ID}_${EXEC_ID}.env"
    if [[ -f "$ENV_FILE" ]]; then
        rm -f "$ENV_FILE" || log "WARNING: Failed to remove environment file"
    fi
else
    # Clean old workspaces (older than 1 hour)
    log "Cleaning old workspaces (older than 1 hour)"
    
    if [[ -d "$WORKSPACE_BASE" ]]; then
        find "$WORKSPACE_BASE" -mindepth 1 -maxdepth 1 -type d -mtime +0.04 -exec rm -rf {} \; 2>/dev/null || true
        log "Old workspaces cleaned"
    fi
    
    # Clean old environment files
    find /tmp -name "workspace_*.env" -mtime +0.04 -delete 2>/dev/null || true
    
    # Clean old log files
    find /tmp -name "*.log" -mtime +1 -delete 2>/dev/null || true
fi

# Clean Docker images older than 24 hours (if Docker is available)
if command -v docker &> /dev/null; then
    log "Cleaning old Docker images"
    docker image prune -f --filter "until=24h" 2>/dev/null || log "WARNING: Docker cleanup failed"
fi

log "Cleanup completed"