# Azure OpenAI Fine-Tuning REST API Command Reference

> **Source**: [Microsoft Learn - Customize a model with fine-tuning](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/fine-tuning?tabs=azure-openai&pivots=rest-api)
> 
> **Created**: October 8, 2025
> 
> **Purpose**: Complete reference of all REST API commands for Azure OpenAI fine-tuning operations

## Table of Contents

1. [Environment Variables](#environment-variables)
2. [File Upload Commands](#file-upload-commands)
3. [Fine-Tuning Job Management](#fine-tuning-job-management)
4. [Model Status and Monitoring](#model-status-and-monitoring)
5. [Checkpoint Operations](#checkpoint-operations)
6. [Model Copy Operations (Preview)](#model-copy-operations-preview)
7. [Model Deployment](#model-deployment)
8. [Analysis and Results](#analysis-and-results)
9. [Continuous Fine-Tuning](#continuous-fine-tuning)
10. [Data Format Examples](#data-format-examples)

---

## Environment Variables

Set these environment variables before running the commands:

```bash
# Required environment variables
export AZURE_OPENAI_ENDPOINT="https://<your-resource-name>.openai.azure.com"
export AZURE_OPENAI_API_KEY="<your-api-key>"

# For deployment operations
export SUBSCRIPTION="<your-subscription-id>"
export RESOURCE_GROUP="<your-resource-group-name>"
export RESOURCE_NAME="<your-azure-openai-resource-name>"
export TOKEN="<azure-bearer-token>"  # Get via: az account get-access-token
```

---

## File Upload Commands

### Upload Training Data

**Purpose**: Upload training dataset in JSONL format for fine-tuning

```bash
curl -X POST $AZURE_OPENAI_ENDPOINT/openai/v1/files \
  -H "Content-Type: multipart/form-data" \
  -H "api-key: $AZURE_OPENAI_API_KEY" \
  -F "purpose=fine-tune" \
  -F "file=@C:\\fine-tuning\\training_set.jsonl;type=application/json"
```

**Key Points**:
- File must be in JSONL format with UTF-8 encoding and BOM
- Maximum file size: 512 MB
- Purpose must be set to "fine-tune"
- Returns a file ID for use in training jobs

### Upload Validation Data

**Purpose**: Upload validation dataset to monitor training performance

```bash
curl -X POST $AZURE_OPENAI_ENDPOINT/openai/v1/files \
  -H "Content-Type: multipart/form-data" \
  -H "api-key: $AZURE_OPENAI_API_KEY" \
  -F "purpose=fine-tune" \
  -F "file=@C:\\fine-tuning\\validation_set.jsonl;type=application/json"
```

**Key Points**:
- Optional but recommended for monitoring overfitting
- Same format requirements as training data
- Returns a file ID for use in training jobs

---

## Fine-Tuning Job Management

### Create Fine-Tuning Job (Standard)

**Purpose**: Start a new fine-tuning job with standard regional training

```bash
curl -X POST $AZURE_OPENAI_ENDPOINT/openai/v1/fine_tuning/jobs \
  -H "Content-Type: application/json" \
  -H "api-key: $AZURE_OPENAI_API_KEY" \
  -d '{
    "model": "gpt-4.1-2025-04-14",
    "training_file": "<TRAINING_FILE_ID>",
    "validation_file": "<VALIDATION_FILE_ID>",
    "seed": 105
}'
```

**Parameters**:
- `model`: Base model to fine-tune (e.g., gpt-4.1-2025-04-14, gpt-4o-mini-2024-07-18)
- `training_file`: File ID from upload training data step
- `validation_file`: File ID from upload validation data step (optional)
- `seed`: For reproducible results (optional)

### Create Fine-Tuning Job (Global Training)

**Purpose**: Start a fine-tuning job with global standard training (preview feature)

```bash
curl -X POST $AZURE_OPENAI_ENDPOINT/openai/fine_tuning/jobs?api-version=2025-04-01-preview \
  -H "Content-Type: application/json" \
  -H "api-key: $AZURE_OPENAI_API_KEY" \
  -d '{
    "model": "gpt-4.1-2025-04-14",
    "training_file": "<TRAINING_FILE_ID>",
    "validation_file": "<VALIDATION_FILE_ID>",
    "seed": 105,
    "trainingType": "globalstandard"
}'
```

**Key Points**:
- Requires API version 2025-04-01-preview
- `trainingType` set to "globalstandard" for global training
- Only available for supported models and regions

### Pause Fine-Tuning Job

**Purpose**: Pause a running fine-tuning job to create a deployable checkpoint

```bash
curl -X POST $AZURE_OPENAI_ENDPOINT/openai/v1/fine_tuning/jobs/{fine_tuning_job_id}/pause \
  -H "Content-Type: application/json" \
  -H "api-key: $AZURE_OPENAI_API_KEY"
```

**Key Points**:
- Job must be in "Running" state and trained for at least one step
- Creates a deployable checkpoint after safety evaluations
- Useful when metrics aren't converging properly

### Resume Fine-Tuning Job

**Purpose**: Resume a paused fine-tuning job to continue training

```bash
curl -X POST $AZURE_OPENAI_ENDPOINT/openai/v1/fine_tuning/jobs/{fine_tuning_job_id}/resume \
  -H "Content-Type: application/json" \
  -H "api-key: $AZURE_OPENAI_API_KEY"
```

**Key Points**:
- Can only resume jobs that were previously paused
- Training continues from the paused checkpoint

---

## Model Status and Monitoring

### Check Fine-Tuning Job Status

**Purpose**: Monitor the progress and status of a fine-tuning job

```bash
curl -X GET $AZURE_OPENAI_ENDPOINT/openai/v1/fine_tuning/jobs/<YOUR-JOB-ID> \
  -H "api-key: $AZURE_OPENAI_API_KEY"
```

**Response Information**:
- Job status (queued, running, succeeded, failed, etc.)
- Training progress and metrics
- Error messages if job failed
- Fine-tuned model ID when completed

### List Fine-Tuning Events

**Purpose**: Get detailed training events and logs for troubleshooting

```bash
curl -X POST $AZURE_OPENAI_ENDPOINT/openai/v1/fine_tuning/jobs/{fine_tuning_job_id}/events \
  -H "Content-Type: application/json" \
  -H "api-key: $AZURE_OPENAI_API_KEY"
```

**Key Points**:
- Provides step-by-step training progress
- Includes loss metrics and token accuracy
- Useful for debugging training issues

---

## Checkpoint Operations

### List Checkpoints

**Purpose**: Retrieve all checkpoints created during fine-tuning (one per epoch)

```bash
curl -X GET $AZURE_OPENAI_ENDPOINT/openai/v1/fine_tuning/jobs/{fine_tuning_job_id}/checkpoints \
  -H "api-key: $AZURE_OPENAI_API_KEY"
```

**Key Points**:
- Checkpoints are created after each training epoch
- Each checkpoint is a fully functional deployable model
- Useful for finding models before overfitting occurs
- Up to 3 most recent checkpoints are kept

---

## Model Copy Operations (Preview)

### Copy Fine-Tuned Model Checkpoint

**Purpose**: Copy a fine-tuned checkpoint from one region/subscription to another

```bash
curl --request POST \
  --url 'https://<aoai-resource>.openai.azure.com/openai/v1/fine_tuning/jobs/<ftjob>/checkpoints/<checkpoint-name>/copy' \
  --header 'Content-Type: application/json' \
  --header 'api-key: <api-key>' \
  --header 'aoai-copy-ft-checkpoints: preview' \
  --data '{
  "destinationResourceId": "<resourceId>",
  "region": "<region>"
}'
```

**Parameters**:
- `destinationResourceId`: Full Azure resource ID of destination OpenAI account
- `region`: Target region for the copied model
- Requires preview header: `aoai-copy-ft-checkpoints: preview`

**Prerequisites**:
- Destination account must have at least one fine-tuning job
- Destination account must not disable public network access
- Proper permissions configured with managed identity

### Check Copy Status

**Purpose**: Monitor the progress of a model copy operation

```bash
curl --request GET \
  --url 'https://<aoai-resource>.openai.azure.com//openai/v1/fine_tuning/jobs/<ftjob>/checkpoints/<checkpoint-name>/copy' \
  --header 'Content-Type: application/json' \
  --header 'api-key: <api-key>' \
  --header 'aoai-copy-ft-checkpoints: preview'
```

**Key Points**:
- Long-running operation that requires status polling
- Use checkpoint ID from the original POST request
- Returns copy operation status and completion details

---

## Model Deployment

### Deploy Fine-Tuned Model

**Purpose**: Create a deployment for inference using the fine-tuned model

```bash
curl -X POST "https://management.azure.com/subscriptions/<SUBSCRIPTION>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.CognitiveServices/accounts/<RESOURCE_NAME>/deployments/<MODEL_DEPLOYMENT_NAME>?api-version=2024-10-21" \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "sku": {"name": "standard", "capacity": 1},
    "properties": {
        "model": {
            "format": "OpenAI",
            "name": "<FINE_TUNED_MODEL>",
            "version": "1"
        }
    }
}'
```

**Parameters**:
- `FINE_TUNED_MODEL`: Model ID from completed fine-tuning job (e.g., gpt-4.1-2025-04-14.ft-b044a9d3cf9c4228b5d393567f693b83)
- `MODEL_DEPLOYMENT_NAME`: Custom name for your deployment
- `capacity`: Number of deployment units (starts with 1)

**Key Points**:
- Uses Azure Management API, not OpenAI API
- Requires Azure Bearer token (get via `az account get-access-token`)
- Can also deploy checkpoints using checkpoint ID

---

## Analysis and Results

### Download Training Results

**Purpose**: Get the job details to find the results file ID

```bash
curl -X GET "$AZURE_OPENAI_ENDPOINT/openai/v1/fine_tuning/jobs/<JOB_ID>" \
  -H "api-key: $AZURE_OPENAI_API_KEY"
```

### Download Results CSV File

**Purpose**: Download the detailed training metrics CSV file for analysis

```bash
curl -X GET "$AZURE_OPENAI_ENDPOINT/openai/v1/files/<RESULT_FILE_ID>/content" \
    -H "api-key: $AZURE_OPENAI_API_KEY" > <RESULT_FILENAME>
```

**CSV Columns**:
- `step`: Training step number
- `train_loss`: Loss for training batch
- `train_mean_token_accuracy`: Token prediction accuracy on training data
- `valid_loss`: Loss for validation batch  
- `validation_mean_token_accuracy`: Token prediction accuracy on validation data
- `full_valid_loss`: Validation loss at end of epoch
- `full_valid_mean_token_accuracy`: Validation token accuracy at end of epoch

---

## Continuous Fine-Tuning

### Fine-Tune an Already Fine-Tuned Model

**Purpose**: Perform iterative fine-tuning on a previously fine-tuned model

```bash
curl -X POST $AZURE_OPENAI_ENDPOINT/openai/v1/fine_tuning/jobs \
  -H "Content-Type: application/json" \
  -H "api-key: $AZURE_OPENAI_API_KEY" \
  -d '{
    "model": "gpt-4.1-2025-04-14.ft-5fd1918ee65d4cd38a5dcf6835066ed7",
    "training_file": "<TRAINING_FILE_ID>",
    "validation_file": "<VALIDATION_FILE_ID>",
    "suffix": "<additional text used to help identify fine-tuned models>"
}'
```

**Key Points**:
- Use the fine-tuned model ID as the base model
- `suffix` parameter helps identify different iterations (up to 40 characters)
- Same process as initial fine-tuning but with fine-tuned model as base

---

## Data Format Examples

### Single-Turn Chat Format

```jsonl
{"messages": [{"role": "system", "content": "Clippy is a factual chatbot that is also sarcastic."}, {"role": "user", "content": "Who discovered Antarctica?"}, {"role": "assistant", "content": "Some chaps named Fabian Gottlieb von Bellingshausen and Mikhail Lazarev, as if they don't teach that in every school!"}]}
{"messages": [{"role": "system", "content": "Clippy is a factual chatbot that is also sarcastic."}, {"role": "user", "content": "What is the biggest ocean?"}, {"role": "assistant", "content": "The Pacific Ocean. It's not like it's a small pond or anything."}]}
```

### Multi-Turn Chat Format with Weights

```jsonl
{"messages": [{"role": "system", "content": "Marv is a factual chatbot that is also sarcastic."}, {"role": "user", "content": "What's the capital of France?"}, {"role": "assistant", "content": "Paris", "weight": 0}, {"role": "user", "content": "Can you be more sarcastic?"}, {"role": "assistant", "content": "Paris, as if everyone doesn't know that already.", "weight": 1}]}
```

### Chat Completions with Vision

```jsonl
{"messages": [{"role": "user", "content": [{"type": "text", "text": "What's in this image?"}, {"type": "image_url", "image_url": {"url": "https://raw.githubusercontent.com/MicrosoftDocs/azure-ai-docs/main/articles/ai-services/openai/media/how-to/generated-seattle.png"}}]}, {"role": "assistant", "content": "The image appears to be a watercolor painting of a city skyline, featuring tall buildings and a recognizable structure often associated with Seattle, like the Space Needle. The artwork uses soft colors and brushstrokes to create a somewhat abstract and artistic representation of the cityscape."}]}
```

---

## Hyperparameters (Optional)

When creating fine-tuning jobs, you can specify these optional hyperparameters:

- `batch_size` (integer): Number of training examples per batch
- `learning_rate_multiplier` (number): Multiplier for the learning rate (0.02 to 0.2 recommended)
- `n_epochs` (integer): Number of training epochs
- `seed` (integer): For reproducible results

---

## Best Practices

1. **Data Quality**: Use hundreds to thousands of high-quality examples
2. **Validation Data**: Always include validation data to monitor overfitting
3. **Monitoring**: Check training metrics regularly via events API
4. **Checkpoints**: Consider deploying checkpoints if final model shows overfitting
5. **Iteration**: Use continuous fine-tuning to refine models incrementally
6. **Testing**: Deploy to developer deployment first for validation

---

## Common Error Scenarios

1. **File Upload Errors**: Check file format (JSONL), encoding (UTF-8 with BOM), size (<512MB)
2. **Job Creation Errors**: Verify file IDs and model names
3. **Permission Errors**: Ensure proper RBAC roles (Cognitive Services OpenAI Contributor)
4. **Copy Operation Errors**: Check managed identity configuration and network access

---

*This reference was compiled from the official Microsoft Learn documentation and contains all REST API commands for Azure OpenAI fine-tuning operations as of October 2025.*