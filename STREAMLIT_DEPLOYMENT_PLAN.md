# Rundeck Streamlit Deployment System - Implementation Plan

## Overview

This document outlines the comprehensive implementation plan for extending the existing Rundeck setup to enable Akvo data scientists to deploy Streamlit applications from GitHub repositories to Google Cloud Run through a web-based interface.

## Use Case Requirements

### Primary Workflow
1. Data scientists log into Rundeck with limited access permissions
2. Enter GitHub repository URL containing Streamlit application
3. Specify the main Python file for the Streamlit application
4. Provide secrets configuration through a text area interface
5. Rundeck executes automated deployment pipeline
6. System returns the deployed Cloud Run application URL
7. **CI/CD Enhancement**: System automatically creates GitHub webhook for continuous deployment

### Continuous Deployment Workflow (Enhancement)
1. GitHub webhook is created during initial deployment
2. When code is pushed to the target branch (specified or auto-detected), webhook triggers Rundeck
3. Rundeck automatically redeploys the updated application to Cloud Run
4. No manual intervention required for subsequent deployments

### User Access Model
- **Data Scientists**: Execute-only permissions for deployment jobs
- **Administrators**: Full configuration and management access
- **Audit Trail**: Complete logging of all deployment activities

## Technical Architecture

### Infrastructure Components

#### Current State
- Rundeck 5.14.1 with PostgreSQL backend
- Docker Compose orchestration
- Basic web interface on port 4440

#### Required Extensions
- Google Cloud SDK integration
- Docker CLI access within Rundeck container
- Git client for repository cloning
- Workspace volume for temporary processing

### Service Dependencies
- **GitHub**: Source repository access and webhook management
- **Google Artifact Registry**: Container image storage
- **Google Cloud Run**: Application hosting platform
- **Google Cloud IAM**: Service account authentication
- **Rundeck Webhook API**: Receiving GitHub push notifications

## Implementation Phases

### Phase 1: Infrastructure Setup

#### 1.1 Docker Compose Modifications
**File**: `compose.yml`

**Changes Required**:
- Extend Rundeck service with additional tools
- Add workspace volume for code processing
- Configure environment variables for Google Cloud authentication
- Ensure network connectivity to external services

**New Volume Mounts**:
```yaml
volumes:
  - workspace:/tmp/workspace
  - gcloud-config:/root/.config/gcloud
```

**Additional Environment Variables**:
```yaml
environment:
  - GOOGLE_APPLICATION_CREDENTIALS=/etc/rundeck/service-account.json
  - PROJECT_ID=${GCP_PROJECT_ID}
  - ARTIFACT_REGISTRY=${ARTIFACT_REGISTRY_URL}
  - GITHUB_TOKEN=${GITHUB_API_TOKEN}
  - WEBHOOK_SECRET=${RUNDECK_WEBHOOK_SECRET}
```

#### 1.2 Service Account Configuration
**Google Cloud Requirements**:
- Artifact Registry Writer permissions
- Cloud Run Admin permissions
- Service Usage Consumer permissions

**GitHub API Requirements**:
- Personal Access Token or GitHub App with webhooks:write and contents:read permissions
- Repository access for webhook creation

**Authentication Setup**:
- Mount service account JSON key in Rundeck container
- Configure gcloud authentication in startup script
- Store GitHub token securely in environment variables

### Phase 2: Core Deployment Components

#### 2.1 Main Deployment Script
**File**: `scripts/deploy-streamlit.sh`

**Functionality**:
- Validate input parameters
- Clone GitHub repository to workspace
- Generate dynamic Dockerfile
- Create `.streamlit/secrets.toml` from user input
- Build and tag container image
- Push to Artifact Registry
- Deploy to Cloud Run
- **Create GitHub webhook for automatic redeployment**
- **Store deployment metadata for webhook processing**
- Return service URL and webhook confirmation

**Error Handling**:
- Repository access validation
- Docker build failure recovery
- Registry authentication checks
- Cloud Run deployment verification

**Script Parameters**:
- `GITHUB_URL`: Repository URL
- `MAIN_FILE`: Streamlit entry point
- `SECRETS_CONTENT`: Base64 encoded secrets
- `APP_NAME`: Cloud Run service name
- `REGION`: Deployment region
- `PROJECT_ID`: Google Cloud Project
- `TARGET_BRANCH`: Branch to deploy (optional, auto-detects default if empty)

#### 2.2 Dynamic Dockerfile Template
**File**: `templates/streamlit.dockerfile.template`

**Features**:
- Base Python runtime selection
- Automatic requirements.txt detection
- Configurable entry point
- Port exposure (8080 for Cloud Run)
- Health check configuration

**Template Structure**:
```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
RUN mkdir -p .streamlit

EXPOSE 8080
HEALTHCHECK CMD curl --fail http://localhost:8080/_stcore/health

CMD ["streamlit", "run", "{MAIN_FILE}", "--server.port=8080", "--server.address=0.0.0.0"]
```

#### 2.3 Webhook Management Scripts
**File**: `scripts/create-webhook.sh`

**Functionality**:
- Create GitHub webhook using GitHub API
- Configure webhook to trigger on push events to specified or auto-detected target branch
- Set webhook URL to Rundeck webhook endpoint
- Configure webhook secret for payload validation
- Return webhook ID for future management

**File**: `scripts/webhook-redeploy.sh`

**Functionality**:
- Validate GitHub webhook payload and signature
- Extract repository information and commit details
- Lookup existing deployment metadata from database
- Execute redeployment with updated code
- Filter for target branch pushes only (matches stored branch for each deployment)
- Log webhook-triggered deployment activities

#### 2.4 Deployment Metadata Management
**Database Schema Enhancement**:
```sql
CREATE TABLE deployments (
  id SERIAL PRIMARY KEY,
  app_name VARCHAR(255) UNIQUE NOT NULL,
  github_url VARCHAR(500) NOT NULL,
  main_file VARCHAR(100) NOT NULL,
  secrets_content TEXT,
  region VARCHAR(50) NOT NULL,
  target_branch VARCHAR(100) NOT NULL,
  webhook_id VARCHAR(50),
  cloud_run_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Phase 3: Rundeck Job Configuration

#### 3.1 Initial Deployment Job Definition
**File**: `rundeck-config/streamlit-deploy-job.yml`

**Job Parameters**:
- `github_url` (String, Required): GitHub repository URL
- `main_file` (String, Required, Default: "app.py"): Streamlit entry point
- `secrets_content` (Secure String, Optional): Contents for secrets.toml
- `app_name` (String, Required): Cloud Run service name
- `target_branch` (String, Optional): Branch to deploy and monitor (auto-detects default branch if empty)
- `region` (Select, Required): GCP region
  - Options: us-central1, europe-west1, asia-southeast1
- `memory` (Select, Optional, Default: "1Gi"): Container memory limit
- `cpu` (Select, Optional, Default: "1"): Container CPU allocation

**Job Steps**:
1. **Parameter Validation**: Verify required inputs
2. **Workspace Preparation**: Create clean working directory
3. **Repository Clone**: Download source code
4. **Container Build**: Execute deployment script
5. **Service Deployment**: Deploy to Cloud Run
6. **Webhook Creation**: Set up GitHub webhook for CI/CD
7. **Metadata Storage**: Store deployment information in database
8. **URL Reporting**: Display deployed application URL and webhook status

#### 3.2 Job Execution Flow
```yaml
sequence:
  keepgoing: false
  strategy: node-first
  commands:
    - exec: '/scripts/validate-inputs.sh "${option.github_url}" "${option.main_file}" "${option.app_name}"'
    - exec: '/scripts/prepare-workspace.sh "${job.id}" "${job.execid}"'
    - exec: '/scripts/deploy-streamlit.sh'
      env:
        GITHUB_URL: '${option.github_url}'
        MAIN_FILE: '${option.main_file}'
        SECRETS_CONTENT: '${option.secrets_content}'
        APP_NAME: '${option.app_name}'
        TARGET_BRANCH: '${option.target_branch}'
        REGION: '${option.region}'
        MEMORY: '${option.memory}'
        CPU: '${option.cpu}'
```

#### 3.3 Webhook-Triggered Redeployment Job
**File**: `rundeck-config/webhook-streamlit-redeploy.yml`

**Job Configuration**:
- **Trigger**: Webhook endpoint `/api/webhook/streamlit-redeploy`
- **Authentication**: Webhook secret validation
- **Input**: GitHub push event payload (JSON)

**Job Parameters** (extracted from webhook payload):
- Repository URL from payload
- Commit SHA and branch information
- Pusher information for audit trail

**Job Steps**:
1. **Payload Validation**: Verify webhook signature and payload structure
2. **Branch Filter**: Only process pushes to the target branch stored in deployment metadata
3. **Deployment Lookup**: Find existing deployment metadata by repository and verify branch match
4. **Code Update**: Clone latest repository version from target branch
5. **Redeployment**: Execute deployment pipeline with existing configuration
6. **Notification**: Log successful redeployment (optional: notify users)

### Phase 4: Access Control & Security

#### 4.1 User Role Configuration
**File**: `rundeck-config/user-roles.aclpolicy`

**Data Scientist Role**:
- Project: streamlit-deployments
- Resource access: jobs (read, run)
- Node access: none required
- Admin access: none

**Administrator Role**:
- Full system access
- Job configuration permissions
- User management capabilities

#### 4.2 Project Structure
**Project Name**: `streamlit-deployments`
**Description**: "Streamlit Application Deployment Pipeline"

**Project Configuration**:
- Isolated from other Rundeck projects
- Dedicated execution environment
- Separate audit logging
- Resource quotas (if needed)

#### 4.3 Security Considerations
- Secrets handling through Rundeck's secure input
- Service account principle of least privilege
- Repository URL validation (GitHub only)
- Container image scanning (optional)
- Network policies for external access
- **Webhook payload signature validation using HMAC-SHA256**
- **GitHub API token with minimal required permissions**
- **Rate limiting on webhook endpoints to prevent abuse**
- **IP allowlist for GitHub webhook sources**
- **Branch filtering to prevent unauthorized deployments (matches stored target branch)**

### Phase 5: Monitoring & Logging

#### 5.1 Job Execution Monitoring
- Real-time log streaming during deployment
- Step-by-step progress indicators
- Error notification system
- Deployment success/failure metrics
- **Webhook-triggered deployment tracking and logging**
- **Automatic vs manual deployment distinction in audit logs**

#### 5.2 Application Monitoring
- Cloud Run service health checks
- Resource utilization tracking
- Cost monitoring per deployment
- Usage analytics for data science teams

## File Structure

```
try-rundeck/
├── compose.yml                              # Updated Docker Compose
├── scripts/
│   ├── deploy-streamlit.sh                  # Main deployment script
│   ├── create-webhook.sh                    # GitHub webhook creation
│   ├── webhook-redeploy.sh                  # Webhook-triggered redeployment
│   ├── validate-inputs.sh                   # Input validation
│   ├── validate-webhook.sh                  # Webhook payload validation
│   ├── prepare-workspace.sh                 # Workspace management
│   └── cleanup-workspace.sh                 # Post-deployment cleanup
├── templates/
│   └── streamlit.dockerfile.template        # Dynamic Dockerfile
├── rundeck-config/
│   ├── streamlit-deploy-job.yml            # Initial deployment job definition
│   ├── webhook-streamlit-redeploy.yml      # Webhook-triggered job definition
│   ├── user-roles.aclpolicy                # Access control
│   └── project-config.properties           # Project settings
├── sql/
│   └── deployment-schema.sql               # Database schema for deployment tracking
├── gcloud/
│   └── service-account.json                # GCP authentication (git-ignored)
└── STREAMLIT_DEPLOYMENT_PLAN.md            # This documentation
```

## Development Guidelines

### Code Quality Standards
- All shell scripts must include error handling and logging
- Parameter validation for all user inputs
- Comprehensive documentation for each component
- Unit tests for critical deployment logic

### Security Requirements
- No hardcoded credentials in any files
- Service account key rotation procedures
- Input sanitization for all user-provided data
- Secure temporary file handling

### Testing Strategy
- Local development environment setup
- Integration testing with Google Cloud services
- User acceptance testing with data science team
- Performance testing for concurrent deployments

## Deployment Steps

### Prerequisites
1. Google Cloud Project with required APIs enabled
2. Service account with appropriate permissions
3. Artifact Registry repository created
4. Domain/DNS configuration for Cloud Run (optional)

### Installation Process
1. Update Docker Compose configuration
2. Create required directories and files
3. Configure service account authentication
4. Set up GitHub API token for webhook management
5. Create deployment tracking database schema
6. Import Rundeck job definitions (both initial and webhook-triggered)
7. Configure webhook endpoint and security settings
8. Set up user roles and permissions
9. Test deployment with sample application
10. Verify webhook creation and automatic redeployment

### Post-Deployment Verification
- Test complete deployment workflow (initial deployment)
- Verify GitHub webhook creation and configuration
- Test automatic redeployment by pushing code changes
- Verify user access controls for both job types
- Validate Cloud Run service functionality
- Check logging and monitoring setup
- Verify webhook payload validation and security

## Maintenance Procedures

### Regular Tasks
- Service account key rotation
- GitHub API token rotation
- Docker image updates
- Rundeck plugin updates
- Log cleanup and archival
- **Webhook health monitoring and cleanup of inactive webhooks**
- **Deployment metadata cleanup for removed applications**

### Troubleshooting Guide
- Common deployment failures and solutions
- Network connectivity issues
- Authentication problems
- Resource quota limitations
- **Webhook delivery failures and GitHub connectivity issues**
- **Webhook payload validation errors**
- **Automatic redeployment troubleshooting**
- **Database connectivity issues for deployment metadata**

## Success Metrics

### Technical Metrics
- Deployment success rate (target: >95%)
- Average deployment time (target: <5 minutes)
- System uptime (target: >99.5%)
- Error resolution time
- **Webhook delivery success rate (target: >98%)**
- **Automatic redeployment success rate (target: >95%)**
- **Time from code push to live deployment (target: <3 minutes)**

### User Experience Metrics
- User adoption rate
- Support ticket volume
- User satisfaction scores
- Training completion rates

## Future Enhancements

### Potential Features
- Multiple cloud provider support
- Advanced deployment strategies (blue-green, canary)
- Automated scaling configuration
- **Pull request preview deployments via GitHub webhooks**
- **Integration with GitHub Actions for advanced CI/CD workflows**
- **Slack/Teams notifications for deployment events**
- **Automatic rollback on deployment failures**
- Cost optimization recommendations

### Scalability Considerations
- Multi-region deployment support
- Horizontal scaling of Rundeck
- Database performance optimization
- Container registry optimization

---

**Document Version**: 2.1
**Last Updated**: 2025-08-21
**Author**: Implementation Team
**Review Status**: Enhanced with CI/CD Automation and Flexible Branch Support

## Summary of Enhancements

This enhanced version includes GitHub webhook automation and flexible branch management to provide complete continuous deployment capabilities. Key additions:

- **Automatic Webhook Creation**: Initial deployment creates GitHub webhooks
- **Flexible Branch Support**: Optional branch parameter with auto-detection of default branch
- **Push-Triggered Redeployments**: Code pushes to target branch automatically redeploy applications
- **Multi-Branch Deployment**: Different branches can be deployed as separate services using different app names
- **Deployment Metadata Tracking**: Database schema to manage webhook-to-deployment mappings with branch information
- **Enhanced Security**: Webhook payload validation and signature verification
- **Complete CI/CD Pipeline**: Transform from one-time deployment to full automation platform

The system now provides data scientists with both initial deployment capabilities and ongoing continuous deployment for any branch (specified or auto-detected), requiring no manual intervention after the initial setup.

---

This document serves as the authoritative reference for implementing the Rundeck Streamlit deployment system with full CI/CD automation. All implementation decisions should align with the specifications outlined here to ensure consistency and maintainability.