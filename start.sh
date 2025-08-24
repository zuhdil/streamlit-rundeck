#!/bin/bash
# Streamlit-Rundeck Deployment System Startup Script
# Automatically detects Docker group ID and starts the services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting Streamlit-Rundeck Deployment System"

# Detect Docker group ID if not already set
if [[ -z "${DOCKER_GID:-}" ]]; then
    echo "🔍 Detecting Docker group ID..."
    DOCKER_GID=$(./get-docker-gid.sh)
    export DOCKER_GID
    echo "✅ Using Docker GID: $DOCKER_GID"
else
    echo "✅ Using provided Docker GID: $DOCKER_GID"
fi

# Check if .env file exists
if [[ ! -f .env ]]; then
    echo "⚠️  Warning: .env file not found. Please create one based on .env.example"
    if [[ -f .env.example ]]; then
        echo "💡 Hint: cp .env.example .env && nano .env"
    fi
fi

# Start services
echo "🐳 Starting Docker services..."
docker compose up "$@"