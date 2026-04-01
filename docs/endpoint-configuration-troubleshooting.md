# AI Foundry Endpoint Configuration Troubleshooting

## Issue Summary

The agent migration encountered 401 Unauthorized errors due to endpoint configuration mismatches between the expected AI Foundry service endpoints and the actual Azure ML workspace endpoints.

## Root Cause Analysis

### Expected Configuration
The original configuration used AI Foundry service endpoints:
```
https://YOUR-DEV-RESOURCE.services.ai.azure.com/api/projects/agent-dev-project
```

### Actual Infrastructure
The created workspaces use Azure ML service endpoints:
```
https://eastus2.api.azureml.ms/discovery
```

### Authentication Mismatch
- Original scripts used `https://ai.azure.com` resource for token authentication
- Azure ML workspaces require `https://ml.azure.com` resource for token authentication

## Resolution Strategy

### Option 1: AI Foundry Projects (Recommended)

Create proper AI Foundry projects within the existing workspaces:

1. **Run Project Setup Script**:
   ```powershell
   .\scripts\setup-ai-foundry-projects.ps1
   ```

2. **Manual Project Creation** (if script fails):
   - Navigate to [AI Foundry portal](https://ai.azure.com)
   - Create projects within existing workspaces:
     - `agent-dev-project` in `YOUR-DEV-RESOURCE` workspace
     - `agent-test-project` in `YOUR-TEST-RESOURCE` workspace  
     - `agent-prod-project` in `YOUR-PROD-RESOURCE` workspace

3. **Update Configuration**:
   Use the updated `agent_migration_updated.json` configuration with correct endpoints.

### Option 2: Azure ML Workspace Direct Access

Use Azure ML workspace endpoints directly:

1. **Authentication**: Use `https://ml.azure.com` resource
2. **Endpoints**: Use Azure ML format:
   ```
   https://eastus2.api.azureml.ms/raisvc/v1.0/subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.MachineLearningServices/workspaces/{workspace}/assistants
   ```
3. **API Version**: Use `2024-05-01-preview`

## Updated Configuration Files

### agent_migration_updated.json
- ✅ Correct Azure ML workspace endpoints
- ✅ Updated authentication resource (`https://ml.azure.com`)
- ✅ Proper API version (`2024-05-01-preview`)
- ✅ Correct resource group (`default`)

### Updated Scripts
- ✅ `migrate-agent.ps1`: Updated authentication and endpoints
- ✅ GitHub Actions workflow: Updated token acquisition and API calls
- ✅ `setup-ai-foundry-projects.ps1`: Creates proper AI Foundry projects

## Authentication Setup

### Required RBAC Roles
For Azure ML workspace access:
- **Azure Machine Learning Data Scientist** (workspace scope)
- **Azure AI Developer** (if AI Foundry projects exist)

### Service Principal Setup
Update GitHub Actions with service principal that has:
1. `Azure Machine Learning Data Scientist` role on workspaces
2. `Azure AI Developer` role on AI Foundry projects (when created)

### Token Testing
Test authentication with both approaches:

```powershell
# Test Azure ML token
$mlToken = az account get-access-token --resource 'https://ml.azure.com' --query accessToken -o tsv

# Test AI services token  
$aiToken = az account get-access-token --resource 'https://cognitiveservices.azure.com' --query accessToken -o tsv
```

## Next Steps

1. **Immediate**: Run `setup-ai-foundry-projects.ps1` to create proper projects
2. **Configuration**: Update workflows to use `agent_migration_updated.json`
3. **Authentication**: Verify service principal roles for GitHub Actions
4. **Testing**: Test migration with updated configuration

## Validation Commands

Test workspace access:
```bash
az ml workspace show --name YOUR-DEV-RESOURCE --resource-group default
```

Test AI Foundry project access (after creation):
```bash
curl -H "Authorization: Bearer $ML_TOKEN" \
  "https://YOUR-DEV-RESOURCE.services.ai.azure.com/api/projects/agent-dev-project/assistants?api-version=2024-05-01-preview"
```

## Expected Outcomes

After proper setup:
- ✅ GitHub Actions workflow succeeds with 200 responses
- ✅ Agent migration completes successfully
- ✅ Cross-environment agent promotion works
- ✅ Authentication errors resolved