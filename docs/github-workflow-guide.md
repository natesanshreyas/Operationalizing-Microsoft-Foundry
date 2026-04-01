# GitHub Workflow Guide: Portal Agent Migration

This guide explains how to use the updated GitHub workflow for migrating AI agents between Azure AI Foundry environments using our streamlined Portal-only approach.

## Overview

The `promote-agent.yml` workflow has been updated to use the new **Portal-only migration script** (`migrate-portal-agent.ps1`), which:

- ✅ Creates agents that are **visible in the AI Foundry portal**
- ✅ Uses the correct **Portal API endpoints**
- ✅ Handles **authentication automatically**
- ✅ Provides **comprehensive validation and testing**
- ✅ Generates **detailed migration reports**

## Prerequisites

### 1. Azure OIDC Authentication Setup
Ensure your repository has the following secrets configured:
- `AZURE_CLIENT_ID` - Service Principal Client ID
- `AZURE_TENANT_ID` - Azure Tenant ID  
- `AZURE_SUBSCRIPTION_ID` - Azure Subscription ID

### 2. Service Principal Permissions
Your service principal needs:
- **Azure AI User** role on both source and target AI Foundry projects
- **Reader** role on the resource groups containing AI Foundry resources

### 3. Configuration File
Ensure `releases/agent_migration.json` contains the correct environment configurations with `project_name` fields:

```json
{
  "environments": {
    "dev": {
      "ai_foundry_resource_name": "YOUR-DEV-RESOURCE",
      "resource_group": "rg-YOUR-DEV-RESOURCE",
      "subscription_id": "00000000-0000-0000-0000-000000000000",
      "project_name": "agent-dev-project"
    },
    "test": {
      "ai_foundry_resource_name": "YOUR-TEST-RESOURCE", 
      "resource_group": "rg-YOUR-TEST-RESOURCE",
      "subscription_id": "00000000-0000-0000-0000-000000000000",
      "project_name": "agent-test-project"
    },
    "prod": {
      "ai_foundry_resource_name": "YOUR-PROD-RESOURCE",
      "resource_group": "rg-YOUR-PROD-RESOURCE", 
      "subscription_id": "00000000-0000-0000-0000-000000000000",
      "project_name": "agent-prod-project"
    }
  }
}
```

## How to Run the Workflow

### 1. Navigate to GitHub Actions
1. Go to your repository on GitHub
2. Click on the **Actions** tab
3. Select **Promote AI Agent** workflow

### 2. Trigger the Workflow
1. Click **Run workflow**
2. Fill in the required parameters:

| Parameter | Description | Example |
|-----------|-------------|---------|
| **Source Environment** | Environment to migrate from | `dev` |
| **Target Environment** | Environment to migrate to | `test` |
| **Agent Name** | Name of the agent to migrate | `Agent589` |
| **Create New Version** | Whether to create new version if agent exists | `true` (default) |

### 3. Monitor the Workflow
The workflow will execute the following steps:

1. **Validate Inputs** - Ensures parameters are valid
2. **Azure Login** - Authenticates using OIDC
3. **Load Configuration** - Reads environment settings
4. **Verify Azure Access** - Confirms subscription access
5. **Install PowerShell** - Sets up PowerShell runtime
6. **Run Portal Agent Migration** - Executes the migration script
7. **Validation Summary** - Confirms successful migration
8. **Copy Migration Artifacts** - Prepares reports for upload
9. **Upload Artifacts** - Saves migration reports and exports
10. **Summary** - Displays final migration results

## What the Workflow Does

### PowerShell Migration Script Execution
The workflow calls `migrate-portal-agent.ps1` with your parameters, which:

- 🔍 **Discovers** the source agent using Portal API
- 📤 **Exports** the agent configuration
- 🔍 **Checks** if agent exists in target environment
- 🚀 **Creates** the new agent in target Portal API
- ✅ **Validates** the migrated agent
- 📊 **Generates** comprehensive migration report

### Portal Visibility
Unlike the previous dual-system approach, this workflow ensures:
- Agents are created using the **Portal API** (`*.services.ai.azure.com`)
- Agents are **immediately visible** in the AI Foundry portal interface
- **Clean, maintainable** single-system approach

## Workflow Outputs

### GitHub Outputs
The workflow provides these outputs for integration:
- `new_agent_id` - ID of the created/updated agent
- `final_agent_name` - Final name of the migrated agent  
- `target_project` - Target project name where agent was created

### Artifacts
The workflow uploads migration artifacts including:
- **Migration Report** - Detailed report of the migration process
- **Export Files** - Agent configuration exports
- **Validation Results** - Testing and validation outcomes

### Example Output
```
🎉 Portal Agent migration completed successfully!

📋 Migration Summary:
  Source: dev → Target: test
  Agent: Agent589 → Agent589
  New Agent ID: asst_EXAMPLE_AGENT_ID_002
  Target Project: agent-test-project

✅ The Portal agent has been successfully migrated and is visible in AI Foundry portal.
📁 Migration artifacts have been uploaded for your records.
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify OIDC secrets are correctly configured
   - Check service principal has required permissions
   - Ensure correct subscription and tenant IDs

2. **Agent Not Found**
   - Verify agent name exists in source environment
   - Check agent was created using Portal API (visible in portal)
   - Confirm correct project name in configuration

3. **Permission Issues**  
   - Ensure service principal has "Azure AI User" role on projects
   - Verify resource group reader access
   - Check cross-subscription permissions if applicable

### Getting Help

1. **Review Workflow Logs** - Check GitHub Actions run logs for detailed error messages
2. **Download Artifacts** - Review migration reports for additional context
3. **Check Configuration** - Verify `agent_migration.json` settings
4. **Test Locally** - Run `migrate-portal-agent.ps1` locally for troubleshooting

## Advantages of Portal-Only Migration

### ✅ Simplified Architecture
- Single API system (Portal API only)
- Cleaner, more maintainable code
- Reduced complexity and error points

### ✅ Portal Visibility
- Agents immediately visible in portal interface
- Full portal management capabilities
- Consistent user experience

### ✅ Enterprise Ready
- Cross-subscription support
- Comprehensive validation and testing
- Detailed audit trails and reporting

### ✅ Developer Friendly
- Clear error messages and troubleshooting
- Comprehensive logging and artifacts
- Easy integration with CI/CD pipelines

## Migration from Old Workflow

If you were using the previous dual-system workflow:

1. **Existing Agents**: Continue to work with both old and new migrations
2. **New Migrations**: Use this Portal-only approach for better portal visibility  
3. **Configuration**: Update `agent_migration.json` to include `project_name` fields
4. **Testing**: Validate that migrated agents appear in the portal interface

The new workflow is backward compatible and will handle both scenarios seamlessly.