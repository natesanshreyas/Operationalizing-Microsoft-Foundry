# Azure OIDC Configuration

## Federated Identity Credentials Configured

The following federated identity credentials have been configured for the Azure App Registration "GH-AI-Foundry-CICD" (Client ID: 00000000-0000-0000-0000-000000000002):

1. **Main Branch**: `repo:YOUR-GITHUB-USERNAME/ai-foundry-cicd-lab:ref:refs/heads/main`
2. **Pull Requests**: `repo:YOUR-GITHUB-USERNAME/ai-foundry-cicd-lab:pull_request`
3. **Test Environment**: `repo:YOUR-GITHUB-USERNAME/ai-foundry-cicd-lab:environment:test`
4. **Any Environment**: `repo:YOUR-GITHUB-USERNAME/ai-foundry-cicd-lab:environment:*`

## Required GitHub Secrets

- AZURE_CLIENT_ID: `00000000-0000-0000-0000-000000000002`
- AZURE_TENANT_ID: `00000000-0000-0000-0000-000000000001`
- AZURE_SUBSCRIPTION_ID: `00000000-0000-0000-0000-000000000000`

## Azure CLI Commands Used

```bash
# Create federated credentials
az ad app federated-credential create --id 00000000-0000-0000-0000-000000000002 --parameters @federated-credential.json
```