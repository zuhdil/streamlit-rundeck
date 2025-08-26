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

### General Tab Configuration

| Field | Value | Description |
|-------|-------|-------------|
| **Name** | `streamlit-redeploy` | Descriptive name for the webhook |
| **User** | (leave blank) | Username for authorization (optional) |
| **Roles** | (leave blank) | Authorization roles (optional) |
| **Enabled** | ✅ Checked | Webhook must be enabled to function |

**HTTP Authorization String**: Leave "Use Authorization Header" unchecked unless you need additional security.

### Handler Configuration Tab

Switch to the **"Handler Configuration"** tab and configure:

| Field | Value | Description |
|-------|-------|-------------|
| **Plugin** | `Run Job` | Select this handler type |
| **Job** | `Webhook Streamlit Redeploy (streamlit-deployments)` | Click "Choose A Job" and select the webhook job |
| **Options** | `-webhook_payload ${raw}` | **Critical**: Use ${raw} for proper JSON payload handling |
| **Node Filter** | (leave blank) | Leave blank for default |
| **As User** | (leave blank) | Username to run job as (optional) |

3. **Save the Webhook**
   - Click **"Save"** button (top right)
   - The webhook will be created and you'll see a confirmation

## Step 3: Get the Webhook URL

After creating the webhook, Rundeck will generate a unique URL:

1. **Find the Webhook URL**
   - In the Webhooks list, click on your created webhook
   - Copy the complete **"Post URL"** - it will look like:
     ```
     https://your-domain.com/api/53/webhook/1yd5iB2TlCRiD91psA7wKdnnBvoSLQs#streamlit-redeploy
     ```

2. **Copy the Complete URL**
   - Copy the entire URL exactly as shown in the Post URL field
   - The format is: `https://your-domain.com/api/{version}/webhook/{auth-key}#{webhook-name}`

## Step 4: Update Environment Configuration

Add the complete webhook URL to your environment:

1. **Update .env file**
   ```bash
   # Add this line to your .env file (use your actual webhook URL)
   WEBHOOK_URL=https://your-domain.com/api/53/webhook/1yd5iB2TlCRiD91psA7wKdnnBvoSLQs#streamlit-redeploy
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

**Note**: GitHub periodically sends "ping" events to test webhook endpoints. These are automatically handled and will show as successful executions with a "zen" message in the logs.

## Troubleshooting

### Common Issues

**Webhook not triggering:**
- Verify webhook URL is correct in GitHub
- Check that webhook job is enabled in Rundeck
- Ensure WEBHOOK_URL matches the exact URL from Rundeck UI

**Job fails with "Option 'webhook_payload' is required", "Failed to substitute data", or webhook_payload shows as 'null':**
- Use the working configuration: `-webhook_payload ${raw}` in the Options field
- If ${raw} doesn't work, try these alternatives in order:
  1. **Leave Options field completely empty** - Rundeck may pass data via stdin or environment
  2. Try: `-webhook_payload ${data}` (alternative variable name)
  3. Try: `-webhook_payload ${webhook.data}` (older format)
  4. Check Rundeck version - some versions have different webhook variable formats
- The webhook job will now handle the null payload case and provide better error messages
- Re-edit the webhook in Rundeck UI and verify the Handler Configuration tab

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
     https://your-domain.com/api/53/webhook/your-auth-key#streamlit-redeploy
   ```

3. **Verify Environment Variables**
   ```bash
   # Check if webhook URL is loaded
   docker compose exec rundeck env | grep WEBHOOK_URL
   ```

## Security Considerations

- **Auth Key Protection**: Keep webhook auth keys secure - they allow job execution
- **Network Access**: Ensure webhook URLs are only accessible to GitHub's IP ranges if possible
- **Webhook URL Security**: Rundeck webhook URLs contain authentication tokens that provide secure access
- **Job Permissions**: Webhook jobs run with specific user permissions - ensure appropriate access controls

## Next Steps

Once webhooks are working:
- Monitor job execution logs regularly
- Set up alerting for failed webhook executions
- Consider implementing webhook rate limiting if needed
- Document your specific webhook configurations for team members

For advanced webhook configurations and enterprise features, refer to the official Rundeck documentation.