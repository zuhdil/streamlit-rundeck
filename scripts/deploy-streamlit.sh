#!/bin/bash

# Streamlit Application Deployment Script
# Deploys Streamlit apps from GitHub to Google Cloud Run with webhook automation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_BASE="/tmp/workspace"
LOG_FILE="/tmp/deployment.log"

# Required environment variables
: "${GITHUB_URL:?GITHUB_URL is required}"
: "${MAIN_FILE:?MAIN_FILE is required}"
: "${APP_NAME:?APP_NAME is required}"
: "${PROJECT_ID:?PROJECT_ID is required}"
: "${ARTIFACT_REGISTRY:?ARTIFACT_REGISTRY is required}"

# Optional environment variables
SECRETS_CONTENT="${SECRETS_CONTENT:-}"
TARGET_BRANCH="${TARGET_BRANCH:-}"
REGION="${DEFAULT_REGION:-us-central1}"
MEMORY="${DEFAULT_MEMORY:-1Gi}"
CPU="${DEFAULT_CPU:-1}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Error handling
error() {
    log "ERROR: $*"
    exit 1
}

# Cleanup function
cleanup() {
    if [[ -d "$WORKSPACE" ]]; then
        log "Cleaning up workspace: $WORKSPACE"
        rm -rf "$WORKSPACE"
    fi
}
trap cleanup EXIT

# Initialize workspace
WORKSPACE="$WORKSPACE_BASE/$(date +%s)-$$"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

log "Starting deployment of $APP_NAME from $GITHUB_URL"

# Step 1: Validate inputs
log "Step 1: Validating inputs"
if [[ ! "$GITHUB_URL" =~ ^https://github\.com/.+/.+$ ]]; then
    error "Invalid GitHub URL format: $GITHUB_URL"
fi

if [[ ! "$APP_NAME" =~ ^[a-z0-9-]+$ ]]; then
    error "Invalid app name format: $APP_NAME (use lowercase letters, numbers, and hyphens only)"
fi

# Step 2: Detect or validate target branch
log "Step 2: Processing target branch"
if [[ -z "$TARGET_BRANCH" ]]; then
    log "Auto-detecting default branch for repository"
    REPO_PATH=$(echo "$GITHUB_URL" | sed 's|https://github.com/||' | sed 's|\.git$||')
    
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        TARGET_BRANCH=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/$REPO_PATH" | jq -r '.default_branch // empty')
    fi
    
    if [[ -z "$TARGET_BRANCH" ]]; then
        log "Could not detect default branch via API, trying common defaults"
        TARGET_BRANCH="main"
    fi
    
    log "Using auto-detected branch: $TARGET_BRANCH"
else
    log "Using specified target branch: $TARGET_BRANCH"
fi

# Step 3: Clone repository
log "Step 3: Cloning repository"
git clone --branch "$TARGET_BRANCH" --depth 1 "$GITHUB_URL" app || error "Failed to clone repository"
cd app

# Verify main file exists
if [[ ! -f "$MAIN_FILE" ]]; then
    error "Main file '$MAIN_FILE' not found in repository"
fi

# Step 4: Generate Dockerfile
log "Step 4: Generating Dockerfile"
cat > Dockerfile << EOF
FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt* ./
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Install streamlit if not in requirements
RUN pip install --no-cache-dir streamlit

# Copy application code
COPY . .

# Create streamlit directory
RUN mkdir -p .streamlit

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \\
    CMD curl --fail http://localhost:8080/_stcore/health || exit 1

# Expose port
EXPOSE 8080

# Run streamlit
CMD ["streamlit", "run", "$MAIN_FILE", "--server.port=8080", "--server.address=0.0.0.0", "--server.headless=true"]
EOF

# Step 5: Create secrets file if provided
if [[ -n "$SECRETS_CONTENT" ]]; then
    # Trim leading and trailing whitespace
    SECRETS_CONTENT=$(echo "$SECRETS_CONTENT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    if [[ -n "$SECRETS_CONTENT" ]]; then
        log "Step 5: Creating secrets configuration"
        mkdir -p .streamlit
        echo "$SECRETS_CONTENT" > .streamlit/secrets.toml
    else
        log "Step 5: Secrets content was empty after trimming, skipping"
    fi
else
    log "Step 5: No secrets provided, skipping"
fi

# Step 6: Build and push container
log "Step 6: Building container image"
IMAGE_TAG="$ARTIFACT_REGISTRY/$APP_NAME:$(date +%Y%m%d-%H%M%S)"
LATEST_TAG="$ARTIFACT_REGISTRY/$APP_NAME:latest"

# Configure Docker to use gcloud for authentication
gcloud auth configure-docker "${ARTIFACT_REGISTRY%%/*}" --quiet || error "Failed to configure Docker authentication"

# Build image
docker build -t "$IMAGE_TAG" -t "$LATEST_TAG" . || error "Failed to build Docker image"

# Push image
log "Pushing image to registry"
docker push "$IMAGE_TAG" || error "Failed to push image tag: $IMAGE_TAG"
docker push "$LATEST_TAG" || error "Failed to push latest tag: $LATEST_TAG"

# Step 7: Deploy to Cloud Run
log "Step 7: Deploying to Cloud Run"
gcloud run deploy "$APP_NAME" \\
    --image="$LATEST_TAG" \\
    --platform=managed \\
    --region="$REGION" \\
    --allow-unauthenticated \\
    --memory="$MEMORY" \\
    --cpu="$CPU" \\
    --project="$PROJECT_ID" \\
    --quiet || error "Failed to deploy to Cloud Run"

# Get service URL
SERVICE_URL=$(gcloud run services describe "$APP_NAME" \\
    --region="$REGION" \\
    --project="$PROJECT_ID" \\
    --format="value(status.url)") || error "Failed to get service URL"

log "Application deployed successfully!"
log "Service URL: $SERVICE_URL"

# Step 8: Create GitHub webhook
log "Step 8: Creating GitHub webhook"
if [[ -n "${GITHUB_TOKEN:-}" ]] && [[ -n "${WEBHOOK_SECRET:-}" ]]; then
    WEBHOOK_URL="${RUNDECK_GRAILS_URL:-http://localhost:4440}/api/webhook/streamlit-redeploy"
    
    "$SCRIPT_DIR/create-webhook.sh" "$GITHUB_URL" "$TARGET_BRANCH" "$WEBHOOK_URL" "$WEBHOOK_SECRET" || {
        log "WARNING: Failed to create webhook, but deployment succeeded"
    }
else
    log "WARNING: GitHub token or webhook secret not provided, skipping webhook creation"
fi

# Step 9: Store deployment metadata
log "Step 9: Storing deployment metadata"
"$SCRIPT_DIR/store-deployment.sh" \\
    "$APP_NAME" \\
    "$GITHUB_URL" \\
    "$MAIN_FILE" \\
    "$TARGET_BRANCH" \\
    "$REGION" \\
    "$SERVICE_URL" \\
    "${SECRETS_CONTENT:-}" || {
    log "WARNING: Failed to store deployment metadata"
}

log "Deployment completed successfully!"
log "Application URL: $SERVICE_URL"
log "Monitoring branch: $TARGET_BRANCH"

# Output for Rundeck job
echo "========================================="
echo "DEPLOYMENT SUCCESSFUL"
echo "========================================="
echo "App Name: $APP_NAME"
echo "Service URL: $SERVICE_URL"
echo "Target Branch: $TARGET_BRANCH"
echo "Region: $REGION"
echo "Image: $LATEST_TAG"
echo "========================================="