# Cross-AI Foundry Resource Migration Considerations

## Overview

This document addresses the specific considerations when migrating agents between different Azure AI Foundry resources, which is the typical enterprise scenario where environments are in separate resource groups and potentially different subscriptions.

## Architecture Considerations

### AI Foundry Resource Hierarchy
```
Azure Subscription
├── Resource Group (Dev)
│   ├── AI Foundry Resource (Dev)
│   │   └── AI Foundry Project (Dev)
│   │       └── Agents
│   └── Cognitive Services Account (Dev)
└── Resource Group (Test/Prod)
    ├── AI Foundry Resource (Test/Prod)
    │   └── AI Foundry Project (Test/Prod)
    │       └── Agents
    └── Cognitive Services Account (Test/Prod)
```

### Key Differences from Same-Resource Scenarios

1. **Resource Isolation**: Each AI Foundry resource has its own:
   - Identity and access management
   - Storage accounts
   - Cosmos DB instances
   - Search services
   - Network configurations

2. **Cross-Resource Authentication**: Requires proper RBAC setup across multiple resources

3. **Data Sovereignty**: Data doesn't move between resources directly - only configurations

## RBAC Requirements

### Required Roles by Resource

#### Source AI Foundry Resource
- **Azure AI User** (at project scope)
  - Permissions: `agents/*/read`, `agents/*/action`
  - Purpose: Read agent configurations and test functionality

#### Target AI Foundry Resource  
- **Azure AI User** (at project scope)
  - Permissions: `agents/*/read`, `agents/*/write`, `agents/*/action`, `agents/*/delete`
  - Purpose: Create/update agents and validate functionality

#### Service Principal (for CI/CD)
- **Azure AI User** on both source and target AI Foundry projects
- **Reader** on both resource groups (for resource verification)

### RBAC Assignment Examples

```bash
# Assign Azure AI User role to service principal on source project
az role assignment create \
  --assignee $SERVICE_PRINCIPAL_ID \
  --role "Azure AI Developer" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$SOURCE_RG/providers/Microsoft.MachineLearningServices/workspaces/$SOURCE_AI_FOUNDRY/projects/$SOURCE_PROJECT"

# Assign Azure AI User role to service principal on target project  
az role assignment create \
  --assignee $SERVICE_PRINCIPAL_ID \
  --role "Azure AI Developer" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$TARGET_RG/providers/Microsoft.MachineLearningServices/workspaces/$TARGET_AI_FOUNDRY/projects/$TARGET_PROJECT"
```

## Network Considerations

### Private Endpoints
If using private endpoints, ensure:
1. **Source Access**: Migration tool can reach source AI Foundry project endpoint
2. **Target Access**: Migration tool can reach target AI Foundry project endpoint
3. **DNS Resolution**: Proper DNS configuration for private endpoint resolution

### Virtual Network Peering
For VNet-isolated resources:
1. **Cross-VNet Access**: Ensure VNet peering or appropriate routing
2. **NSG Rules**: Network security groups allow HTTPS traffic to AI Foundry endpoints
3. **Service Tags**: Use `AzureMachineLearning` service tag if needed

## Configuration Updates

### Enhanced Configuration Schema

```json
{
  "environments": {
    "dev": {
      "ai_foundry_resource_name": "company-ai-foundry-dev",
      "resource_group": "rg-ai-foundry-dev",
      "subscription_id": "dev-subscription-id",
      "endpoint": "https://company-ai-foundry-dev.services.ai.azure.com/api/projects/dev-project",
      "region": "eastus2",
      "model_deployment": "gpt-4o-mini",
      "cognitive_services_account": "company-openai-dev",
      "cognitive_services_rg": "rg-openai-dev"
    },
    "prod": {
      "ai_foundry_resource_name": "company-ai-foundry-prod", 
      "resource_group": "rg-ai-foundry-prod",
      "subscription_id": "prod-subscription-id",
      "endpoint": "https://company-ai-foundry-prod.services.ai.azure.com/api/projects/prod-project",
      "region": "centralus",
      "model_deployment": "gpt-4o",
      "cognitive_services_account": "company-openai-prod",
      "cognitive_services_rg": "rg-openai-prod"
    }
  }
}
```

### Key Configuration Fields

- **`ai_foundry_resource_name`**: The actual AI Foundry workspace name
- **`resource_group`**: Resource group containing the AI Foundry resource
- **`subscription_id`**: Azure subscription (may differ between environments)
- **`endpoint`**: Full project endpoint URL
- **`cognitive_services_account`**: Associated OpenAI/Cognitive Services account
- **`cognitive_services_rg`**: Resource group for Cognitive Services (may differ)

## Migration Process Enhancements

### 1. Pre-Migration Resource Validation

The updated script now validates:
- AI Foundry resource accessibility
- Associated Cognitive Services account accessibility  
- Cross-resource group permissions
- Project-level API access

### 2. Cross-Subscription Support

```powershell
# Set subscription context for source
az account set --subscription $sourceConfig.subscription_id

# Verify source resource access
az resource show --name $sourceConfig.ai_foundry_resource_name --resource-group $sourceConfig.resource_group

# Set subscription context for target  
az account set --subscription $targetConfig.subscription_id

# Verify target resource access
az resource show --name $targetConfig.ai_foundry_resource_name --resource-group $targetConfig.resource_group
```

### 3. Enhanced Error Handling

The script now provides specific error messages for:
- **403 Forbidden**: Indicates missing Azure AI User role
- **404 Not Found**: Indicates incorrect endpoint or project name
- **Network issues**: DNS resolution or connectivity problems

## Troubleshooting Cross-Resource Issues

### Common Error Scenarios

#### 1. Resource Not Found
```
Error: Cannot access source AI Foundry resource: company-ai-foundry-dev in resource group: rg-ai-foundry-dev
```
**Solutions:**
- Verify AI Foundry resource name is correct
- Ensure resource group name is accurate
- Check subscription context

#### 2. Access Denied (403)
```  
Error: Access denied (403). Verify you have 'Azure AI User' role on the AI Foundry project
```
**Solutions:**
- Verify Azure AI User role assignment at project scope
- Check if using correct service principal
- Validate subscription context

#### 3. Network Connectivity Issues
```
Error: API call failed: Unable to connect to remote server
```
**Solutions:**
- Check private endpoint configuration
- Verify DNS resolution for AI Foundry endpoints
- Validate network security group rules

### Diagnostic Commands

```powershell
# Verify AI Foundry resource exists
az resource show --name "ai-foundry-name" --resource-group "rg-name" --resource-type "Microsoft.MachineLearningServices/workspaces"

# Check role assignments on AI Foundry project
az role assignment list --scope "/subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.MachineLearningServices/workspaces/workspace-name/projects/project-name"

# Test endpoint connectivity
Test-NetConnection -ComputerName "your-ai-foundry.services.ai.azure.com" -Port 443

# Verify DNS resolution  
Resolve-DnsName "your-ai-foundry.services.ai.azure.com"
```

## Security Best Practices

### 1. Principle of Least Privilege
- Grant minimum required permissions on each resource
- Use project-scoped roles instead of resource-scoped when possible
- Regularly audit cross-resource permissions

### 2. Cross-Environment Isolation
- Use separate service principals for different environment tiers
- Implement approval workflows for production migrations
- Maintain audit logs for cross-resource operations

### 3. Network Security
- Use private endpoints for production environments
- Implement network segmentation between environments
- Monitor cross-resource network traffic

## Automation Considerations

### GitHub Actions Updates

The workflow needs updates to handle cross-resource scenarios:

```yaml
- name: Set Source Subscription Context
  run: az account set --subscription ${{ steps.load-config.outputs.source_subscription }}

- name: Verify Source Resource Access
  run: |
    az resource show \
      --name ${{ steps.load-config.outputs.source_ai_foundry }} \
      --resource-group ${{ steps.load-config.outputs.source_rg }} \
      --resource-type "Microsoft.MachineLearningServices/workspaces"

- name: Set Target Subscription Context  
  run: az account set --subscription ${{ steps.load-config.outputs.target_subscription }}

- name: Verify Target Resource Access
  run: |
    az resource show \
      --name ${{ steps.load-config.outputs.target_ai_foundry }} \
      --resource-group ${{ steps.load-config.outputs.target_rg }} \
      --resource-type "Microsoft.MachineLearningServices/workspaces"
```

### Service Principal Configuration

For cross-resource automation, configure federated identity credentials with broader scope:

```json
{
  "name": "github-actions-cross-resource",
  "subject": "repo:company/ai-foundry-cicd:environment:production",
  "issuer": "https://token.actions.githubusercontent.com",
  "audiences": ["api://AzureADTokenExchange"]
}
```

## Monitoring and Alerting

### Key Metrics to Monitor
- Cross-resource migration success/failure rates
- Authentication failures by resource
- Network connectivity issues
- Permission escalation attempts

### Recommended Alerts
- Failed cross-resource migrations
- Unusual cross-subscription activity  
- Network connectivity degradation
- RBAC permission changes

## Compliance Considerations

### Data Residency
- Ensure target environment meets data residency requirements
- Document cross-region data movement for compliance
- Validate encryption in transit and at rest

### Audit Trail
- Log all cross-resource operations
- Maintain migration history and artifacts
- Document approval workflows for production changes

This enhanced approach ensures robust, secure, and compliant agent migrations across different AI Foundry resources while maintaining proper isolation and governance.