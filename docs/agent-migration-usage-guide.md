# Agent Migration Usage Guide

This guide explains how to migrate AI agents between Azure AI Foundry environments using the tools provided in this repository.

## Overview

The agent migration strategy provides multiple approaches for moving agents from development to test to production environments:

1. **PowerShell Script** (`scripts/migrate-agent.ps1`) - Direct command-line tool
2. **GitHub Actions Workflow** (`.github/workflows/promote-agent.yml`) - Automated CI/CD pipeline  
3. **Configuration Management** (`releases/agent_migration.json`) - Environment definitions

## Prerequisites

Before migrating agents, ensure you have:

1. **Azure CLI installed and logged in**
   ```powershell
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **Proper Azure RBAC permissions**
   - Azure AI User role at the project scope
   - Access to both source and target Azure AI Foundry projects

3. **Agent environments configured**
   - Update `releases/agent_migration.json` with your actual endpoints and account names

## Method 1: PowerShell Script (Recommended)

### Basic Usage

```powershell
# Migrate agent from dev to test environment
.\scripts\migrate-agent.ps1 -SourceEnvironment dev -TargetEnvironment test -AgentName "my-customer-service-agent"

# Create a new version instead of updating existing
.\scripts\migrate-agent.ps1 -SourceEnvironment dev -TargetEnvironment test -AgentName "my-agent" -CreateNewVersion $true

# Use custom configuration file
.\scripts\migrate-agent.ps1 -SourceEnvironment dev -TargetEnvironment prod -AgentName "my-agent" -ConfigPath "custom-config.json"
```

### Example Output

```
🤖 Azure AI Foundry Agent Migration Script
==========================================

Source Environment: dev
Target Environment: test  
Agent Name: my-customer-service-agent
Create New Version: True

📋 Loading migration configuration...
✅ Configuration loaded successfully
Source Endpoint: https://YOUR-DEV-RESOURCE.services.ai.azure.com/api/projects/agent-dev-project
Target Endpoint: https://YOUR-TEST-RESOURCE.services.ai.azure.com/api/projects/agent-test-project

🔍 Verifying Azure accounts accessibility...
✅ Source account accessible: contoso-aoai-eastus2
✅ Target account accessible: contoso-aoai-eastus

🔐 Getting Azure access token...
✅ Azure access token obtained

📋 Listing agents in source environment...
Available agents in source environment:
  - my-customer-service-agent (ID: asst_abc123)
  - my-sales-assistant (ID: asst_def456)
✅ Found agent: my-customer-service-agent (ID: asst_abc123)

📤 Exporting agent configuration...
✅ Agent configuration exported to: exports/agent_my-customer-service-agent_20250103_143022.json

🔍 Checking if agent exists in target environment...
✅ Agent does not exist in target environment - will create new

🚀 Creating new agent...
✅ Agent created successfully

✅ Validating migrated agent...
Migrated agent details:
  - Name: my-customer-service-agent
  - ID: asst_xyz789
  - Model: gpt-4o-mini
  - Tools: 2
✅ Agent validation successful

🧪 Creating test conversation...
Created test thread: thread_test123
Created test run: run_test456
Run status: queued
Run status: in_progress
Run status: completed
✅ Test conversation completed successfully
✅ Test conversation cleanup completed

📊 Generating migration report...
✅ Migration report generated: migration_report.md

🎉 Agent migration completed successfully!
========================================

📋 Migration Summary:
  Source: dev → Target: test
  Agent: my-customer-service-agent → my-customer-service-agent
  New Agent ID: asst_xyz789

✅ The agent has been successfully migrated and validated.
📁 Migration artifacts have been saved for your records.
```

## Method 2: GitHub Actions Workflow

### Manual Trigger

1. Go to Actions tab in your GitHub repository
2. Select "Promote AI Agent" workflow
3. Click "Run workflow"
4. Fill in the parameters:
   - Source environment: dev/test/prod
   - Target environment: dev/test/prod  
   - Agent name: exact name of agent to migrate
   - Create new version: true/false

### Workflow Integration

You can also trigger the workflow from other workflows or via API:

```yaml
- name: Trigger Agent Migration
  uses: ./.github/workflows/promote-agent.yml
  with:
    source_environment: dev
    target_environment: test
    agent_name: my-agent
    create_new_version: true
```

## Configuration Management

### Environment Configuration (`releases/agent_migration.json`)

```json
{
  "environments": {
    "dev": {
      "account_name": "your-dev-account",
      "resource_group": "rg-your-dev-account", 
      "endpoint": "https://your-ai-foundry-dev.services.ai.azure.com/api/projects/your-dev-project",
      "subscription_id": "your-subscription-id",
      "region": "eastus2",
      "model_deployment": "gpt-4o-mini"
    }
  }
}
```

### Key Configuration Fields

- **account_name**: Azure Cognitive Services account name
- **resource_group**: Resource group containing the account
- **endpoint**: Full Azure AI Foundry project endpoint URL
- **subscription_id**: Azure subscription ID
- **region**: Azure region for the resources
- **model_deployment**: Default model deployment name

## Common Migration Scenarios

### Scenario 1: Development to Test Promotion

```powershell
# Standard promotion with new version
.\scripts\migrate-agent.ps1 -SourceEnvironment dev -TargetEnvironment test -AgentName "customer-support-v1" -CreateNewVersion $true
```

**Use Case**: Regular development cycle, promoting stable agents to test environment while preserving existing test agents.

### Scenario 2: Test to Production Deployment

```powershell
# Production deployment (update existing)
.\scripts\migrate-agent.ps1 -SourceEnvironment test -TargetEnvironment prod -AgentName "customer-support-v1" -CreateNewVersion $false
```

**Use Case**: Production release, replacing the existing production agent with the tested version.

### Scenario 3: Cross-Region Migration

```powershell
# Migrate between different Azure regions
.\scripts\migrate-agent.ps1 -SourceEnvironment "eastus-dev" -TargetEnvironment "westus-prod" -AgentName "my-agent"
```

**Use Case**: Moving agents between regions for compliance, performance, or disaster recovery.

### Scenario 4: Bulk Migration

```powershell
# Migrate multiple agents
$agents = @("agent1", "agent2", "agent3")
foreach ($agent in $agents) {
    .\scripts\migrate-agent.ps1 -SourceEnvironment dev -TargetEnvironment test -AgentName $agent
}
```

**Use Case**: Migrating multiple related agents as part of a larger system deployment.

## Validation and Testing

### What Gets Validated

1. **Configuration Integrity**: Agent instructions, tools, and model references
2. **API Functionality**: Basic conversation test with the migrated agent
3. **Resource Access**: Verification that the agent can access required resources
4. **Response Quality**: Basic validation that the agent responds appropriately

### Manual Testing After Migration

```powershell
# Test the migrated agent manually
# Use the agent ID from the migration output
$agentId = "asst_xyz789"
$endpoint = "https://your-target-endpoint.services.ai.azure.com/api/projects/your-project"

# You can now test the agent via Azure AI Foundry portal or additional API calls
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   ```
   Error: Failed to get Azure access token
   Solution: Run 'az login' and ensure you have proper permissions
   ```

2. **Agent Not Found**
   ```
   Error: Agent 'my-agent' not found in source environment
   Solution: Verify agent name is exact match (case sensitive)
   ```

3. **Endpoint Access Issues**
   ```
   Error: Cannot access source account
   Solution: Verify account names and resource groups in agent_migration.json
   ```

4. **Model Compatibility**
   ```
   Error: Model deployment not found in target environment
   Solution: Ensure target environment has same model deployments as source
   ```

### Debug Steps

1. **Verify Configuration**
   ```powershell
   # Test configuration loading
   $config = Get-Content "releases/agent_migration.json" | ConvertFrom-Json
   $config.environments.dev
   ```

2. **Test Azure Access**
   ```powershell
   # Verify Azure CLI authentication
   az account show
   az cognitiveservices account list
   ```

3. **Check Agent Service Endpoints**
   ```powershell
   # Test API endpoint accessibility
   $token = az account get-access-token --resource 'https://ai.azure.com' --query accessToken -o tsv
   # Use token to test API calls manually
   ```

## Advanced Usage

### Custom Configuration Templates

Create environment-specific configurations:

```json
{
  "environments": {
    "dev-eastus": {
      "account_name": "myapp-dev-eastus",
      "endpoint": "https://myapp-dev-eastus.services.ai.azure.com/api/projects/dev"
    },
    "prod-westus": {
      "account_name": "myapp-prod-westus", 
      "endpoint": "https://myapp-prod-westus.services.ai.azure.com/api/projects/prod"
    }
  }
}
```

### Integration with Release Pipelines

```powershell
# Use in automated release pipeline
$result = .\scripts\migrate-agent.ps1 -SourceEnvironment test -TargetEnvironment prod -AgentName $env:AGENT_NAME

# Extract agent ID for downstream processes
$newAgentId = ($result | Where-Object { $_ -match "MIGRATED_AGENT_ID=" }) -replace "MIGRATED_AGENT_ID=", ""
Write-Host "##vso[task.setvariable variable=AgentId]$newAgentId"
```

### Selective Migration

Migrate only specific agent properties:

```powershell
# Future enhancement - selective property migration
# This would require modifying the script to support partial updates
```

## Best Practices

1. **Version Control**: Always use version control for agent configurations
2. **Testing**: Thoroughly test agents in lower environments before production
3. **Documentation**: Document agent purposes and deployment procedures  
4. **Monitoring**: Set up monitoring for agent performance across environments
5. **Backup**: Export agent configurations before making changes
6. **Rollback Plan**: Have a rollback strategy for production deployments

## Security Considerations

1. **Token Management**: Never log or store Azure access tokens
2. **Configuration Security**: Keep sensitive endpoint information in secure configuration
3. **RBAC**: Use principle of least privilege for agent service accounts
4. **Audit Trail**: Maintain logs of all migration activities
5. **Network Security**: Use private endpoints where available

## Migration Checklist

### Pre-Migration
- [ ] Verify source agent exists and is functional
- [ ] Confirm target environment readiness
- [ ] Update configuration file with correct endpoints
- [ ] Test authentication and permissions
- [ ] Review agent dependencies and tools

### During Migration  
- [ ] Run migration script with appropriate parameters
- [ ] Monitor output for any errors or warnings
- [ ] Verify successful agent creation in target environment
- [ ] Execute validation tests

### Post-Migration
- [ ] Test migrated agent functionality
- [ ] Update application references to new agent ID
- [ ] Document migration results
- [ ] Archive migration artifacts
- [ ] Update monitoring and alerting

## Support and Troubleshooting

For issues with agent migration:

1. Check the generated migration report for details
2. Review the exported agent configuration files
3. Verify Azure permissions and network connectivity
4. Consult the Azure AI Foundry documentation
5. Contact your Azure support team for platform issues

The migration tools provide comprehensive logging and error reporting to help diagnose and resolve issues quickly.