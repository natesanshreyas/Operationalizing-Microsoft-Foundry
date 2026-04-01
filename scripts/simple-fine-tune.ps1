# Simplified Azure OpenAI Fine-tuning Script
# Creates a fine-tuning job without complex file status checking

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceName = "YOUR-DEV-RESOURCE",
    
    [Parameter(Mandatory=$false)]
    [string]$BaseModel = "gpt-35-turbo",
    
    [Parameter(Mandatory=$false)]
    [string]$JobSuffix = "azure-demo"
)

$ErrorActionPreference = "Stop"

Write-Host "🧠 Azure OpenAI Simple Fine-tuning Script" -ForegroundColor Cyan
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

# Upload files using curl (more reliable for file uploads)
Write-Host "📤 Uploading training data..." -ForegroundColor Yellow
$trainingUpload = curl -s -X POST "$endpoint/files?api-version=2024-08-01-preview" `
    -H "Authorization: Bearer $token" `
    -F "purpose=fine-tune" `
    -F "file=@data/training_data.jsonl" | ConvertFrom-Json

if ($trainingUpload.id) {
    Write-Host "✅ Training file uploaded: $($trainingUpload.id)" -ForegroundColor Green
} else {
    Write-Error "Failed to upload training file: $trainingUpload"
}

Write-Host "📤 Uploading validation data..." -ForegroundColor Yellow
$validationUpload = curl -s -X POST "$endpoint/files?api-version=2024-08-01-preview" `
    -H "Authorization: Bearer $token" `
    -F "purpose=fine-tune" `
    -F "file=@data/validation_data.jsonl" | ConvertFrom-Json

if ($validationUpload.id) {
    Write-Host "✅ Validation file uploaded: $($validationUpload.id)" -ForegroundColor Green
} else {
    Write-Error "Failed to upload validation file: $validationUpload"
}

# Wait a moment for file processing
Write-Host "⏳ Waiting 30 seconds for file processing..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Create fine-tuning job with minimal parameters
Write-Host "🚀 Creating fine-tuning job..." -ForegroundColor Yellow

$finetuneRequest = @{
    model = $BaseModel
    training_file = $trainingUpload.id
    validation_file = $validationUpload.id
    suffix = $JobSuffix
} | ConvertTo-Json -Depth 3

try {
    $jobResponse = Invoke-RestMethod -Uri "$endpoint/fine_tuning/jobs?api-version=2024-08-01-preview" -Method POST -Headers $headers -Body $finetuneRequest
    Write-Host "✅ Fine-tuning job created successfully!" -ForegroundColor Green
    Write-Host "Job ID: $($jobResponse.id)" -ForegroundColor Cyan
    Write-Host "Status: $($jobResponse.status)" -ForegroundColor Cyan
    Write-Host "Model: $($jobResponse.model)" -ForegroundColor Cyan
    
    # Update ft_release.json with real job details
    Write-Host "📝 Updating ft_release.json..." -ForegroundColor Yellow
    if (Test-Path "releases/ft_release.json") {
        $releaseConfig = Get-Content "releases/ft_release.json" | ConvertFrom-Json
        $releaseConfig.source.fine_tune_job_id = $jobResponse.id
        $releaseConfig.source.account_name = $ResourceName
        $releaseConfig.base_model = $BaseModel
        $releaseConfig.name = $jobResponse.model -replace ':', '-'
        
        $releaseConfig | ConvertTo-Json -Depth 4 | Set-Content "releases/ft_release.json"
        Write-Host "✅ ft_release.json updated with real job details" -ForegroundColor Green
    }
    
    # Save job info for reference
    $jobInfo = @{
        job_id = $jobResponse.id
        model = $jobResponse.model
        base_model = $BaseModel
        status = $jobResponse.status
        created_at = $jobResponse.created_at
        resource_name = $ResourceName
        endpoint = $endpoint
        suffix = $JobSuffix
    }
    
    $jobInfo | ConvertTo-Json -Depth 3 | Set-Content "fine_tune_job_$($jobResponse.id).json"
    Write-Host "📄 Job details saved to: fine_tune_job_$($jobResponse.id).json" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "🎉 Fine-tuning job created successfully!" -ForegroundColor Green
    Write-Host "📊 Job will continue running in the background" -ForegroundColor Yellow
    Write-Host "🔄 You can now test the migration workflow with this job ID" -ForegroundColor Cyan
    
}
catch {
    Write-Host "❌ Failed to create fine-tuning job: $($_.Exception.Message)" -ForegroundColor Red
    
    # Show the detailed error
    if ($_.Exception.Response) {
        $errorStream = $_.Exception.Response.GetResponseStream()
        $reader = [System.IO.StreamReader]::new($errorStream)
        $errorBody = $reader.ReadToEnd()
        Write-Host "Error details: $errorBody" -ForegroundColor Red
    }
    throw
}

Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Monitor the fine-tuning job progress (it may take 10-30 minutes)" -ForegroundColor White
Write-Host "2. When ready, test the migration workflow: promote-ft.yml" -ForegroundColor White
Write-Host "3. The job will be migrated from dev to test environment" -ForegroundColor White