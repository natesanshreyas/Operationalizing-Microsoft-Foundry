# Checkpoint Copy Troubleshooting Guide

## Issue: "Copy checkpoint not found" Error

### Command That Failed:
```bash
curl -X GET https://ai-foundry-demo-eastus2-003652292098918.openai.azure.com/openai/v1/fine_tuning/jobs/ftjob-c71fd2e0fbb74d6bb39f886867df1b16/checkpoints/ftchkpt-254eb8f8f7dc456bae3f7dcca291c96a`
```

### Root Cause Analysis:

1. **API Endpoint Confusion**: 
   - `/checkpoints/{id}` endpoint is for copy operations, not retrieval
   - Individual checkpoint details are not available via separate API

2. **Original Command Issues**:
   - Typo: "fgpt" instead of "gpt" 
   - Wrong identifier format
   - Used model name instead of checkpoint ID

### Correct Approaches:

#### ✅ List All Checkpoints (Working):
```bash
curl -X GET https://ai-foundry-demo-eastus2-003652292098918.openai.azure.com/openai/v1/fine_tuning/jobs/ftjob-c71fd2e0fbb74d6bb39f886867df1b16/checkpoints \
  -H "api-key: <YOUR_API_KEY>"
```

#### ✅ Copy Checkpoint (Correct Format):
```bash
# PowerShell version
$headers = @{ 
  'Content-Type' = 'application/json'
  'api-key' = '<YOUR_API_KEY>'
  'aoai-copy-ft-checkpoints' = 'preview' 
}

$body = @{ 
  destinationResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-YOUR-DEMO-RG-2/providers/Microsoft.CognitiveServices/accounts/ai-foundry-project-west-resource'
  region = 'westus' 
} | ConvertTo-Json

Invoke-RestMethod -Uri 'https://ai-foundry-demo-eastus2-003652292098918.openai.azure.com/openai/v1/fine_tuning/jobs/ftjob-c71fd2e0fbb74d6bb39f886867df1b16/checkpoints/ftchkpt-254eb8f8f7dc456bae3f7dcca291c96a/copy' -Method Post -Headers $headers -Body $body
```

### Possible Reasons for "Copy checkpoint not found":

1. **Feature Not Available**: Copy functionality may not be enabled for:
   - Multi-service AI accounts (vs dedicated OpenAI accounts)
   - This specific region combination
   - This account type/subscription

2. **Checkpoint Requirements**: 
   - Only certain checkpoints may be copyable
   - Latest checkpoint might be required
   - Checkpoint must be in specific state

3. **Preview Limitations**:
   - Feature is in preview with restrictions
   - May require special enrollment or configuration

### Recommended Next Steps:

1. **Try Latest Checkpoint**: Use `ftchkpt-73146949c5174c30a3b100a5aa165e4e` (step 1347)
2. **Check Account Type**: Verify if dedicated OpenAI accounts are required
3. **Contact Support**: If copy is critical, check with Azure support about feature availability

### Available Checkpoints for Reference:
- `ftchkpt-73146949c5174c30a3b100a5aa165e4e` (Step 1347, Latest, 97.46% accuracy)
- `ftchkpt-254eb8f8f7dc456bae3f7dcca291c96a` (Step 898, 86.11% accuracy)  
- `ftchkpt-4651d3b66185463ab806d1bc218076dc` (Step 449, 86.25% accuracy)