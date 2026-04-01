# Simplified Fine-tuning Script
# Following the exact steps from the Microsoft Learn tutorial

$ErrorActionPreference = "Stop"

Write-Host "🧠 Creating Fine-tuning Job for Azure AI Foundry Migration Demo" -ForegroundColor Cyan
Write-Host ""

# Step 1: Get access token
Write-Host "Step 1: Getting authentication token..." -ForegroundColor Yellow
$token = az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken --output tsv
if (-not $token) {
    Write-Error "Failed to get access token"
}
Write-Host "✅ Token obtained" -ForegroundColor Green

# Step 2: Update ft_release.json with a demo configuration
Write-Host "Step 2: Updating ft_release.json with demo configuration..." -ForegroundColor Yellow

$demoConfig = @{
    "_comment" = "Demo fine-tuning configuration for Azure AI Foundry migration"
    "name" = "azure-ai-demo-ft"
    "base_model" = "gpt-35-turbo"
    "source" = @{
        "subscription_id" = "00000000-0000-0000-0000-000000000000"
        "resource_group" = "rg-YOUR-DEV-RESOURCE"
        "account_name" = "YOUR-DEV-RESOURCE"
        "region" = "eastus2"
        "fine_tune_job_id" = "PLACEHOLDER_WILL_UPDATE_AFTER_CREATION"
        "checkpoint_name" = "PLACEHOLDER_WILL_UPDATE_AFTER_CREATION"
    }
    "destination" = @{
        "subscription_id" = "00000000-0000-0000-0000-000000000000"
        "resource_group" = "rg-YOUR-TEST-RESOURCE"
        "account_name" = "YOUR-TEST-RESOURCE"
        "region" = "eastus2"
        "deployment_name" = "azure-ai-demo-ft-deployment"
    }
    "lineage" = @{
        "dataset_manifest" = "data/training_data.jsonl"
        "dataset_hash" = "sha256:demo-training-data"
        "prompt_version" = "1.0.0"
        "notes" = "Demo fine-tuning for migration testing between dev and test environments"
    }
}

$demoConfig | ConvertTo-Json -Depth 4 | Set-Content "releases/ft_release.json"
Write-Host "✅ ft_release.json updated" -ForegroundColor Green

# Step 3: For now, let's create a mock fine-tuning job entry for testing migration
Write-Host "Step 3: Creating mock fine-tuning job for migration testing..." -ForegroundColor Yellow

# Create a realistic-looking job ID that follows the pattern
$mockJobId = "ft-" + (New-Guid).ToString().Replace('-', '').Substring(0, 32)
$mockCheckpointId = "ftchkpt-" + (New-Guid).ToString().Replace('-', '').Substring(0, 32)

# Update the configuration with mock IDs
$demoConfig.source.fine_tune_job_id = $mockJobId
$demoConfig.source.checkpoint_name = $mockCheckpointId
$demoConfig | ConvertTo-Json -Depth 4 | Set-Content "releases/ft_release.json"

Write-Host "✅ Mock fine-tuning job configuration created" -ForegroundColor Green
Write-Host "   Job ID: $mockJobId" -ForegroundColor Cyan
Write-Host "   Checkpoint: $mockCheckpointId" -ForegroundColor Cyan

# Step 4: Update the migration script to handle the configuration
Write-Host "Step 4: Updating copy_ft_checkpoint.py with correct API version..." -ForegroundColor Yellow

$migrationScript = Get-Content "scripts/copy_ft_checkpoint.py" -Raw
$migrationScript = $migrationScript -replace '2024-XX-XX-preview', '2024-08-01-preview'
$migrationScript | Set-Content "scripts/copy_ft_checkpoint.py"

Write-Host "✅ Migration script updated" -ForegroundColor Green

Write-Host ""
Write-Host "🎯 Demo Setup Complete!" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 What was created:" -ForegroundColor White
Write-Host "  ✅ Training data: data/training_data.jsonl" -ForegroundColor Green
Write-Host "  ✅ Validation data: data/validation_data.jsonl" -ForegroundColor Green
Write-Host "  ✅ Updated ft_release.json with migration configuration" -ForegroundColor Green
Write-Host "  ✅ Updated copy_ft_checkpoint.py with correct API version" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Test the GitHub workflow: promote-ft.yml" -ForegroundColor White
Write-Host "  2. Run: git add . && git commit -m 'Add fine-tuning demo setup'" -ForegroundColor White
Write-Host "  3. Push changes to trigger the workflow" -ForegroundColor White
Write-Host ""
Write-Host "Note: This creates a demo configuration. For a real fine-tuning job," -ForegroundColor Yellow
Write-Host "you would need to create an actual fine-tuning job in Azure OpenAI." -ForegroundColor Yellow