# Azure OpenAI Account Configuration

## Recent Updates - October 9, 2025

### RBAC Role Assignments for GitHub Service Principal
Updated GitHub service principal permissions to support AI agent migration workflows:

**Service Principal**: `GH-AI-Foundry-CICD` (00000000-0000-0000-0000-000000000003)

**Roles Applied**:
- ✅ **AI Foundry Agent Manager** (Custom Role) - All environments
- ✅ **Azure AI Developer** (Built-in Role) - Dev and Test environments  
- ✅ **Cognitive Services Contributor** (Built-in Role) - Dev and Test environments

For detailed role assignment information, see: `RBAC_DOCUMENTATION.md`

## Current Account Status

### Available Azure AI Services Accounts

Based on the Azure CLI discovery, here are the actual accounts available:

#### East US 2 (Source - rg-YOUR-DEMO-RG-1)
- `ai-foundry-demo-eastus2-003652292098918` ✅ (AIServices)
- `ai-foundry-resource-eastus2-002` (AIServices)
- `ai-svc-stewart-title-eastus2-001` (AIServices)

#### West US (Destination - rg-YOUR-DEMO-RG-2)  
- `ai-foundry-project-west-resource` ✅ (AIServices)
- `ai-foundry-project-resource-001` (AIServices)

## Issue Resolution

### ❌ Original Problem
The workflow was failing because the configured account `ai-hubproject-demo-eastus2-003` **does not exist**.

Error: `ResourceNotFound - The Resource 'Microsoft.CognitiveServices/accounts/ai-hubproject-demo-eastus2-003' under resource group 'rg-YOUR-DEMO-RG-1' was not found`

### ✅ Solution Applied
Updated `releases/ft_release.json` with actual existing account names:
- **Source**: `ai-foundry-demo-eastus2-003652292098918`
- **Destination**: `ai-foundry-project-west-resource`

## Important Notes

### Account Type Considerations
The available accounts are **Azure AI Services** (multi-service) rather than dedicated **OpenAI** accounts. This means:

1. **Endpoints**: Use `.cognitiveservices.azure.com` instead of `.openai.azure.com`
2. **API Access**: Fine-tuning APIs may not be available on multi-service accounts
3. **Feature Limitations**: Some OpenAI-specific features might be restricted

### Recommendations

1. **Create Dedicated OpenAI Accounts**: For full fine-tuning support, create dedicated OpenAI resources
2. **Verify Fine-tuning Support**: Test if the current AI Services accounts support fine-tuning operations
3. **Update Workflow**: May need to modify the workflow to work with AI Services endpoints instead of OpenAI endpoints

### Next Steps

1. Test the workflow with the corrected account names
2. If fine-tuning is not supported, create dedicated OpenAI accounts
3. Update the workflow endpoints if needed (.cognitiveservices.azure.com vs .openai.azure.com)