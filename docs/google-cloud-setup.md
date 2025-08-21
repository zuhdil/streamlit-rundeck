# Google Cloud Setup Guide

This guide provides step-by-step instructions for setting up Google Cloud resources and service accounts required for the Rundeck Streamlit deployment system.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Setup](#project-setup)
3. [Enable Required APIs](#enable-required-apis)
4. [Create Artifact Registry Repository](#create-artifact-registry-repository)
5. [Create Service Account (Web UI)](#create-service-account-web-ui)
6. [Create Service Account (gcloud CLI)](#create-service-account-gcloud-cli)
7. [Grant Permissions](#grant-permissions)
8. [Generate and Download Service Account Key](#generate-and-download-service-account-key)
9. [Verification](#verification)
10. [Security Best Practices](#security-best-practices)
11. [Troubleshooting](#troubleshooting)

## Prerequisites

- Google Cloud Platform account with billing enabled
- Access to create projects and service accounts
- gcloud CLI installed (for CLI method): [Installation Guide](https://cloud.google.com/sdk/docs/install)

## Project Setup

### Option 1: Create New Project (Web UI)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the project dropdown at the top of the page
3. Click "New Project"
4. Enter project details:
   - **Project name**: `streamlit-deployment` (or your preferred name)
   - **Organization**: Select your organization (if applicable)
   - **Location**: Select appropriate location
5. Click "Create"
6. Wait for project creation to complete
7. Make sure the new project is selected in the project dropdown

### Option 2: Create New Project (gcloud CLI)

```bash
# Set your preferred project ID
export PROJECT_ID="streamlit-deployment-$(date +%s)"

# Create new project
gcloud projects create $PROJECT_ID --name="Streamlit Deployment"

# Set as default project
gcloud config set project $PROJECT_ID

# Enable billing (replace BILLING_ACCOUNT_ID with your billing account ID)
# Get billing account ID: gcloud billing accounts list
gcloud billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
```

## Enable Required APIs

### Option 1: Enable APIs (Web UI)

1. In Google Cloud Console, navigate to "APIs & Services" > "Library"
2. Search for and enable the following APIs (click "Enable" for each):

   **Cloud Run API:**
   - Search: "Cloud Run API"
   - Click "Cloud Run API"
   - Click "Enable"

   **Artifact Registry API:**
   - Search: "Artifact Registry API"
   - Click "Artifact Registry API"
   - Click "Enable"

   **Container Registry API:**
   - Search: "Container Registry API"
   - Click "Container Registry API"
   - Click "Enable"

   **Cloud Build API** (recommended):
   - Search: "Cloud Build API"
   - Click "Cloud Build API"
   - Click "Enable"

### Option 2: Enable APIs (gcloud CLI)

```bash
# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Verify APIs are enabled
gcloud services list --enabled --filter="name:(run.googleapis.com OR artifactregistry.googleapis.com OR containerregistry.googleapis.com)"
```

## Create Artifact Registry Repository

### Option 1: Create Repository (Web UI)

1. Navigate to "Artifact Registry" > "Repositories"
2. Click "Create Repository"
3. Configure repository:
   - **Name**: `streamlit-apps`
   - **Format**: Docker
   - **Mode**: Standard
   - **Location**: Choose region closest to your Cloud Run deployments
   - **Encryption**: Google-managed encryption key
4. Click "Create"
5. Note the repository URL format: `REGION-docker.pkg.dev/PROJECT_ID/streamlit-apps`

### Option 2: Create Repository (gcloud CLI)

```bash
# Set variables
export REGION="us-central1"  # Choose your preferred region
export REPOSITORY_NAME="streamlit-apps"

# Create Artifact Registry repository
gcloud artifacts repositories create $REPOSITORY_NAME \
    --repository-format=docker \
    --location=$REGION \
    --description="Repository for Streamlit application images"

# Verify repository creation
gcloud artifacts repositories list --location=$REGION

# Configure Docker authentication
gcloud auth configure-docker $REGION-docker.pkg.dev
```

## Create Service Account (Web UI)

1. Navigate to "IAM & Admin" > "Service Accounts"
2. Click "Create Service Account"
3. Configure service account:
   - **Service account name**: `streamlit-deployer`
   - **Service account ID**: `streamlit-deployer` (auto-generated)
   - **Description**: `Service account for Rundeck Streamlit deployment system`
4. Click "Create and Continue"
5. Skip the "Grant this service account access to project" step for now (we'll do this separately)
6. Click "Continue"
7. Skip the "Grant users access to this service account" step
8. Click "Done"

## Create Service Account (gcloud CLI)

```bash
# Set service account details
export SA_NAME="streamlit-deployer"
export SA_DISPLAY_NAME="Streamlit Deployer"
export SA_DESCRIPTION="Service account for Rundeck Streamlit deployment system"

# Create service account
gcloud iam service-accounts create $SA_NAME \
    --display-name="$SA_DISPLAY_NAME" \
    --description="$SA_DESCRIPTION"

# Verify service account creation
gcloud iam service-accounts list --filter="email:$SA_NAME@"
```

## Grant Permissions

### Option 1: Grant Permissions (Web UI)

1. Navigate to "IAM & Admin" > "IAM"
2. Click "Grant Access"
3. In "New principals" field, enter: `streamlit-deployer@PROJECT_ID.iam.gserviceaccount.com`
4. Click "Select a role" and add the following roles one by one:

   **Required Roles:**
   - `Cloud Run Admin` - Full control of Cloud Run services
   - `Artifact Registry Writer` - Push images to Artifact Registry
   - `Service Usage Consumer` - Access to enabled APIs
   - `Storage Object Viewer` - Read access to GCS (for Cloud Run)

   **Optional but Recommended:**
   - `Cloud Build Editor` - For advanced build scenarios
   - `Compute Network User` - For VPC network access (if needed)

5. Click "Save"

### Option 2: Grant Permissions (gcloud CLI)

```bash
# Set variables
export PROJECT_ID=$(gcloud config get-value project)
export SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# Grant required roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/serviceusage.serviceUsageConsumer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/storage.objectViewer"

# Optional: Grant additional roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/cloudbuild.builds.editor"

# Verify permissions
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --format="table(bindings.role)" \
    --filter="bindings.members:$SA_EMAIL"
```

## Generate and Download Service Account Key

### Option 1: Generate Key (Web UI)

1. Navigate to "IAM & Admin" > "Service Accounts"
2. Find the `streamlit-deployer` service account
3. Click on the three dots menu (⋮) and select "Manage keys"
4. Click "Add Key" > "Create new key"
5. Select "JSON" format
6. Click "Create"
7. The key file will be automatically downloaded to your computer
8. **Important**: Rename the file to `service-account.json`
9. Move the file to the `gcloud/` directory in your project:
   ```bash
   mv ~/Downloads/PROJECT_ID-*.json /path/to/try-rundeck/gcloud/service-account.json
   ```

### Option 2: Generate Key (gcloud CLI)

```bash
# Navigate to your project directory
cd /path/to/try-rundeck

# Create service account key
gcloud iam service-accounts keys create gcloud/service-account.json \
    --iam-account=$SA_EMAIL

# Verify key file was created
ls -la gcloud/service-account.json

# Set secure permissions
chmod 600 gcloud/service-account.json
```

## Verification

### Test Service Account Authentication

```bash
# Set environment variable for testing
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/gcloud/service-account.json"

# Test authentication
gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS

# Test Cloud Run access
gcloud run services list --region=$REGION

# Test Artifact Registry access  
gcloud artifacts repositories list --location=$REGION

# Test Docker authentication
gcloud auth configure-docker $REGION-docker.pkg.dev
```

### Verify Environment Configuration

Create your `.env` file with the correct values:

```bash
# Copy example environment file
cp .env.example .env

# Edit .env file with your values
cat > .env << EOF
# Google Cloud Configuration
GCP_PROJECT_ID=$PROJECT_ID
ARTIFACT_REGISTRY_URL=$REGION-docker.pkg.dev/$PROJECT_ID/streamlit-apps

# GitHub Configuration
GITHUB_API_TOKEN=your-github-token-here

# Rundeck Configuration
RUNDECK_WEBHOOK_SECRET=$(openssl rand -hex 32)
EOF
```

## Security Best Practices

### 1. Key Management

- **Never commit service account keys to version control**
- Store keys securely using secret management systems in production
- Rotate keys regularly (recommended: every 90 days)
- Use minimal permissions (principle of least privilege)

### 2. Access Control

```bash
# Set restrictive permissions on service account key
chmod 600 gcloud/service-account.json

# Ensure the key is git-ignored
echo "gcloud/service-account.json" >> .gitignore
```

### 3. Monitoring

Enable audit logging for service account usage:

1. Navigate to "IAM & Admin" > "Audit Logs"
2. Find "Cloud Run Admin API" and "Artifact Registry API"
3. Enable "Admin Read", "Data Read", and "Data Write" for both services

### 4. Alternative: Workload Identity (Production)

For production deployments, consider using Workload Identity instead of service account keys:

```bash
# Enable Workload Identity on GKE cluster (if using Kubernetes)
gcloud container clusters update CLUSTER_NAME \
    --workload-pool=$PROJECT_ID.svc.id.goog
```

## Troubleshooting

### Common Issues

**1. Permission Denied Errors**
```bash
# Check current project
gcloud config get-value project

# Verify service account permissions
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:$SA_EMAIL"
```

**2. API Not Enabled Errors**
```bash
# List enabled APIs
gcloud services list --enabled

# Enable missing API
gcloud services enable MISSING_API_NAME
```

**3. Artifact Registry Authentication Issues**
```bash
# Reconfigure Docker authentication
gcloud auth configure-docker $REGION-docker.pkg.dev

# Test authentication
docker pull busybox
docker tag busybox $REGION-docker.pkg.dev/$PROJECT_ID/streamlit-apps/test:latest
docker push $REGION-docker.pkg.dev/$PROJECT_ID/streamlit-apps/test:latest
```

**4. Service Account Key Issues**
```bash
# Verify key file format
head -n 5 gcloud/service-account.json

# Test key directly
gcloud auth activate-service-account --key-file=gcloud/service-account.json
```

### Getting Help

**Check quotas and limits:**
```bash
# Check Cloud Run quotas
gcloud run regions describe $REGION

# Check Artifact Registry quotas
gcloud artifacts repositories describe $REPOSITORY_NAME --location=$REGION
```

**Enable additional logging:**
```bash
# Enable audit logs for debugging
gcloud logging read "protoPayload.serviceName=run.googleapis.com" --limit=10
```

## Summary

After completing this setup, you should have:

✅ Google Cloud project with billing enabled  
✅ Required APIs enabled (Cloud Run, Artifact Registry, etc.)  
✅ Artifact Registry repository for container images  
✅ Service account with appropriate permissions  
✅ Service account key file in `gcloud/service-account.json`  
✅ Environment variables configured in `.env` file  

Your Google Cloud environment is now ready for the Rundeck Streamlit deployment system!

## Next Steps

1. Set up GitHub Personal Access Token (see main README.md)
2. Configure Rundeck webhook secret
3. Start the deployment system with `docker compose up -d`
4. Access Rundeck at http://localhost:4440 and test your first deployment