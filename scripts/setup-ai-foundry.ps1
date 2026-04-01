# Azure AI Foundry Setup Script
# This script creates the AI Foundry workspaces needed for agent migration

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "00000000-0000-0000-0000-000000000000",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2"
)

Write-Host "🚀 Azure AI Foundry Setup Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription context
Write-Host "🔍 Setting subscription context..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId

# Verify subscription
$subscription = az account show --query name -o tsv
Write-Host "✅ Using subscription: $subscription" -ForegroundColor Green
Write-Host ""

# Define environments
$environments = @(
    @{
        Name = "dev"
        WorkspaceName = "YOUR-DEV-RESOURCE"
        ResourceGroup = "rg-YOUR-DEV-RESOURCE"
        ProjectName = "agent-dev-project"
    },
    @{
        Name = "test" 
        WorkspaceName = "YOUR-TEST-RESOURCE"
        ResourceGroup = "rg-YOUR-TEST-RESOURCE"
        ProjectName = "agent-test-project"
    },
    @{
        Name = "prod"
        WorkspaceName = "YOUR-PROD-RESOURCE"
        ResourceGroup = "rg-YOUR-PROD-RESOURCE"
        ProjectName = "agent-prod-project"
    }
)

foreach ($env in $environments) {
    Write-Host "🔨 Setting up $($env.Name) environment..." -ForegroundColor Yellow
    
    # Check if resource group exists
    $rgExists = az group exists --name $env.ResourceGroup
    if ($rgExists -eq "false") {
        Write-Host "❌ Resource group $($env.ResourceGroup) does not exist" -ForegroundColor Red
        Write-Host "   Please create it first: az group create --name $($env.ResourceGroup) --location $Location" -ForegroundColor Red
        continue
    }
    
    Write-Host "✅ Resource group exists: $($env.ResourceGroup)" -ForegroundColor Green
    
    # Check if workspace already exists
    $workspaceExists = az ml workspace show --name $env.WorkspaceName --resource-group $env.ResourceGroup 2>$null
    if ($workspaceExists) {
        Write-Host "✅ AI Foundry workspace already exists: $($env.WorkspaceName)" -ForegroundColor Green
    } else {
        Write-Host "🔨 Creating AI Foundry workspace: $($env.WorkspaceName)" -ForegroundColor Yellow
        try {
            az ml workspace create --name $env.WorkspaceName --resource-group $env.ResourceGroup --location $Location
            Write-Host "✅ AI Foundry workspace created: $($env.WorkspaceName)" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to create workspace: $($_.Exception.Message)" -ForegroundColor Red
            continue
        }
    }
    
    Write-Host ""
}

Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Set up federated identity credentials for GitHub Actions" -ForegroundColor White
Write-Host "2. Assign Azure AI User roles to your GitHub service principal" -ForegroundColor White
Write-Host "3. Create AI Foundry projects within the workspaces" -ForegroundColor White
Write-Host "4. Update agent_migration.json with correct project endpoints" -ForegroundColor White
Write-Host ""

Write-Host "📋 Required RBAC Commands:" -ForegroundColor Cyan
Write-Host "# Replace <SERVICE_PRINCIPAL_ID> with your GitHub Actions service principal ID" -ForegroundColor Gray
foreach ($env in $environments) {
    Write-Host "az role assignment create --assignee <SERVICE_PRINCIPAL_ID> --role 'Azure AI Developer' --scope '/subscriptions/$SubscriptionId/resourceGroups/$($env.ResourceGroup)/providers/Microsoft.MachineLearningServices/workspaces/$($env.WorkspaceName)'" -ForegroundColor Gray
}