# Rundeck Webhook Setup Guide

This guide explains how to configure Rundeck webhooks for automatic Streamlit application redeployment when GitHub repositories are updated.

## Prerequisites

- Rundeck server running and accessible
- Admin access to Rundeck web interface
- Webhook job definition loaded in Rundeck
- GitHub repository with webhook permissions

## Step 1: Load the Webhook Job Definition

First, ensure the webhook job is loaded in Rundeck:

1. **Access Rundeck Web Interface**
   - Navigate to `http://localhost:4440` (or your configured BASE_URL)
   - Login with your admin credentials (default: `admin`/`admin`)

2. **Import the Webhook Job**
   - Click on **"Jobs"** in the top navigation
   - Click **"Actions"** → **"Upload Definition"**
   - Choose the file `rundeck-config/webhook-streamlit-redeploy.yml`
   - Select **"Update"** for the import behavior
   - Click **"Upload"**
   - Verify the job appears as "Webhook Streamlit Redeploy"

## Step 2: Create a Webhook in Rundeck

1. **Navigate to Webhooks**
   - In the project view, click **"Webhooks"** in the left sidebar
   - If you don't see the Webhooks option, ensure you're in a project (not the home page)

2. **Create New Webhook**
   - Click **"Create Webhook"** or **"Add Webhook"**
   - Fill in the webhook configuration:

### Basic Configuration

| Field | Value | Description |
|-------|-------|-------------|
| **Name** | `streamlit-redeploy` | Descriptive name for the webhook |
| **Trigger** | `Run Job` | Select this option to trigger a job execution |
| **Job** | `Webhook Streamlit Redeploy` | Select the imported webhook job |

### Advanced Configuration (if available)

| Field | Value | Description |
|-------|-------|-------------|
| **Authentication** | `None` or `Basic` | Leave as None for GitHub webhooks |
| **Content Type** | `application/json` | Ensures JSON payload processing |
| **Enabled** | ✅ Checked | Webhook must be enabled to function |

3. **Configure Job Parameters (Important)**
   
   The webhook needs to map GitHub payload data to job options:

   **For webhook_payload option:**
   - **Source**: `Webhook JSON Data`
   - **JSONPath**: `$` (entire payload)
   - **Description**: Maps the complete GitHub webhook payload

   **For webhook_signature option:**
   - **Source**: `Header Value`  
   - **Header Name**: `X-Hub-Signature-256`
   - **Description**: GitHub webhook signature for validation

4. **Save the Webhook**
   - Click **"Create"** or **"Save"**
   - The webhook will be created and you'll see a confirmation

## Step 3: Get the Webhook URL

After creating the webhook, Rundeck will generate a unique URL:

1. **Find the Webhook URL**
   - In the Webhooks list, click on your created webhook
   - Copy the **"Post URL"** - it will look like:
     ```
     https://your-domain.com/api/19/webhook/abc123def456/webhook-streamlit-redeploy
     ```

2. **Extract the Auth Key**
   - From the URL above, the auth key is the part after `/webhook/` and before the next `/`
   - In this example: `abc123def456`

## Step 4: Update Environment Configuration

Add the webhook auth key to your environment:

1. **Update .env file**
   ```bash
   # Add this line to your .env file
   WEBHOOK_AUTH_KEY=abc123def456
   ```

2. **Restart Services**
   ```bash
   docker compose down
   ./start.sh -d
   ```

## Step 5: Test the Webhook

### Test via Rundeck UI

1. **Manual Test**
   - Go to the Webhooks page
   - Click **"Test"** next to your webhook
   - Send a sample JSON payload:
     ```json
     {
       "ref": "refs/heads/main",
       "repository": {
         "clone_url": "https://github.com/username/repo.git",
         "full_name": "username/repo"
       },
       "head_commit": {
         "id": "abc123"
       },
       "pusher": {
         "name": "testuser"
       }
     }
     ```

### Test via GitHub

1. **Deploy a Streamlit App**
   - Use the main deployment job to deploy an app
   - This will automatically create the GitHub webhook

2. **Trigger via Git Push**
   - Push changes to the monitored repository branch
   - Check the job execution history in Rundeck

## Step 6: Verify Webhook Operation

### Check Job Execution

1. **View Job History**
   - Go to **Jobs** → **Webhook Streamlit Redeploy**
   - Click **"Activity"** to see execution history
   - Recent webhook-triggered executions should appear

2. **Review Logs**
   - Click on any execution to view detailed logs
   - Look for webhook payload processing messages
   - Verify deployment steps completed successfully

### GitHub Webhook Status

1. **Check GitHub Repository**
   - Go to your GitHub repository → **Settings** → **Webhooks**
   - Click on the webhook entry
   - Check **"Recent Deliveries"** for status codes:
     - ✅ `200`: Webhook successful
     - ❌ `4xx/5xx`: Check Rundeck logs for errors

## Troubleshooting

### Common Issues

**Webhook not triggering:**
- Verify webhook URL is correct in GitHub
- Check that webhook job is enabled in Rundeck
- Ensure WEBHOOK_AUTH_KEY matches the generated URL

**Job fails with "No deployment found":**
- The repository must be deployed via the main job first
- Webhook only triggers for branches that have been deployed

**Authentication errors:**
- Check that webhook secret matches between GitHub and Rundeck
- Verify X-Hub-Signature-256 header is being passed correctly

### Debug Steps

1. **Enable Debug Logging**
   - Add debug output to the webhook job if needed
   - Check Rundeck server logs: `docker compose logs rundeck`

2. **Test Webhook URL Manually**
   ```bash
   curl -X POST \
     -H "Content-Type: application/json" \
     -d '{"ref":"refs/heads/main","repository":{"clone_url":"https://github.com/test/repo.git"}}' \
     https://your-domain.com/api/19/webhook/your-auth-key/webhook-streamlit-redeploy
   ```

3. **Verify Environment Variables**
   ```bash
   # Check if auth key is loaded
   docker compose exec rundeck env | grep WEBHOOK
   ```

## Security Considerations

- **Auth Key Protection**: Keep webhook auth keys secure - they allow job execution
- **Network Access**: Ensure webhook URLs are only accessible to GitHub's IP ranges if possible
- **Signature Validation**: Always validate webhook signatures to prevent unauthorized triggers
- **Job Permissions**: Webhook jobs run with specific user permissions - ensure appropriate access controls

## Next Steps

Once webhooks are working:
- Monitor job execution logs regularly
- Set up alerting for failed webhook executions
- Consider implementing webhook rate limiting if needed
- Document your specific webhook configurations for team members

For advanced webhook configurations and enterprise features, refer to the official Rundeck documentation.