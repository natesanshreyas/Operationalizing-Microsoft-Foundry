# Azure RBAC Role Assignment Documentation

## Overview
This document tracks all Azure RBAC role assignments made to the GitHub service principal for AI Foundry agent migration workflows.

## Service Principal Details
- **Display Name**: `GH-AI-Foundry-CICD`
- **Object ID**: `00000000-0000-0000-0000-000000000003`
- **Application ID**: `00000000-0000-0000-0000-000000000002`
- **Purpose**: GitHub Actions OIDC authentication for AI Foundry CI/CD workflows

## Problem Statement
GitHub workflows were failing with 401 PermissionDenied errors when attempting to create AI agents:
```
The principal '00000000-0000-0000-0000-000000000003' lacks the required data action 
'Microsoft.CognitiveServices/accounts/AIServices/agents/write' to perform 
'POST /api/projects/{projectName}/assistants' operation.
```

## Role Assignments Applied

### 1. AI Foundry Agent Manager (Custom Role)
**Created**: October 9, 2025  
**Type**: Custom Role Definition  
**Purpose**: Granular permissions for AI agent management operations

#### Role Definition
```json
{
  "Name": "AI Foundry Agent Manager",
  "Description": "Allows managing AI agents in Azure AI Foundry projects",
  "Actions": [
    "Microsoft.CognitiveServices/accounts/read",
    "Microsoft.MachineLearningServices/workspaces/read"
  ],
  "DataActions": [
    "Microsoft.CognitiveServices/accounts/AIServices/agents/read",
    "Microsoft.CognitiveServices/accounts/AIServices/agents/write",
    "Microsoft.CognitiveServices/accounts/AIServices/agents/delete"
  ],
  "AssignableScopes": [
    "/subscriptions/00000000-0000-0000-0000-000000000000"
  ]
}
```

#### Assignments
| Environment | Scope | Assignment ID | Status |
|-------------|--------|---------------|---------|
| Dev | `/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-DEV-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-DEV-RESOURCE` | `00000000-0000-0000-0000-RBAC00000001` | ✅ Active |
| Test | `/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-TEST-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-TEST-RESOURCE` | `00000000-0000-0000-0000-RBAC00000002` | ✅ Active |
| Prod | `/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-PROD-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-PROD-RESOURCE` | `00000000-0000-0000-0000-RBAC00000003` | ✅ Active |

### 2. Azure AI Developer (Built-in Role)
**Applied**: October 9, 2025  
**Type**: Azure Built-in Role  
**Role Definition ID**: `64702f94-c441-49e6-a78b-ef80e0188fee`  
**Purpose**: Comprehensive AI development permissions

#### Assignments
| Environment | Scope | Assignment ID | Status |
|-------------|--------|---------------|---------|
| Dev | `/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-DEV-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-DEV-RESOURCE` | `00000000-0000-0000-0000-RBAC00000004` | ✅ Active |
| Test | `/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-TEST-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-TEST-RESOURCE` | `00000000-0000-0000-0000-RBAC00000005` | ✅ Active |

### 3. Cognitive Services Contributor (Built-in Role)
**Applied**: October 9, 2025  
**Type**: Azure Built-in Role  
**Role Definition ID**: `25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68`  
**Purpose**: Full management access to Cognitive Services accounts

#### Assignments
| Environment | Scope | Assignment ID | Status |
|-------------|--------|---------------|---------|
| Dev | `/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-DEV-RESOURCE/providers/Microsoft.CognitiveServices/accounts/YOUR-DEV-RESOURCE` | `00000000-0000-0000-0000-RBAC00000006` | ✅ Active |
| Test | `/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-TEST-RESOURCE/providers/Microsoft.CognitiveServices/accounts/YOUR-TEST-RESOURCE` | `00000000-0000-0000-0000-RBAC00000007` | ✅ Active |

## Permission Matrix

| Operation | Custom Role | Azure AI Developer | Cognitive Services Contributor |
|-----------|-------------|-------------------|-------------------------------|
| Read AI Foundry workspace | ✅ | ✅ | ❌ |
| Read Cognitive Services account | ✅ | ✅ | ✅ |
| Read AI agents | ✅ | ✅ | ✅ |
| Create/Update AI agents | ✅ | ✅ | ✅ |
| Delete AI agents | ✅ | ✅ | ✅ |
| Manage Cognitive Services | ❌ | ❌ | ✅ |

## Commands Used

### Custom Role Creation
```bash
# Create custom role definition
az role definition create --role-definition @ai-foundry-agent-manager-role.json
```

### AI Foundry Agent Manager Assignments
```bash
# Dev environment
az role assignment create \
  --assignee "00000000-0000-0000-0000-000000000003" \
  --role "AI Foundry Agent Manager" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-DEV-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-DEV-RESOURCE"

# Test environment  
az role assignment create \
  --assignee "00000000-0000-0000-0000-000000000003" \
  --role "AI Foundry Agent Manager" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-TEST-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-TEST-RESOURCE"

# Prod environment
az role assignment create \
  --assignee "00000000-0000-0000-0000-000000000003" \
  --role "AI Foundry Agent Manager" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-PROD-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-PROD-RESOURCE"
```

### Azure AI Developer Assignments
```bash
# Dev environment
az role assignment create \
  --assignee "00000000-0000-0000-0000-000000000003" \
  --role "Azure AI Developer" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-DEV-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-DEV-RESOURCE"

# Test environment
az role assignment create \
  --assignee "00000000-0000-0000-0000-000000000003" \
  --role "Azure AI Developer" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-TEST-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-TEST-RESOURCE"
```

### Cognitive Services Contributor Assignments
```bash
# Dev environment
az role assignment create \
  --assignee "00000000-0000-0000-0000-000000000003" \
  --role "Cognitive Services Contributor" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-DEV-RESOURCE/providers/Microsoft.CognitiveServices/accounts/YOUR-DEV-RESOURCE"

# Test environment
az role assignment create \
  --assignee "00000000-0000-0000-0000-000000000003" \
  --role "Cognitive Services Contributor" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-TEST-RESOURCE/providers/Microsoft.CognitiveServices/accounts/YOUR-TEST-RESOURCE"
```

## Verification Commands

### List All Role Assignments
```bash
az role assignment list \
  --assignee "00000000-0000-0000-0000-000000000003" \
  --query "[].{Role: roleDefinitionName, Scope: scope}" \
  --output table
```

### Test API Access
```bash
# Test agent listing
az rest \
  --method GET \
  --url "https://YOUR-DEV-RESOURCE.services.ai.azure.com/api/projects/agent-dev-project/assistants?api-version=2025-05-15-preview" \
  --resource "https://ai.azure.com/"
```

## Security Considerations

### Principle of Least Privilege
- **Custom Role**: Most restrictive, only includes required data actions
- **Azure AI Developer**: Broader AI development permissions
- **Cognitive Services Contributor**: Broadest, includes account management

### Recommended Approach
1. **Primary**: Use the custom "AI Foundry Agent Manager" role
2. **Fallback**: Use "Azure AI Developer" for broader compatibility
3. **Last Resort**: Use "Cognitive Services Contributor" for maximum permissions

### Scope Isolation
- **Workspace Level**: Permissions scoped to specific AI Foundry workspaces
- **Account Level**: Permissions scoped to specific Cognitive Services accounts
- **Environment Separation**: Different permissions per environment (dev/test/prod)

## Troubleshooting

### RBAC Propagation
- **Initial Delay**: 5-15 minutes typical
- **Maximum Delay**: Up to 30 minutes
- **Verification**: Use `az role assignment list` to confirm assignments exist

### Common Issues
1. **Token Audience Mismatch**: Ensure using `https://ai.azure.com/` as resource
2. **Project Not Found**: Verify project names in AI Foundry portal
3. **Conditional Access**: Check Azure AD policies blocking service principals

## Audit Trail

| Date | Time (UTC) | Action | Role | Environment | Status |
|------|------------|---------|------|-------------|--------|
| 2025-10-09 | 19:36:02 | Role Assignment Created | AI Foundry Agent Manager | Dev | Success |
| 2025-10-09 | 19:36:32 | Role Assignment Created | AI Foundry Agent Manager | Test | Success |
| 2025-10-09 | 19:59:28 | Role Assignment Created | AI Foundry Agent Manager | Prod | Success |
| 2025-10-09 | 20:12:59 | Role Assignment Created | Azure AI Developer | Dev | Success |
| 2025-10-09 | 20:13:50 | Role Assignment Created | Azure AI Developer | Test | Success |
| 2025-10-09 | 20:14:16 | Role Assignment Created | Cognitive Services Contributor | Dev | Success |
| 2025-10-09 | 20:14:43 | Role Assignment Created | Cognitive Services Contributor | Test | Success |

## Next Steps

1. **Wait for propagation** (15-30 minutes)
2. **Test GitHub workflow**
3. **Validate agent creation**
4. **Monitor for any remaining permission issues**
5. **Document successful resolution**

---
**Document Version**: 1.0  
**Last Updated**: October 9, 2025  
**Author**: GitHub Copilot Assistant  
**Status**: Permissions Applied, Awaiting Propagation