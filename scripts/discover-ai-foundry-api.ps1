# AI Foundry API Discovery Script
# This script systematically tests different API endpoints to find where agents are stored

param(
    [Parameter(Mandatory=$false)]
    [string]$CognitiveServiceName = "YOUR-DEV-RESOURCE",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-YOUR-DEV-RESOURCE",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "agent-dev-project",
    
    [Parameter(Mandatory=$false)]
    [string]$AgentId = "asst_EXAMPLE_AGENT_ID_001"
)

Write-Host "🔍 AI Foundry API Discovery Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Get API key
Write-Host "🔑 Getting Cognitive Services API key..." -ForegroundColor Yellow
try {
    $apiKey = az cognitiveservices account keys list --name $CognitiveServiceName --resource-group $ResourceGroup --query key1 -o tsv
    Write-Host "✅ API key obtained" -ForegroundColor Green
} catch {
    Write-Error "Failed to get API key: $($_.Exception.Message)"
}

# Get access token as alternative
Write-Host "🔐 Getting Azure access tokens..." -ForegroundColor Yellow
$aiToken = az account get-access-token --resource 'https://ai.azure.com' --query accessToken -o tsv
$cogToken = az account get-access-token --resource 'https://cognitiveservices.azure.com' --query accessToken -o tsv

Write-Host "✅ Access tokens obtained" -ForegroundColor Green
Write-Host ""

# Base URLs to test
$baseUrls = @(
    "https://$CognitiveServiceName.cognitiveservices.azure.com",
    "https://$CognitiveServiceName.openai.azure.com",
    "https://$CognitiveServiceName.api.cognitive.microsoft.com",
    "https://$CognitiveServiceName.aiservices.azure.com"
)

# API paths to test
$apiPaths = @(
    "/openai/assistants",
    "/openai/deployments/assistants",
    "/openai/deployments/$ProjectName/assistants",
    "/openai/projects/$ProjectName/assistants",
    "/v1/assistants",
    "/agents",
    "/v1/agents",
    "/openai/agents",
    "/projects/$ProjectName/agents",
    "/deployments/$ProjectName/assistants",
    "/raisvc/v1/assistants",
    "/api/v1/assistants",
    "/cognitive/assistants",
    "/aiservices/assistants"
)

# API versions to test
$apiVersions = @(
    "2024-02-15-preview",
    "2024-05-01-preview", 
    "2023-12-01-preview",
    "2024-02-01",
    "2023-10-01-preview"
)

# Authentication methods
$authMethods = @(
    @{ Name = "API Key"; Headers = @{ 'api-key' = $apiKey; 'Content-Type' = 'application/json' } },
    @{ Name = "Bearer AI Token"; Headers = @{ 'Authorization' = "Bearer $aiToken"; 'Content-Type' = 'application/json' } },
    @{ Name = "Bearer Cog Token"; Headers = @{ 'Authorization' = "Bearer $cogToken"; 'Content-Type' = 'application/json' } }
)

Write-Host "🔍 Testing combinations of:" -ForegroundColor Yellow
Write-Host "  - Base URLs: $($baseUrls.Count)" -ForegroundColor Gray
Write-Host "  - API Paths: $($apiPaths.Count)" -ForegroundColor Gray
Write-Host "  - API Versions: $($apiVersions.Count)" -ForegroundColor Gray
Write-Host "  - Auth Methods: $($authMethods.Count)" -ForegroundColor Gray
Write-Host "  Total combinations: $($baseUrls.Count * $apiPaths.Count * $apiVersions.Count * $authMethods.Count)" -ForegroundColor Gray
Write-Host ""

$successfulEndpoints = @()
$testCount = 0

foreach ($baseUrl in $baseUrls) {
    foreach ($apiPath in $apiPaths) {
        foreach ($apiVersion in $apiVersions) {
            foreach ($authMethod in $authMethods) {
                $testCount++
                $url = "$baseUrl$apiPath" + "?api-version=$apiVersion&limit=1"
                
                Write-Progress -Activity "Testing API endpoints" -Status "Testing $testCount" -PercentComplete (($testCount / ($baseUrls.Count * $apiPaths.Count * $apiVersions.Count * $authMethods.Count)) * 100)
                
                try {
                    $response = Invoke-RestMethod -Uri $url -Headers $authMethod.Headers -Method GET -TimeoutSec 5
                    
                    $result = @{
                        Url = $url
                        BaseUrl = $baseUrl
                        ApiPath = $apiPath
                        ApiVersion = $apiVersion
                        AuthMethod = $authMethod.Name
                        Status = "Success"
                        ItemCount = if ($response.data) { $response.data.Count } elseif ($response) { $response.Count } else { 0 }
                        Response = $response
                    }
                    
                    $successfulEndpoints += $result
                    Write-Host "✅ SUCCESS: $($authMethod.Name) - $baseUrl$apiPath - Found $($result.ItemCount) items" -ForegroundColor Green
                    
                    # If we found items, show details
                    if ($result.ItemCount -gt 0) {
                        Write-Host "🎯 FOUND AGENTS! Details:" -ForegroundColor Cyan
                        if ($response.data) {
                            $response.data | Select-Object -First 3 | ForEach-Object {
                                Write-Host "  - Name: $($_.name) | ID: $($_.id)" -ForegroundColor White
                            }
                        } else {
                            $response | Select-Object -First 3 | ForEach-Object {
                                Write-Host "  - Name: $($_.name) | ID: $($_.id)" -ForegroundColor White
                            }
                        }
                        Write-Host ""
                    }
                    
                } catch {
                    # Only log non-404 errors to reduce noise
                    if ($_.Exception.Response.StatusCode -ne 'NotFound') {
                        Write-Host "⚠️  $($authMethod.Name) - $baseUrl$apiPath - $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
                    }
                }
                
                # Add small delay to avoid rate limiting
                Start-Sleep -Milliseconds 100
            }
        }
    }
}

Write-Progress -Activity "Testing API endpoints" -Completed

Write-Host ""
Write-Host "🎯 DISCOVERY RESULTS" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

if ($successfulEndpoints.Count -eq 0) {
    Write-Host "❌ No working endpoints found with standard API patterns" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "1. Check browser network traffic in AI Foundry portal" -ForegroundColor Gray
    Write-Host "2. Look for non-standard API endpoints or headers" -ForegroundColor Gray
    Write-Host "3. Try direct agent ID access" -ForegroundColor Gray
    
    # Try direct agent access if ID provided
    if ($AgentId) {
        Write-Host ""
        Write-Host "🔍 Testing direct agent access..." -ForegroundColor Yellow
        
        foreach ($baseUrl in $baseUrls) {
            foreach ($authMethod in $authMethods) {
                try {
                    $directUrl = "$baseUrl/openai/assistants/$AgentId?api-version=2024-02-15-preview"
                    $response = Invoke-RestMethod -Uri $directUrl -Headers $authMethod.Headers -Method GET -TimeoutSec 5
                    Write-Host "✅ DIRECT ACCESS SUCCESS: $($authMethod.Name) - $baseUrl" -ForegroundColor Green
                    Write-Host "Agent: $($response.name) | ID: $($response.id)" -ForegroundColor White
                } catch {
                    if ($_.Exception.Response.StatusCode -ne 'NotFound') {
                        Write-Host "⚠️  Direct access failed: $($authMethod.Name) - $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
    
} else {
    Write-Host "✅ Found $($successfulEndpoints.Count) working endpoint(s)!" -ForegroundColor Green
    Write-Host ""
    
    foreach ($endpoint in $successfulEndpoints) {
        Write-Host "🎯 Working Endpoint:" -ForegroundColor Cyan
        Write-Host "  URL: $($endpoint.Url)" -ForegroundColor White
        Write-Host "  Auth: $($endpoint.AuthMethod)" -ForegroundColor Gray
        Write-Host "  Items Found: $($endpoint.ItemCount)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Generate updated configuration
    $workingEndpoint = $successfulEndpoints[0]
    $newEndpoint = "$($workingEndpoint.BaseUrl)$($workingEndpoint.ApiPath)"
    
    Write-Host "🔧 RECOMMENDED CONFIGURATION UPDATE:" -ForegroundColor Yellow
    Write-Host "Update your agent_migration.json with:" -ForegroundColor Gray
    Write-Host "  endpoint: `"$newEndpoint`"" -ForegroundColor White
    Write-Host "  api_version: `"$($workingEndpoint.ApiVersion)`"" -ForegroundColor White
    Write-Host "  auth_method: `"$($workingEndpoint.AuthMethod)`"" -ForegroundColor White
}

Write-Host ""
Write-Host "📊 Test Summary:" -ForegroundColor Cyan
Write-Host "  Total tests: $testCount" -ForegroundColor Gray
Write-Host "  Successful: $($successfulEndpoints.Count)" -ForegroundColor Gray
Write-Host "  Success rate: $([math]::Round(($successfulEndpoints.Count / $testCount) * 100, 2))%" -ForegroundColor Gray