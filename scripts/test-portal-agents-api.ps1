#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script to discover AI Foundry portal agent APIs
.DESCRIPTION
    This script tests various API patterns discovered from browser dev tools
    to find the correct endpoints for portal-created agents
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "00000000-0000-0000-0000-000000000000",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupDev = "rg-YOUR-DEV-RESOURCE",
    
    [Parameter(Mandatory = $false)]
    [string]$WorkspaceNameDev = "YOUR-DEV-RESOURCE",
    
    [Parameter(Mandatory = $false)]
    [string]$PortalAgentId = "asst_EXAMPLE_AGENT_ID_001"
)

Write-Host "🔍 AI Foundry Portal Agent API Discovery" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow

# Function to test API endpoint with different auth methods
function Test-ApiEndpoint {
    param(
        [string]$Url,
        [hashtable]$Headers,
        [string]$Method = "GET",
        [string]$Description
    )
    
    Write-Host "`n🧪 Testing: $Description" -ForegroundColor Cyan
    Write-Host "   URL: $Url" -ForegroundColor Gray
    
    try {
        $response = Invoke-RestMethod -Uri $Url -Headers $Headers -Method $Method -ErrorAction Stop
        Write-Host "   ✅ SUCCESS!" -ForegroundColor Green
        return $response
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $message = $_.Exception.Message
        Write-Host "   ❌ Failed: HTTP $statusCode - $message" -ForegroundColor Red
        return $null
    }
}

# Get authentication tokens
Write-Host "`n🔐 Getting authentication tokens..." -ForegroundColor Yellow
$cognitiveServicesKey = az cognitiveservices account keys list --name $WorkspaceNameDev --resource-group $ResourceGroupDev --query key1 -o tsv
$accessToken = az account get-access-token --query accessToken -o tsv

# Prepare different auth headers
$apiKeyHeaders = @{
    'api-key' = $cognitiveServicesKey
    'Content-Type' = 'application/json'
}

$bearerHeaders = @{
    'Authorization' = "Bearer $accessToken"
    'Content-Type' = 'application/json'
}

# Test different API patterns that might be used by the portal
Write-Host "`n🌐 Testing API Patterns Found in Browser Dev Tools" -ForegroundColor Yellow
Write-Host "=================================================" -ForegroundColor Yellow

# Pattern 1: Standard OpenAI API (we know this works for programmatic agents)
$openaiUrl = "https://$WorkspaceNameDev.openai.azure.com/openai/assistants/$PortalAgentId?api-version=2024-05-01-preview"
Test-ApiEndpoint -Url $openaiUrl -Headers $apiKeyHeaders -Description "OpenAI API with API Key"

# Pattern 2: AI Foundry Portal API (discovered from browser dev tools!)
$portalApiBase = "https://$WorkspaceNameDev.services.ai.azure.com/api/projects/agent-dev-project"
$portalPatterns = @(
    "$portalApiBase/assistants?api-version=2025-05-15-preview&limit=100&after=",
    "$portalApiBase/assistants/$PortalAgentId?api-version=2025-05-15-preview"
)

# Pattern 3: Other AI Foundry patterns (based on the Microsoft Learn docs you found)
$aiFoundryPatterns = @(
    "https://$WorkspaceNameDev.openai.azure.com/aiagents/$PortalAgentId?api-version=2024-05-01-preview",
    "https://$WorkspaceNameDev.api.azureml.ms/aiagents/v1.0/agents/$PortalAgentId",
    "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupDev/providers/Microsoft.MachineLearningServices/workspaces/$WorkspaceNameDev/aiagents/$PortalAgentId?api-version=2024-05-01-preview"
)

# Test the discovered portal API patterns
foreach ($url in $portalPatterns) {
    Test-ApiEndpoint -Url $url -Headers $bearerHeaders -Description "Portal API with Bearer Token"
    Test-ApiEndpoint -Url $url -Headers $apiKeyHeaders -Description "Portal API with API Key"
}

foreach ($url in $aiFoundryPatterns) {
    Test-ApiEndpoint -Url $url -Headers $bearerHeaders -Description "AI Foundry Pattern with Bearer Token"
    Test-ApiEndpoint -Url $url -Headers $apiKeyHeaders -Description "AI Foundry Pattern with API Key"
}

# Pattern 3: List all agents to see what IDs are returned
Write-Host "`n📋 Comparing Agent Lists from Different APIs" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow

$openaiListUrl = "https://$WorkspaceNameDev.openai.azure.com/openai/assistants?api-version=2024-05-01-preview"
$openaiAgents = Test-ApiEndpoint -Url $openaiListUrl -Headers $apiKeyHeaders -Description "OpenAI Assistants List"

if ($openaiAgents) {
    Write-Host "`n🤖 OpenAI Assistants Found:" -ForegroundColor Green
    $openaiAgents.data | ForEach-Object {
        Write-Host "   • Name: '$($_.name)' | ID: '$($_.id)' | Model: '$($_.model)'" -ForegroundColor Cyan
    }
}

Write-Host "`n📝 INSTRUCTIONS FOR BROWSER DEV TOOLS:" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Yellow
Write-Host "1. Open https://ai.azure.com in Chrome/Edge" -ForegroundColor White
Write-Host "2. Press F12 → Network tab → Check 'Preserve log'" -ForegroundColor White  
Write-Host "3. Navigate to your agents section" -ForegroundColor White
Write-Host "4. Look for API calls containing:" -ForegroundColor White
Write-Host "   - /agents/, /assistants/, /aiagents/" -ForegroundColor Cyan
Write-Host "   - Your agent ID: $PortalAgentId" -ForegroundColor Cyan
Write-Host "5. Check Request Headers for auth method" -ForegroundColor White
Write-Host "6. Copy the exact URL pattern and test it here" -ForegroundColor White

Write-Host "`n🎯 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Run this script after inspecting browser dev tools" -ForegroundColor White
Write-Host "2. Update this script with discovered API patterns" -ForegroundColor White
Write-Host "3. Integrate working patterns into migrate-agent.ps1" -ForegroundColor White

Write-Host "`n✨ Discovery complete!" -ForegroundColor Green