# Azure AI Foundry Project Setup Script
# Creates AI Foundry projects within Azure ML workspaces

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId = "00000000-0000-0000-0000-000000000000",
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName = "default",
    
    [Parameter(Mandatory=$false)]
    [string[]]$ProjectNames = @("agent-dev-project", "agent-test-project", "agent-prod-project"),
    
    [Parameter(Mandatory=$false)]
    [string[]]$WorkspaceNames = @("YOUR-DEV-RESOURCE", "YOUR-TEST-RESOURCE", "YOUR-PROD-RESOURCE"),
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2"
)

Write-Host "🚀 Setting up AI Foundry projects..." -ForegroundColor Cyan
Write-Host "Subscription: $SubscriptionId" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host ""

# Set subscription context
Write-Host "🔧 Setting Azure subscription context..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set subscription context"
    exit 1
}

Write-Host "✅ Subscription context set" -ForegroundColor Green
Write-Host ""

# Loop through workspaces and create projects
for ($i = 0; $i -lt $WorkspaceNames.Length; $i++) {
    $workspaceName = $WorkspaceNames[$i]
    $projectName = $ProjectNames[$i]
    
    Write-Host "📋 Creating AI Foundry project '$projectName' in workspace '$workspaceName'..." -ForegroundColor Yellow
    
    # Check if workspace exists
    $workspace = az ml workspace show --name $workspaceName --resource-group $ResourceGroupName --query "name" -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Workspace '$workspaceName' not found. Skipping project creation." -ForegroundColor Red
        continue
    }
    
    # Try to create the project using Azure CLI extension
    Write-Host "  Creating project using Azure AI CLI..." -ForegroundColor Gray
    
    # Create project configuration
    $projectConfig = @{
        name = $projectName
        description = "AI Agent project for $($workspaceName.Replace('YOUR-RESOURCE-PREFIX-', '')) environment"
        workspace = $workspaceName
        location = $Location
    } | ConvertTo-Json
    
    $configFile = "project-$projectName.json"
    $projectConfig | Out-File -FilePath $configFile -Encoding UTF8
    
    # Try creating with az ai project create (if available)
    try {
        az ai project create --file $configFile --resource-group $ResourceGroupName --workspace-name $workspaceName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Project '$projectName' created successfully" -ForegroundColor Green
        } else {
            # Alternative approach: use REST API
            Write-Host "  📡 Trying REST API approach..." -ForegroundColor Gray
            
            $token = az account get-access-token --resource 'https://management.azure.com' --query accessToken -o tsv
            $headers = @{
                'Authorization' = "Bearer $token"
                'Content-Type' = 'application/json'
            }
            
            $projectData = @{
                properties = @{
                    description = "AI Agent project for $($workspaceName.Replace('YOUR-RESOURCE-PREFIX-', '')) environment"
                    workspace = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.MachineLearningServices/workspaces/$workspaceName"
                }
                location = $Location
            } | ConvertTo-Json -Depth 3
            
            $projectUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.MachineLearningServices/workspaces/$workspaceName/projects/$projectName" + "?api-version=2024-04-01-preview"
            
            try {
                $response = Invoke-RestMethod -Uri $projectUrl -Method PUT -Headers $headers -Body $projectData
                Write-Host "  ✅ Project '$projectName' created via REST API" -ForegroundColor Green
            }
            catch {
                Write-Host "  ⚠️  Could not create project via REST API: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "  📝 Manual creation may be required in AI Foundry portal" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "  ⚠️  Could not create project: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Clean up temp file
    if (Test-Path $configFile) {
        Remove-Item $configFile -Force
    }
    
    Write-Host ""
}

Write-Host "🎯 AI Foundry project setup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Verify projects in AI Foundry portal (https://ai.azure.com)" -ForegroundColor Gray  
Write-Host "2. Configure model deployments for each project" -ForegroundColor Gray
Write-Host "3. Update agent_migration_updated.json with correct project endpoints" -ForegroundColor Gray
Write-Host "4. Test agent migration with updated configuration" -ForegroundColor Gray