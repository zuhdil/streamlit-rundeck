#!/bin/bash

# Workspace Preparation Script
# Prepares clean workspace for deployment

set -euo pipefail

# Arguments
JOB_ID="$1"
EXEC_ID="$2"

WORKSPACE_BASE="/tmp/workspace"
WORKSPACE="$WORKSPACE_BASE/${JOB_ID}-${EXEC_ID}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PREPARE-WS: $*"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "Preparing workspace: $WORKSPACE"

# Create workspace directory
mkdir -p "$WORKSPACE" || error "Failed to create workspace directory"

# Set permissions
chmod 755 "$WORKSPACE" || error "Failed to set workspace permissions"

# Clean any existing content
if [[ -d "$WORKSPACE" ]]; then
    log "Cleaning existing workspace content"
    rm -rf "${WORKSPACE:?}"/* 2>/dev/null || true
fi

# Create subdirectories
mkdir -p "$WORKSPACE"/{logs,temp,app} || error "Failed to create workspace subdirectories"

# Export workspace path for other scripts
echo "WORKSPACE=$WORKSPACE" > "/tmp/workspace_${JOB_ID}_${EXEC_ID}.env"

log "Workspace prepared successfully: $WORKSPACE"

# Set up cleanup on script exit
cat > "$WORKSPACE/cleanup.sh" << 'EOF'
#!/bin/bash
WORKSPACE=$(dirname "$0")
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning up workspace: $WORKSPACE"
cd /tmp
rm -rf "$WORKSPACE" 2>/dev/null || true
EOF

chmod +x "$WORKSPACE/cleanup.sh"

log "Cleanup script created"