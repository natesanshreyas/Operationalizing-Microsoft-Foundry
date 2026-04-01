# Azure Service Principal Permissions Fix

## Problem
The GitHub workflow is failing with a 401 PermissionDenied error:

```
The principal '00000000-0000-0000-0000-000000000003' lacks the required data action 
'Microsoft.CognitiveServices/accounts/AIServices/agents/write' to perform 
'POST /api/projects/{projectName}/assistants' operation.
```

## Root Cause
The Azure service principal used for GitHub OIDC authentication doesn't have the specific AI Foundry permissions needed to create/manage agents through the Portal API.

## Solution: Grant Required Permissions

### Step 1: Identify the Service Principal
The service principal ID from the error: `00000000-0000-0000-0000-000000000003`

### Step 2: Required Permissions
The service principal needs the following data actions:
- `Microsoft.CognitiveServices/accounts/AIServices/agents/write`
- `Microsoft.CognitiveServices/accounts/AIServices/agents/read`
- `Microsoft.CognitiveServices/accounts/AIServices/agents/delete` (optional, for cleanup)

### Step 3: Create Custom Role (Recommended)

```bash
# Create a custom role definition for AI Foundry Agent Management
az role definition create --role-definition '{
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
}'
```

### Step 4: Assign Custom Role to Service Principal

```bash
# Assign to AI Foundry resources in dev environment
az role assignment create \
  --assignee 00000000-0000-0000-0000-000000000003 \
  --role "AI Foundry Agent Manager" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/YOUR-DEV-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-DEV-RESOURCE"

# Assign to AI Foundry resources in test environment  
az role assignment create \
  --assignee 00000000-0000-0000-0000-000000000003 \
  --role "AI Foundry Agent Manager" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/YOUR-TEST-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-TEST-RESOURCE"

# Assign to AI Foundry resources in prod environment (if needed)
az role assignment create \
  --assignee 00000000-0000-0000-0000-000000000003 \
  --role "AI Foundry Agent Manager" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/YOUR-PROD-RESOURCE/providers/Microsoft.MachineLearningServices/workspaces/YOUR-PROD-RESOURCE"
```

### Alternative: Use Built-in Roles (Less Secure)

If you prefer to use built-in roles, you can assign the "Cognitive Services Contributor" role, but this grants broader permissions:

```bash
# Grant Cognitive Services Contributor role (broader permissions)
az role assignment create \
  --assignee 00000000-0000-0000-0000-000000000003 \
  --role "Cognitive Services Contributor" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/YOUR-DEV-RESOURCE"

az role assignment create \
  --assignee 00000000-0000-0000-0000-000000000003 \
  --role "Cognitive Services Contributor" \
  --scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/YOUR-TEST-RESOURCE"
```

## Verification Commands

After applying the permissions, verify they're working:

```bash
# Check role assignments
az role assignment list --assignee 00000000-0000-0000-0000-000000000003 --output table

# Test permissions (run as the service principal)
az rest --method GET \
  --url "https://YOUR-DEV-RESOURCE.services.ai.azure.com/api/projects/agent-dev-project/assistants?api-version=2025-05-15-preview&limit=10" \
  --resource "https://ai.azure.com/"
```

## Security Best Practices

1. **Principle of Least Privilege**: Use the custom role instead of built-in roles when possible
2. **Scope Limitation**: Assign permissions only to the specific AI Foundry resources needed
3. **Regular Auditing**: Periodically review and audit service principal permissions
4. **Environment Isolation**: Consider separate service principals for different environments

## Implementation Steps

✅ **COMPLETED** - All steps have been executed:

1. ✅ **Custom role creation** - AI Foundry Agent Manager role created
2. ✅ **Role assignments** - Assigned to all relevant AI Foundry resources  
3. ✅ **Additional roles** - Applied Azure AI Developer and Cognitive Services Contributor roles
4. ⏳ **RBAC propagation** - Waiting 15-30 minutes for Azure RBAC propagation
5. 🔄 **Testing required** - Re-run the GitHub workflow after propagation
6. 📊 **Validation pending** - Verify successful agent migration

## Current Status - October 9, 2025

### ✅ Roles Successfully Applied:
1. **AI Foundry Agent Manager** (Custom Role) - Applied to dev, test, prod workspaces
2. **Azure AI Developer** (Built-in Role) - Applied to dev, test workspaces  
3. **Cognitive Services Contributor** (Built-in Role) - Applied to dev, test Cognitive Services accounts

### 📋 Assignment IDs for Reference:
- **AI Foundry Agent Manager**:
  - Dev: `00000000-0000-0000-0000-RBAC00000001`
  - Test: `00000000-0000-0000-0000-RBAC00000002`
  - Prod: `00000000-0000-0000-0000-RBAC00000003`
- **Azure AI Developer**:
  - Dev: `00000000-0000-0000-0000-RBAC00000004`
  - Test: `00000000-0000-0000-0000-RBAC00000005`
- **Cognitive Services Contributor**:
  - Dev: `00000000-0000-0000-0000-RBAC00000006`
  - Test: `00000000-0000-0000-0000-RBAC00000007`

## Troubleshooting

✅ **Completed troubleshooting steps:**
1. ✅ Applied multiple role types (custom + built-in)
2. ✅ Applied at different scope levels (workspace + account)
3. ✅ Verified service principal ID matches error message
4. ✅ Confirmed AI Foundry resources exist in correct subscription/resource groups

🔄 **Remaining considerations:**
1. **RBAC propagation delay** - Can take up to 30 minutes
2. **Conditional Access policies** - May be blocking the service principal
3. **Project-level permissions** - May need additional project-specific roles
4. **Token audience verification** - Ensure correct audience in GitHub workflow