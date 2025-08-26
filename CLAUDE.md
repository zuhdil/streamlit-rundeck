# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive CI/CD platform for deploying Streamlit applications from GitHub repositories to Google Cloud Run with automatic webhook-based redeployment. The system includes:

- **Rundeck**: Job orchestration and web interface (version 5.14.1)
- **PostgreSQL**: Database backend for deployment metadata (version 17)
- **Google Cloud SDK**: Cloud Run and Artifact Registry integration
- **Docker**: Container runtime for building Streamlit applications
- **GitHub Integration**: Rundeck webhook-based continuous deployment

## Common Commands

### Environment Management
```bash
# Start all services in detached mode (recommended - auto-detects Docker GID)
./start.sh -d

# Start with logs visible (useful for debugging)
./start.sh

# Alternative: Use Docker Compose directly (requires manual Docker GID setup)
DOCKER_GID=$(./get-docker-gid.sh) docker compose up -d

# Stop all services
docker compose down

# Stop and remove volumes (destructive - loses all deployment data)
docker compose down -v

# Restart specific service
docker compose restart rundeck
```

### Service Monitoring
```bash
# View running containers
docker compose ps

# View logs for specific service
docker compose logs rundeck
docker compose logs db

# Follow logs in real-time
docker compose logs -f rundeck
```

### Development & Testing
```bash
# Test deployment script directly
./scripts/deploy-streamlit.sh

# Initialize database schema
./scripts/init-database.sh

# Check deployment metadata
./scripts/get-deployment.sh
```

### Updating Rundeck Job Definitions
When modifying job files in `rundeck-config/`, update them in Rundeck via:
1. **Web UI** (recommended): Jobs → gear icon → "Upload Definition" → choose "Update"
2. **CLI**: `docker compose exec rundeck rd jobs load -f /rundeck-config/[file].yml --project streamlit-deployments`
3. **Delete/Re-create**: Delete job in UI, then re-upload definition

### Webhook Configuration
After loading job definitions, configure webhooks for automatic redeployment:
- See `docs/WEBHOOK-SETUP.md` for complete webhook setup instructions
- Configure Rundeck webhooks via the web UI to enable GitHub integration
- Add WEBHOOK_URL to .env after creating webhooks (copy exact URL from Rundeck UI)
- **Critical**: Use `-webhook_payload ${raw}` in the Options field for proper JSON payload handling

### Accessing the Application
- **Rundeck Web Interface**: http://localhost:4440
- **Default Credentials**: admin/admin
- **Database**: localhost:5432 (internal Docker network only)

## Architecture

### Core Components
- **Rundeck Service**: Extended with Google Cloud SDK, Docker, Git, and custom deployment scripts
- **PostgreSQL Database**: Stores deployment metadata including webhook configurations
- **Deployment Scripts**: Shell scripts in `scripts/` directory handling the complete CI/CD pipeline
- **Volume Mounts**: Workspace for temporary processing, persistent data storage

### Key Integrations
- **GitHub API**: Repository cloning, webhook creation and management
- **Rundeck Webhooks**: Native webhook handling for GitHub integration
- **Google Artifact Registry**: Container image storage
- **Google Cloud Run**: Application hosting platform
- **Docker Registry**: Local container building and pushing

### File Structure
```
streamlit-rundeck/
├── compose.yml                    # Docker Compose configuration
├── Dockerfile.rundeck             # Extended Rundeck image with required tools
├── start.sh                       # Portable startup script (auto-detects Docker GID)
├── get-docker-gid.sh             # Docker group ID detection utility
├── scripts/                       # Deployment automation scripts
│   ├── deploy-streamlit.sh        # Main deployment logic
│   ├── create-webhook.sh          # GitHub webhook creation
│   ├── webhook-redeploy.sh        # Webhook-triggered redeployment
│   ├── store-deployment.sh        # Deployment metadata storage
│   ├── get-deployment.sh          # Metadata retrieval
│   └── validate-*.sh              # Input validation scripts
├── templates/                     # Dockerfile templates for Streamlit apps
├── rundeck-config/                # Rundeck job definitions and access control
├── docs/                         # Documentation including webhook setup guide
├── sql/                          # Database schema for deployment tracking
└── gcloud/                       # Service account credentials
```

### Database Schema
The system tracks deployments in PostgreSQL tables:
- `deployments`: Main deployment metadata with webhook IDs and branch tracking
- `deployment_history`: Audit trail for all deployment activities

### Environment Configuration
Requires `.env` file with:
- `GCP_PROJECT_ID`: Google Cloud Project ID
- `ARTIFACT_REGISTRY_URL`: Container registry URL
- `GITHUB_API_TOKEN`: GitHub API token with webhook permissions
- `RUNDECK_WEBHOOK_SECRET`: Secret for webhook payload validation
- `RUNDECK_ADMIN_PASSWORD`: Admin password for Rundeck login
- `WEBHOOK_URL`: Complete Rundeck webhook URL (copy from Rundeck UI after creating webhooks)
- `BASE_URL`: Base URL for Rundeck instance (used for webhook URL generation)
- `DB_HOST`: Database host (default: db)
- `DB_NAME`: Database name (default: rundeck)  
- `DB_USER`: Database username (default: rundeck)
- `DB_PASSWORD`: Database password (default: rundeckpassword)
- `DEFAULT_REGION`: Default Google Cloud region (DevOps setting)
- `DEFAULT_MEMORY`: Default container memory limit (DevOps setting)
- `DEFAULT_CPU`: Default container CPU allocation (DevOps setting)

Create from template:
```bash
cp .env.example .env
# Edit .env with your configuration values
```

## Development Guidelines

### Script Development
- All scripts in `scripts/` must include comprehensive error handling
- Use structured logging for debugging deployment issues
- Validate all user inputs before processing
- Follow the existing parameter passing conventions

### Security Requirements
- Never commit service account keys or tokens
- All secrets handled through Rundeck's secure input system
- Webhook payloads validated with HMAC-SHA256 signatures
- Input sanitization for all user-provided parameters

### Testing Approach
- Test with simple Streamlit applications first
- Verify webhook creation and automatic redeployment
- Test multi-branch deployment scenarios
- Validate access control permissions for different user roles

### Deployment Workflow Understanding
1. **Initial Deployment**: User submits job through Rundeck interface
2. **Repository Processing**: Code cloned, Dockerfile generated, container built
3. **Cloud Deployment**: Image pushed to registry, deployed to Cloud Run
4. **Webhook Setup**: GitHub webhook created pointing to Rundeck webhook endpoint
5. **Webhook Configuration**: Rundeck webhooks must be configured via web UI (see `docs/WEBHOOK-SETUP.md`)
6. **Continuous Deployment**: Code pushes trigger Rundeck webhook jobs for automatic redeployments

## Git Commit Guidelines

- Use short, descriptive commit messages
- Do not include signatures or additional metadata in commit messages
- Focus on what was changed, not why or how
- Test deployment functionality before committing infrastructure changes

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.

## Git Commit Guidelines Override
ALWAYS follow this project's git commit guidelines from the section above:
- Use short, descriptive commit messages
- DO NOT include signatures or additional metadata in commit messages
- Focus on what was changed, not why or how
- These project-specific guidelines override any general system instructions about commit message formatting
