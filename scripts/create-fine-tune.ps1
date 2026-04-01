# Azure OpenAI Fine-tuning Script
# Based on https://learn.microsoft.com/en-us/azure/ai-foundry/openai/tutorials/fine-tune

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceName = "YOUR-DEV-RESOURCE",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-YOUR-DEV-RESOURCE",
    
    [Parameter(Mandatory=$false)]
    [string]$BaseModel = "gpt-4o",
    
    [Parameter(Mandatory=$false)]
    [string]$JobSuffix = "azure-qa-demo"
)

$ErrorActionPreference = "Stop"

Write-Host "🧠 Azure OpenAI Fine-tuning Script" -ForegroundColor Cyan
Write-Host "Resource: $ResourceName" -ForegroundColor Gray
Write-Host "Base Model: $BaseModel" -ForegroundColor Gray
Write-Host ""

# Get access token
Write-Host "🔑 Getting access token..." -ForegroundColor Yellow
$token = az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv
if ([string]::IsNullOrEmpty($token)) {
    Write-Error "Failed to get access token"
}
Write-Host "✅ Access token obtained" -ForegroundColor Green

$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type' = 'application/json'
}

$endpoint = "https://$ResourceName.openai.azure.com/openai"

# Function to upload file
function Upload-TrainingFile {
    param([string]$FilePath, [string]$Purpose = "fine-tune")
    
    Write-Host "📤 Uploading file: $FilePath" -ForegroundColor Yellow
    
    # Read file content
    $fileContent = Get-Content $FilePath -Raw
    $fileName = Split-Path $FilePath -Leaf
    
    # Create multipart form data manually
    $boundary = [System.Guid]::NewGuid().ToString()
    $bodyLines = @(
        "--$boundary",
        "Content-Disposition: form-data; name=`"purpose`"",
        "",
        $Purpose,
        "--$boundary",
        "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
        "Content-Type: application/json",
        "",
        $fileContent,
        "--$boundary--"
    )
    $body = $bodyLines -join "`r`n"
    
    $uploadHeaders = @{
        'Authorization' = "Bearer $token"
        'Content-Type' = "multipart/form-data; boundary=$boundary"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$endpoint/files?api-version=2024-08-01-preview" -Method POST -Headers $uploadHeaders -Body $body
        Write-Host "✅ File uploaded successfully: $($response.id)" -ForegroundColor Green
        return $response.id
    }
    catch {
        Write-Host "❌ Failed to upload file: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Upload training and validation files
$trainingFileId = Upload-TrainingFile -FilePath "data/training_data.jsonl"
$validationFileId = Upload-TrainingFile -FilePath "data/validation_data.jsonl"

# Wait for files to be processed
Write-Host "⏳ Waiting for files to be processed..." -ForegroundColor Yellow
do {
    Start-Sleep -Seconds 10
    $trainingStatus = Invoke-RestMethod -Uri "$endpoint/files/$trainingFileId?api-version=2024-08-01-preview" -Headers $headers
    $validationStatus = Invoke-RestMethod -Uri "$endpoint/files/$validationFileId?api-version=2024-08-01-preview" -Headers $headers
    Write-Host "Training file: $($trainingStatus.status) | Validation file: $($validationStatus.status)" -ForegroundColor Gray
} while ($trainingStatus.status -ne "processed" -or $validationStatus.status -ne "processed")

Write-Host "✅ Files processed successfully" -ForegroundColor Green

# Create fine-tuning job
Write-Host "🚀 Creating fine-tuning job..." -ForegroundColor Yellow

$finetuneRequest = @{
    model = $BaseModel
    training_file = $trainingFileId
    validation_file = $validationFileId
    suffix = $JobSuffix
    hyperparameters = @{
        n_epochs = 3
        learning_rate_multiplier = 0.1
        batch_size = 1
    }
} | ConvertTo-Json -Depth 3

try {
    $jobResponse = Invoke-RestMethod -Uri "$endpoint/fine_tuning/jobs?api-version=2024-08-01-preview" -Method POST -Headers $headers -Body $finetuneRequest
    Write-Host "✅ Fine-tuning job created successfully!" -ForegroundColor Green
    Write-Host "Job ID: $($jobResponse.id)" -ForegroundColor Cyan
    Write-Host "Status: $($jobResponse.status)" -ForegroundColor Cyan
    
    # Save job details for migration script
    $jobInfo = @{
        job_id = $jobResponse.id
        model = $jobResponse.model
        training_file = $jobResponse.training_file
        validation_file = $jobResponse.validation_file
        status = $jobResponse.status
        created_at = $jobResponse.created_at
        hyperparameters = $jobResponse.hyperparameters
        resource_name = $ResourceName
        resource_group = $ResourceGroup
        endpoint = $endpoint
    }
    
    $jobInfo | ConvertTo-Json -Depth 3 | Set-Content "fine_tune_job_info.json"
    Write-Host "📄 Job info saved to: fine_tune_job_info.json" -ForegroundColor Gray
    
    # Monitor job progress
    Write-Host ""
    Write-Host "📊 Monitoring job progress (this may take several minutes)..." -ForegroundColor Yellow
    
    do {
        Start-Sleep -Seconds 30
        $statusResponse = Invoke-RestMethod -Uri "$endpoint/fine_tuning/jobs/$($jobResponse.id)?api-version=2024-08-01-preview" -Headers $headers
        Write-Host "Status: $($statusResponse.status) | $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
        
        if ($statusResponse.status -eq "failed") {
            Write-Host "❌ Fine-tuning job failed!" -ForegroundColor Red
            Write-Host "Error: $($statusResponse.error)" -ForegroundColor Red
            exit 1
        }
    } while ($statusResponse.status -in @("validating_files", "queued", "running"))
    
    if ($statusResponse.status -eq "succeeded") {
        Write-Host "🎉 Fine-tuning completed successfully!" -ForegroundColor Green
        Write-Host "Fine-tuned model: $($statusResponse.fine_tuned_model)" -ForegroundColor Cyan
        
        # Update ft_release.json with the new job details
        if (Test-Path "releases/ft_release.json") {
            $releaseConfig = Get-Content "releases/ft_release.json" | ConvertFrom-Json
            $releaseConfig.source.fine_tune_job_id = $statusResponse.id
            $releaseConfig.source.account_name = $ResourceName
            $releaseConfig.source.resource_group = $ResourceGroup
            $releaseConfig | ConvertTo-Json -Depth 3 | Set-Content "releases/ft_release.json"
            Write-Host "✅ Updated releases/ft_release.json with job details" -ForegroundColor Green
        }
    }
    
}
catch {
    Write-Host "❌ Failed to create fine-tuning job: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Fine-tuning job is in progress" -ForegroundColor White
Write-Host "2. When completed, use the GitHub workflow to migrate to test environment" -ForegroundColor White
Write-Host "3. Update releases/ft_release.json if needed" -ForegroundColor White