# Azure AI Foundry Access Setup Guide

This guide helps you set up the required Azure RBAC permissions and authentication for the AI agent migration workflows.

## Current Issue: 401 Unauthorized

The `401 Unauthorized` error indicates missing authentication/authorization. You need to:

1. **Create AI Foundry workspaces** (they don't exist yet)
2. **Set up GitHub Actions authentication** (federated identity credentials)
3. **Assign proper RBAC roles** to the service principal

## Step 1: Create AI Foundry Workspaces

First, run the setup script to create the required workspaces:

```powershell
# Run the setup script
.\scripts\setup-ai-foundry.ps1
```

Or create them manually:

```bash
# Install ML extension if not already installed
az extension add --name ml

# Create AI Foundry workspaces
az ml workspace create --name YOUR-DEV-RESOURCE --resource-group rg-YOUR-DEV-RESOURCE --location eastus2
az ml workspace create --name YOUR-TEST-RESOURCE --resource-group rg-YOUR-TEST-RESOURCE --location eastus2  
az ml workspace create --name YOUR-PROD-RESOURCE --resource-group rg-YOUR-PROD-RESOURCE --location eastus2
```

## Step 2: Set Up GitHub Actions Authentication

### Option A: Use Existing Service Principal (if you have one)

If you already have a service principal for GitHub Actions:

```bash
# Get your service principal ID
az ad sp list --display-name "your-github-sp-name" --query "[].id" -o tsv
```

### Option B: Create New Service Principal

```bash
# Create service principal for GitHub Actions
az ad sp create-for-rbac --name "github-actions-ai-foundry" --role contributor --scopes /subscriptions/00000000-0000-0000-0000-000000000000 --sdk-auth

# Note the output - you'll need the clientId, clientSecret, subscriptionId, and tenantId
```

## Step 3: Set Up Federated Identity Credentials

Create federated identity credentials for GitHub Actions to authenticate without secrets:

```bash
# Replace <SERVICE_PRINCIPAL_ID> with your actual service principal ID
# Replace <GITHUB_ORG> and <REPO_NAME> with your GitHub organization and repository

# For main branch
az ad app federated-credential create --id <SERVICE_PRINCIPAL_ID> --parameters '{
  "name": "github-actions-main",
  "issuer": "https://token.actions.githubusercontent.com", 
  "subject": "repo:YOUR-GITHUB-USERNAME/ai-foundry-cicd-lab:ref:refs/heads/main",
  "description": "GitHub Actions main branch",
  "audiences": ["api://AzureADTokenExchange"]
}'

# For environment-based workflows (if using environments)
az ad app federated-credential create --id <SERVICE_PRINCIPAL_ID> --parameters '{
  "name": "github-actions-dev-env",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:YOUR-GITHUB-USERNAME/ai-foundry-cicd-lab:environment:dev", 
  "description": "GitHub Actions dev environment",
  "audiences": ["api://AzureADTokenExchange"]
}'

az ad app federated-credential create --id <SERVICE_PRINCIPAL_ID> --parameters '{
  "name": "github-actions-test-env",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:YOUR-GITHUB-USERNAME/ai-foundry-cicd-lab:environment:test",
  "description": "GitHub Actions test environment", 
  "audiences": ["api://AzureADTokenExchange"]
}'

az ad app federated-credential create --id <SERVICE_PRINCIPAL_ID> --parameters '{
  "name": "github-actions-prod-env",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:YOUR-GITHUB-USERNAME/ai-foundry-cicd-lab:environment:prod",
  "description": "GitHub Actions prod environment",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

## Step 4: Assign RBAC Roles

Assign the **Azure AI Developer** role to your service principal on each AI Foundry workspace:

```bash
# Replace <SERVICE_PRINCIPAL_ID> with your service principal ID

# Dev environment
az role assignment create \
  --assignee <SERVICE_PRINCIPAL_ID> \
  --role "Azure AI Developer" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-DEV-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-DEV-RESOURCE"

# Test environment  
az role assignment create \
  --assignee <SERVICE_PRINCIPAL_ID> \
  --role "Azure AI Developer" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-TEST-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-TEST-RESOURCE"

# Prod environment
az role assignment create \
  --assignee <SERVICE_PRINCIPAL_ID> \
  --role "Azure AI Developer" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-PROD-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-PROD-RESOURCE"
```

## Step 5: Set GitHub Secrets

Add these secrets to your GitHub repository (Settings > Secrets and variables > Actions):

```
AZURE_CLIENT_ID: <service-principal-client-id>
AZURE_TENANT_ID: <your-tenant-id>  
AZURE_SUBSCRIPTION_ID: 00000000-0000-0000-0000-000000000000
```

**Note**: With federated identity credentials, you don't need `AZURE_CLIENT_SECRET`.

## Step 6: Create AI Foundry Projects

After creating workspaces, you need to create projects within them. This is typically done through the Azure AI Foundry portal:

1. Go to [Azure AI Foundry](https://ai.azure.com)
2. Navigate to your workspace
3. Create projects with these names:
   - Dev: `agent-dev-project`
   - Test: `agent-test-project` 
   - Prod: `agent-prod-project`

## Step 7: Update Configuration

Update your `releases/agent_migration.json` with the correct project endpoints after creating the projects:

```json
{
  "environments": {
    "dev": {
      "endpoint": "https://YOUR-DEV-RESOURCE.services.ai.azure.com/api/projects/agent-dev-project"
    }
  }
}
```

## Verification Commands

### Test Authentication
```bash
# Test if you can authenticate and get a token
az account get-access-token --resource 'https://ai.azure.com'
```

### Test Workspace Access
```bash
# List workspaces to verify they exist
az ml workspace list --resource-group rg-YOUR-DEV-RESOURCE

# Show specific workspace
az ml workspace show --name YOUR-DEV-RESOURCE --resource-group rg-YOUR-DEV-RESOURCE
```

### Test API Access
```bash
# Get token and test API access
TOKEN=$(az account get-access-token --resource 'https://ai.azure.com' --query accessToken -o tsv)

# Test project endpoint (replace with your actual endpoint)
curl -H "Authorization: Bearer $TOKEN" \
     "https://YOUR-DEV-RESOURCE.services.ai.azure.com/api/projects/agent-dev-project/assistants?api-version=2025-05-01&limit=1"
```

## Common Issues and Solutions

### Issue: Workspace Creation Fails
```bash
# Make sure ML extension is installed
az extension add --name ml --upgrade
```

### Issue: RBAC Assignment Fails  
```bash
# Verify you have sufficient permissions to assign roles
az role assignment list --assignee <your-user-id> --scope /subscriptions/00000000-0000-0000-0000-000000000000
```

### Issue: Project Not Found (404)
- Verify projects exist in AI Foundry portal
- Check endpoint URLs match exactly
- Ensure project names match configuration

### Issue: Access Denied (403)
- Verify RBAC role assignments
- Check service principal has correct permissions
- Ensure federated identity credentials are set up correctly

## Alternative: Using Azure AI Studio

If AI Foundry is not available, you can use Azure AI Studio instead:

1. Create Azure AI Studio workspaces
2. Use `https://your-workspace.api.azureml.ms` endpoints
3. Assign **AzureML Data Scientist** role instead

## Quick Setup Script

For a complete automated setup, run:

```powershell
# 1. Create workspaces
.\scripts\setup-ai-foundry.ps1

# 2. Set up authentication (manual steps above)
# 3. Create projects in AI Foundry portal
# 4. Update configuration with actual endpoints
```

This will resolve the 401 authentication error and enable agent migration workflows.