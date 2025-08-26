# Rundeck Streamlit Deployment System

A comprehensive CI/CD platform for deploying Streamlit applications from GitHub repositories to Google Cloud Run with automatic webhook-based redeployment.

## Features

- **One-Click Deployment**: Deploy Streamlit apps from GitHub to Cloud Run through Rundeck web interface
- **Automatic CI/CD**: GitHub webhooks trigger automatic redeployments on code pushes
- **Multi-Branch Support**: Deploy different branches as separate services
- **Flexible Branch Detection**: Auto-detect default branch or specify custom branch
- **Secure Secrets Management**: Direct TOML format secrets injection via Rundeck
- **Resource Configuration**: DevOps-managed memory and CPU defaults
- **Access Control**: Role-based permissions for data scientists and administrators
- **Audit Trail**: Complete deployment history and logging

## Quick Start

### Prerequisites

1. Google Cloud Project with enabled APIs:
   - Cloud Run API
   - Artifact Registry API
   - Container Registry API

2. Google Cloud Service Account with required permissions
   - See [Google Cloud Setup Guide](docs/google-cloud-setup.md) for detailed instructions

3. GitHub Personal Access Token with required scopes
   - See [GitHub Setup Guide](docs/github-setup.md) for detailed instructions

### Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd streamlit-rundeck
   ```

2. **Complete Google Cloud setup**:
   - Follow the [Google Cloud Setup Guide](docs/google-cloud-setup.md)
   - This will create your service account and download the key to `gcloud/service-account.json`

3. **Complete GitHub setup**:
   - Follow the [GitHub Setup Guide](docs/github-setup.md)
   - This will create your Personal Access Token

4. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your Google Cloud and GitHub configuration
   ```

5. **Start the system**:
   ```bash
   ./start.sh -d
   ```
   
   **Alternative**: Use Docker Compose directly (requires manual Docker group ID setup):
   ```bash
   DOCKER_GID=$(getent group docker | cut -d: -f3) docker compose up -d
   ```

6. **Access Rundeck**:
   - URL: http://localhost:4440
   - Default credentials: admin/admin

7. **Create the Streamlit project**:
   - Click the "+" button or "New Project" link on the Rundeck home page
   - Project Name: `streamlit-deployments`
   - Description: `Streamlit Application Deployment Pipeline for Data Scientists`
   - Click "Create"

8. **Import job definitions**:
   - Navigate to the `streamlit-deployments` project
   - In the Jobs section, click **"Upload a Job definition"**
   - Upload `rundeck-config/streamlit-deploy-job.yml`
   - Repeat to upload `rundeck-config/webhook-streamlit-redeploy.yml`

9. **Configure webhooks for automatic redeployment**:
   - Follow the [Webhook Setup Guide](docs/WEBHOOK-SETUP.md) to configure Rundeck webhooks
   - This enables automatic redeployment when code is pushed to GitHub

### Updating Job Definitions

When you modify job definition files (e.g., `rundeck-config/streamlit-deploy-job.yml`), you need to update them in Rundeck:

#### Option 1: Re-import through Rundeck Web UI (Recommended)
1. **Access Rundeck**: http://localhost:4440
2. **Navigate to Project**: Go to the `streamlit-deployments` project
3. **Jobs Section**: Click on "Jobs" in the left sidebar
4. **Find Existing Job**: Locate the job you want to update (e.g., "Deploy Streamlit App")
5. **Job Actions**: Click the gear icon → "Upload Definition"
6. **Upload File**: Select your updated job definition file
7. **Update Strategy**: Choose "Update" to replace the existing job

#### Option 2: Use Rundeck CLI (if available)
```bash
# From within the Rundeck container
docker compose exec rundeck rd jobs load -f /rundeck-config/streamlit-deploy-job.yml --project streamlit-deployments
```

#### Option 3: Delete and Re-create
1. **Delete existing job** through Rundeck UI (gear icon → "Delete this Job")
2. **Re-import** the updated job definition file using the upload process

**Note**: Option 1 is recommended as it preserves job execution history and is safer for production environments.

### Environment Variables

Create a `.env` file with the following variables:

```bash
# Google Cloud Configuration
GCP_PROJECT_ID=your-gcp-project-id
ARTIFACT_REGISTRY_URL=your-region-docker.pkg.dev/your-project/your-repo

# GitHub Configuration  
GITHUB_API_TOKEN=your-github-token

# Rundeck Configuration
RUNDECK_WEBHOOK_SECRET=your-webhook-secret
RUNDECK_ADMIN_PASSWORD=your-admin-password
BASE_URL=http://localhost:4440
WEBHOOK_URL=https://your-domain.com/api/53/webhook/your-auth-key#streamlit-redeploy

# Database Configuration (optional - uses defaults if not specified)
DB_HOST=db
DB_NAME=rundeck
DB_USER=rundeck
DB_PASSWORD=rundeckpassword

# Infrastructure Defaults (DevOps Configuration)
DEFAULT_REGION=us-central1
DEFAULT_MEMORY=1Gi
DEFAULT_CPU=1
```

## Usage

### Deploy a Streamlit Application

1. Log into Rundeck web interface
2. Navigate to the "streamlit-deployments" project
3. Run the "Deploy Streamlit App" job with parameters:
   - **GitHub URL**: Repository URL (e.g., `https://github.com/user/repo`)
   - **Main File**: Streamlit entry point (e.g., `app.py`)
   - **App Name**: Unique Cloud Run service name (lowercase, hyphens only)
   - **Target Branch**: Branch to deploy (leave empty for auto-detection)
   - **Secrets**: Direct TOML format `.streamlit/secrets.toml` content (optional)

**Note**: Infrastructure settings (region, memory, CPU) are now managed by DevOps through environment variables and no longer appear in the user interface.

### Multi-Branch Deployments

Deploy different branches as separate services:

```
Repository: github.com/company/dashboard
Branch: main → App: dashboard-prod → URL: https://dashboard-prod-xyz.run.app
Branch: develop → App: dashboard-staging → URL: https://dashboard-staging-xyz.run.app
```

Each deployment:
- Creates its own Cloud Run service
- Has independent webhook monitoring
- Maintains separate deployment metadata

### Automatic Redeployment

After initial deployment and webhook configuration:
1. GitHub webhook is automatically created during deployment
2. Code pushes to the target branch trigger automatic redeployment
3. Application is automatically updated with new code
4. No manual intervention required

For detailed webhook configuration instructions, see the [Webhook Setup Guide](docs/WEBHOOK-SETUP.md).

**Important**: When configuring webhooks in the Rundeck UI, use `-webhook_payload ${raw}` in the Options field to ensure proper JSON payload handling.

## Architecture

### Components

- **Rundeck**: Job orchestration and web interface
- **PostgreSQL**: Deployment metadata storage
- **Docker**: Container runtime for builds
- **Google Cloud SDK**: Cloud Run and Artifact Registry integration
- **Git**: Repository cloning and branch management

### File Structure

```
streamlit-rundeck/
├── compose.yml                    # Docker Compose configuration
├── Dockerfile.rundeck             # Extended Rundeck image
├── start.sh                       # Portable startup script (auto-detects Docker GID)
├── get-docker-gid.sh             # Docker group ID detection utility
├── scripts/                       # Deployment and management scripts
│   ├── deploy-streamlit.sh        # Main deployment logic
│   ├── create-webhook.sh          # GitHub webhook creation
│   ├── webhook-redeploy.sh        # Webhook-triggered redeployment
│   ├── store-deployment.sh        # Metadata storage
│   ├── get-deployment.sh          # Metadata retrieval
│   └── validate-*.sh              # Input validation scripts
├── templates/                     # Dockerfile templates
├── rundeck-config/                # Rundeck job and access control
├── docs/                         # Documentation including webhook setup guide
├── sql/                          # Database schema
└── gcloud/                       # Service account keys
```

### Database Schema

The system uses PostgreSQL tables for deployment tracking:

- **deployments**: Main deployment metadata
- **deployment_history**: Audit trail for all deployments

## Security

### Access Control

- **Data Scientists**: Execute-only permissions for deployment jobs
- **Administrators**: Full system access
- **Webhook User**: Limited to webhook job execution

### Security Features

- Webhook payload signature validation
- GitHub API token with minimal permissions
- Service account principle of least privilege
- Secure secrets handling through Rundeck
- Input validation and sanitization

## Monitoring

### Deployment Tracking

- Real-time deployment logs
- Success/failure metrics
- Deployment history
- Resource utilization monitoring

### Health Checks

- Cloud Run service health monitoring
- Database connectivity checks
- Webhook delivery verification

## Troubleshooting

### Common Issues

1. **Docker build failures**: Check requirements.txt and Dockerfile generation
2. **Cloud Run deployment errors**: Verify service account permissions
3. **Webhook not triggering**: Check GitHub token permissions and webhook configuration
   - See the [Webhook Setup Guide](docs/WEBHOOK-SETUP.md) for detailed troubleshooting
4. **Database connection errors**: Ensure PostgreSQL is running and accessible

### Logs

- Rundeck logs: `docker compose logs rundeck`
- Database logs: `docker compose logs db`
- Deployment logs: Available in Rundeck web interface

## Development

### Adding New Features

1. Create scripts in `scripts/` directory
2. Update job definitions in `rundeck-config/`
3. Modify database schema if needed
4. Update documentation

### Testing

1. Deploy a sample Streamlit application
2. Verify webhook creation and functionality
3. Test multi-branch deployment scenarios
4. Validate access control permissions

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review logs for error details
3. Verify configuration and permissions
4. Test with a simple Streamlit application first

## License

This project is licensed under the MIT License - see the LICENSE file for details.
