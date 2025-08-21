# GitHub Setup Guide

This guide provides step-by-step instructions for creating a GitHub Personal Access Token (PAT) required for the Rundeck Streamlit deployment system to access repositories and manage webhooks.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Create Personal Access Token (Classic)](#create-personal-access-token-classic)
3. [Create Fine-Grained Personal Access Token](#create-fine-grained-personal-access-token)
4. [Configure Token in Environment](#configure-token-in-environment)
5. [Test Token Permissions](#test-token-permissions)
6. [Security Best Practices](#security-best-practices)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

- GitHub account with access to repositories you want to deploy
- Repository permissions (owner or admin access for webhook management)
- Access to organization repositories (if deploying org-owned repos)

## Create Personal Access Token (Classic)

### Step 1: Access Developer Settings

1. Log into [GitHub](https://github.com)
2. Click your profile picture in the top-right corner
3. Select "Settings" from the dropdown menu
4. In the left sidebar, scroll down and click "Developer settings"
5. Click "Personal access tokens" > "Tokens (classic)"

### Step 2: Generate New Token

1. Click "Generate new token" > "Generate new token (classic)"
2. You may be prompted to confirm your password or use two-factor authentication

### Step 3: Configure Token Settings

**Token Configuration:**
- **Note**: `Rundeck Streamlit Deployer`
- **Expiration**: Choose appropriate expiration (90 days recommended for security)

**Required Scopes** (check the following boxes):

**For Public Repositories:**
- ✅ `public_repo` - Access public repositories
- ✅ `admin:repo_hook` - Full control of repository hooks

**For Private Repositories:**
- ✅ `repo` - Full control of private repositories
- ✅ `admin:repo_hook` - Full control of repository hooks

**Additional Recommended Scopes:**
- ✅ `read:user` - Read user profile data
- ✅ `user:email` - Access user email addresses

### Step 4: Generate and Save Token

1. Click "Generate token"
2. **IMPORTANT**: Copy the token immediately and save it securely
3. The token will look like: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
4. **You cannot see this token again** - save it now!

## Create Fine-Grained Personal Access Token

Fine-grained tokens provide more granular permissions and are recommended for enhanced security.

### Step 1: Access Fine-Grained Tokens

1. In GitHub, go to "Settings" > "Developer settings"
2. Click "Personal access tokens" > "Fine-grained tokens"
3. Click "Generate new token"

### Step 2: Configure Token

**Basic Information:**
- **Token name**: `Rundeck Streamlit Deployer`
- **Expiration**: 90 days (recommended)
- **Description**: `Token for Rundeck to deploy Streamlit apps and manage webhooks`

**Resource Access:**
- **Selected repositories**: Choose specific repositories you want to deploy
- OR **All repositories**: If you want access to all your repositories

### Step 3: Set Repository Permissions

**Required Permissions:**
- **Contents**: Read (to clone repositories)
- **Metadata**: Read (to access repository information)
- **Webhooks**: Write (to create and manage webhooks)

**Optional Permissions:**
- **Actions**: Read (if using GitHub Actions)
- **Issues**: Read (for integration features)
- **Pull requests**: Read (for future PR deployment features)

### Step 4: Generate Token

1. Click "Generate token"
2. Copy and save the token securely
3. Fine-grained tokens start with `github_pat_`

## Configure Token in Environment

### Option 1: Add to .env File

```bash
# Navigate to your project directory
cd /path/to/try-rundeck

# Edit .env file
nano .env

# Add or update the GitHub token line
GITHUB_API_TOKEN=your_token_here
```

### Option 2: Set Environment Variable

```bash
# Set for current session
export GITHUB_API_TOKEN="your_token_here"

# Add to your shell profile for persistence
echo 'export GITHUB_API_TOKEN="your_token_here"' >> ~/.bashrc
source ~/.bashrc
```

### Option 3: Docker Compose Override

For production deployments, use Docker secrets or external secret management:

```yaml
# docker-compose.override.yml
version: '3.8'
services:
  rundeck:
    environment:
      GITHUB_TOKEN: ${GITHUB_API_TOKEN}
```

## Test Token Permissions

### Test 1: Repository Access

```bash
# Set token for testing
export GITHUB_TOKEN="your_token_here"

# Test repository access (replace with your repo)
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/repos/username/repository

# Should return repository information in JSON format
```

### Test 2: Webhook Management

```bash
# List existing webhooks (replace with your repo)
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/repos/username/repository/hooks

# Should return array of webhooks (may be empty)
```

### Test 3: Default Branch Detection

```bash
# Get repository default branch
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/repos/username/repository | \
     jq -r '.default_branch'

# Should return branch name (e.g., "main" or "master")
```

### Test 4: File Access

```bash
# Check if a file exists in repository
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/repos/username/repository/contents/app.py

# Should return file information or 404 if not found
```

## Security Best Practices

### 1. Token Security

- **Never commit tokens to version control**
- Use environment variables or secret management systems
- Set appropriate expiration dates (90 days recommended)
- Regenerate tokens regularly

### 2. Scope Limitation

- Use minimum required scopes
- Prefer fine-grained tokens for better security
- Limit repository access to only needed repositories

### 3. Monitoring

Enable security monitoring for your tokens:

1. Go to GitHub "Settings" > "Developer settings" > "Personal access tokens"
2. Monitor token usage in the "Recent activity" section
3. Set up GitHub security alerts for your account

### 4. Rotation

Create a token rotation schedule:

```bash
# Create reminder for token rotation
echo "GitHub Token expires on: $(date -d '+90 days')" > token_expiry_reminder.txt
```

## Troubleshooting

### Common Issues

**1. 401 Unauthorized Error**
```bash
# Check token format
echo $GITHUB_TOKEN | wc -c
# Classic tokens: 40 characters + prefix
# Fine-grained tokens: longer with github_pat_ prefix

# Test token validity
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

**2. 403 Forbidden - Insufficient Permissions**
```bash
# Check token scopes
curl -H "Authorization: token $GITHUB_TOKEN" -I https://api.github.com/user | grep "x-oauth-scopes"

# Common missing scopes:
# - admin:repo_hook (for webhook management)
# - repo (for private repositories)
```

**3. Repository Not Found**
```bash
# Verify repository exists and is accessible
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/repos/OWNER/REPO

# Check if token has access to the repository
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/user/repos | grep -i "REPO_NAME"
```

**4. Webhook Creation Fails**
```bash
# Check webhook permissions specifically
curl -X POST \
     -H "Authorization: token $GITHUB_TOKEN" \
     -H "Accept: application/vnd.github.v3+json" \
     -d '{"name":"web","config":{"url":"http://example.com","content_type":"json"}}' \
     https://api.github.com/repos/OWNER/REPO/hooks
```

### Rate Limiting

GitHub API has rate limits. Check your current usage:

```bash
# Check rate limit status
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/rate_limit
```

Rate limits:
- **Classic tokens**: 5,000 requests per hour
- **Fine-grained tokens**: 5,000 requests per hour
- **Unauthenticated**: 60 requests per hour

### Organization Repositories

For organization-owned repositories:

1. **Organization Settings**: The organization may need to approve personal access tokens
2. **SSO Requirements**: Some organizations require SSO authentication for tokens
3. **Third-party Access**: Check if third-party access restrictions apply

```bash
# Check if SSO is required
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/orgs/ORGANIZATION_NAME

# Look for "two_factor_requirement_enabled" in response
```

## Token Management Script

Create a helper script to manage tokens:

```bash
#!/bin/bash
# github-token-test.sh

TOKEN="$1"
REPO="$2"

if [[ -z "$TOKEN" ]] || [[ -z "$REPO" ]]; then
    echo "Usage: $0 <token> <owner/repo>"
    exit 1
fi

echo "Testing GitHub token permissions..."

# Test 1: Basic authentication
echo "1. Testing authentication..."
USER=$(curl -s -H "Authorization: token $TOKEN" https://api.github.com/user | jq -r '.login // "ERROR"')
if [[ "$USER" == "ERROR" ]]; then
    echo "❌ Authentication failed"
    exit 1
fi
echo "✅ Authenticated as: $USER"

# Test 2: Repository access
echo "2. Testing repository access..."
REPO_INFO=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/repos/$REPO")
REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name // "ERROR"')
if [[ "$REPO_NAME" == "ERROR" ]]; then
    echo "❌ Repository access failed"
    exit 1
fi
echo "✅ Repository accessible: $REPO_NAME"

# Test 3: Webhook permissions
echo "3. Testing webhook permissions..."
HOOKS=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/repos/$REPO/hooks")
if echo "$HOOKS" | jq -e '. | type == "array"' > /dev/null; then
    echo "✅ Webhook access confirmed"
else
    echo "❌ Webhook access failed"
    exit 1
fi

echo "🎉 All tests passed! Token is ready for use."
```

Make it executable and test:

```bash
chmod +x github-token-test.sh
./github-token-test.sh "your_token" "username/repository"
```

## Summary

After completing this setup, you should have:

✅ GitHub Personal Access Token created  
✅ Token configured with appropriate scopes  
✅ Token added to environment variables  
✅ Token permissions tested and verified  
✅ Security best practices implemented  

Your GitHub integration is now ready for the Rundeck Streamlit deployment system!

## Next Steps

1. Complete Google Cloud setup (see google-cloud-setup.md)
2. Configure webhook secret in .env file
3. Start the deployment system
4. Test your first Streamlit deployment