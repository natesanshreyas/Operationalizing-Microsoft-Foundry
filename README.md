

# Azure AI Foundry CI/CD Lab

This repository demonstrates enterprise-grade CI/CD patterns for Azure AI services, featuring:

- **Fine-tuned model promotion** using Azure OpenAI checkpoint copy APIs
- **AI Agent migration** between Azure AI Foundry environments  
- **GitHub Actions workflows** with Azure OIDC authentication
- **GitOps deployment patterns** with environment-specific configurations
- **Comprehensive API documentation** and troubleshooting guides

## Quick Start

1. **Configure Azure Authentication**: Set up federated identity credentials using `AZURE_OIDC_SETUP.md`
2. **Update Configurations**: 
   - Modify `releases/ft_release.json` with your Azure OpenAI account details
   - Update `releases/agent_migration.json` with your Azure AI Foundry project endpoints
3. **Deploy Workflows**: 
   - Use `.github/workflows/promote-ft.yml` to promote fine-tuned models
   - Use `.github/workflows/promote-agent.yml` to migrate AI agents
   - Or run PowerShell scripts directly: `scripts/migrate-agent.ps1`

## Repository Structure

```
├── .github/workflows/
│   ├── promote-ft.yml              # Fine-tuned model promotion workflow
│   └── promote-agent.yml           # AI agent migration workflow
├── docs/
│   ├── azure-openai-finetuning-api-reference.md    # Complete API documentation
│   ├── checkpoint-copy-troubleshooting.md          # Troubleshooting guide
│   ├── agent-migration-strategy.md                 # Agent migration strategy
│   └── agent-migration-usage-guide.md              # Agent migration usage guide
├── releases/
│   ├── ft_release.json             # Fine-tuning environment configuration
│   └── agent_migration.json        # Agent migration configuration
└── scripts/
    ├── azure-openai-finetuning-commands.sh         # Quick reference commands
    ├── copy_ft_checkpoint.py       # Python checkpoint copy utility
    └── migrate-agent.ps1            # PowerShell agent migration script
```

## Fine-Tuned Model Promotion Flow

**Git single source of truth**: Update `releases/ft_release.json` in a PR.  
On merge to `main`, the **promote-ft** workflow:
1) Requires **Test** environment approval (configure required reviewers in GitHub Environments)  
2) Logs into Azure via **OIDC** (no long-lived secrets)  
3) Calls **checkpoint copy (preview)** from Dev AOAI → Test AOAI  
4) Polls status, then **deploys** in Test  
5) Publishes a promotion artifact

## AI Agent Migration Flow

**Multiple deployment methods**: Use GitHub Actions workflow or PowerShell script.  
The **promote-agent** workflow and `migrate-agent.ps1` script:
1) Export agent configuration from source Azure AI Foundry environment
2) Validate target environment accessibility and model compatibility
3) Create or update agent in target environment with proper naming
4) Execute validation tests to ensure agent functionality  
5) Generate migration report and artifacts

### Agent Migration Examples

```powershell
# Migrate agent from dev to test
.\scripts\migrate-agent.ps1 -SourceEnvironment dev -TargetEnvironment test -AgentName "customer-service-agent"

# Create new version in production  
.\scripts\migrate-agent.ps1 -SourceEnvironment test -TargetEnvironment prod -AgentName "sales-assistant" -CreateNewVersion $true
```

> For fine-tuning: Replace placeholder API URLs/headers in `scripts/copy_ft_checkpoint.py` with those valid for your tenant/region; swap for official CLI/SDK when available.

**RBAC & network** (one-time):
- **Fine-tuning**: SPN needs Reader on **source** AOAI; **Cognitive Services OpenAI Contributor** on **destination** AOAI
- **Agent migration**: Azure AI User role at the project scope for both source and target environments
- Allow PNA on destination if required during copy (then restore)

## Documentation

### Fine-Tuning Resources
- **API Reference**: `docs/azure-openai-finetuning-api-reference.md` - Complete REST API documentation
- **Troubleshooting**: `docs/checkpoint-copy-troubleshooting.md` - Common issues and solutions
- **Quick Commands**: `scripts/azure-openai-finetuning-commands.sh` - CLI reference

### Agent Migration Resources  
- **Migration Strategy**: `docs/agent-migration-strategy.md` - Technical architecture and approaches
- **Usage Guide**: `docs/agent-migration-usage-guide.md` - Step-by-step examples and best practices
- **Cross-Resource Guide**: `docs/cross-resource-migration.md` - Enterprise scenarios with separate AI Foundry resources
- **PowerShell Script**: `scripts/migrate-agent.ps1` - Direct command-line migration tool

## Configuration Files

### `releases/ft_release.json`
Environment configuration for fine-tuned model promotion:
```json
{
  "source_account": "tmnas-aoai-eastus2",
  "target_account": "tmnas-aoai-eastus", 
  "checkpoint_id": "ftchkpt-abc123",
  "model_name": "gpt-35-turbo-fine-tuned"
}
```

### `releases/agent_migration.json`  
Environment configuration for AI agent migration:
```json
{
  "environments": {
    "dev": {
      "account_name": "tmnas-aoai-eastus2",
      "endpoint": "https://YOUR-DEV-RESOURCE.services.ai.azure.com/api/projects/agent-dev-project"
    },
    "test": {
      "account_name": "tmnas-aoai-eastus", 
      "endpoint": "https://YOUR-TEST-RESOURCE.services.ai.azure.com/api/projects/agent-test-project"
    }
  }
}
```

## Security Features

- **Azure OIDC Authentication**: No long-lived secrets in GitHub
- **Federated Identity Credentials**: Secure cross-environment access
- **RBAC Integration**: Proper role-based access control
- **Audit Trail**: Comprehensive logging and reporting
- **Secret Management**: Secure handling of tokens and credentials

## Enterprise Features

- **GitOps Workflows**: Infrastructure and configuration as code
- **Environment Promotion**: Structured dev → test → prod pipelines  
- **Validation Testing**: Automated functionality verification
- **Artifact Management**: Versioned exports and migration reports
- **Error Handling**: Comprehensive error reporting and recovery
- **Monitoring Integration**: Detailed logging for operational monitoring

