# Azure AI Foundry Agent Migration Strategy

## Overview

This document outlines strategies and approaches for migrating AI agents from one Azure AI Foundry instance to another (e.g., from development to test to production environments). Unlike fine-tuned models which have dedicated checkpoint copy APIs, agent migration requires a different approach based on the agent architecture and configuration management.

## Agent Architecture Components

Based on Azure AI Foundry Agent Service documentation, agents consist of:

1. **Agent Definition**
   - Model deployment reference
   - Instructions (system prompt)
   - Tool configurations
   - Metadata (name, description)

2. **Agent State Storage** (varies by setup type)
   - **Basic Setup**: Microsoft-managed storage
   - **Standard Setup**: Customer-managed Azure resources (Cosmos DB, Storage, Search)
   - **BYO VNet Setup**: Customer-managed resources within private network

3. **Associated Resources**
   - Files and documents
   - Vector stores (for search capabilities)
   - Conversation threads (chat history)
   - Custom tools and functions

## Migration Strategies

### Strategy 1: Configuration-Based Recreation (Recommended)

This approach treats agents as infrastructure-as-code, recreating them in target environments using configuration definitions.

**Advantages:**
- Clean separation between environments
- No data carryover concerns
- Fits CI/CD patterns
- Version controlled agent definitions

**Process:**
1. Export agent configuration from source environment
2. Version control the configuration
3. Deploy to target environment using automation
4. Validate functionality

### Strategy 2: API-Based Agent Cloning

Using the Azure AI Foundry Agent Service REST API to read agent configuration and recreate in target environment.

**Key API Operations:**
- `GET /assistants/{agent_id}` - Retrieve agent configuration
- `POST /assistants` - Create new agent
- File and tool management APIs for associated resources

### Strategy 3: Resource-Level Migration (Standard/BYO VNet Only)

For Standard and BYO VNet setups, migrate the underlying Azure resources.

**Applicable Resources:**
- Azure Cosmos DB (conversation threads, agent state)
- Azure Storage (files, documents)
- Azure AI Search (vector stores)

## Implementation Approaches

### Approach 1: GitHub Actions Workflow for Agent Migration

```yaml
name: Agent Migration Pipeline
on:
  workflow_dispatch:
    inputs:
      source_environment:
        description: 'Source environment (dev/test/prod)'
        required: true
        default: 'dev'
      target_environment:
        description: 'Target environment (dev/test/prod)'
        required: true
        default: 'test'
      agent_name:
        description: 'Agent name to migrate'
        required: true

jobs:
  migrate-agent:
    runs-on: ubuntu-latest
    steps:
      # Agent configuration export and deployment steps
```

### Approach 2: PowerShell/Azure CLI Scripts

```powershell
# Export agent configuration
$agentConfig = az rest --method GET --url "$sourceEndpoint/assistants/$agentId" --headers "Authorization=Bearer $token"

# Create agent in target environment
az rest --method POST --url "$targetEndpoint/assistants" --body $agentConfig --headers "Authorization=Bearer $token"
```

### Approach 3: Infrastructure as Code with Bicep/ARM

Define agents as Azure resources and deploy across environments using standard Azure deployment patterns.

## Migration Considerations

### 1. Environment Isolation
- **Projects as Boundaries**: Azure AI Foundry projects provide isolation
- **Cross-Project Access**: Agents in different projects cannot access each other's resources
- **Data Residency**: Consider data location requirements for different environments

### 2. Model Dependencies
- **Model Availability**: Ensure target environment has required model deployments
- **Model Versions**: Verify model version compatibility across environments
- **Quota Management**: Check model quota availability in target regions

### 3. Authentication & Authorization
- **RBAC Roles**: Ensure proper Azure AI User roles in target environments
- **Service Principals**: Use managed identities or service principals for automation
- **Cross-Subscription**: Handle authentication across different Azure subscriptions

### 4. State Management
- **Conversation History**: Decide whether to migrate existing conversations
- **File Assets**: Plan for file and document migration
- **Vector Stores**: Consider search index recreation vs. migration

### 5. Configuration Differences
- **Environment-Specific Settings**: Handle different endpoints, model names, etc.
- **Secrets Management**: Manage API keys and connection strings securely
- **Network Configuration**: Handle VNet and firewall differences

## Agent Configuration Schema

Based on the REST API documentation, agent configurations include:

```json
{
  "instructions": "You are a helpful agent.",
  "name": "my-agent",
  "tools": [{"type": "code_interpreter"}],
  "model": "gpt-4o-mini",
  "description": "Agent description",
  "metadata": {
    "environment": "dev",
    "version": "1.0.0"
  }
}
```

## Migration Workflow Example

### Phase 1: Pre-Migration
1. **Inventory Assessment**
   - List all agents in source environment
   - Document dependencies and configurations
   - Identify shared resources (files, vector stores)

2. **Target Environment Preparation**
   - Verify model deployments
   - Set up required Azure resources
   - Configure RBAC permissions

### Phase 2: Configuration Export
1. **Agent Definition Extraction**
   ```bash
   # Get agent list
   curl -H "Authorization: Bearer $token" \
        "$sourceEndpoint/assistants?api-version=2025-05-01"
   
   # Get specific agent configuration
   curl -H "Authorization: Bearer $token" \
        "$sourceEndpoint/assistants/$agentId?api-version=2025-05-01"
   ```

2. **Resource Cataloging**
   - Document associated files and tools
   - Export vector store configurations
   - Identify custom function definitions

### Phase 3: Target Environment Deployment
1. **Agent Recreation**
   ```bash
   # Create agent in target environment
   curl -X POST -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$agentConfig" \
        "$targetEndpoint/assistants?api-version=2025-05-01"
   ```

2. **Resource Migration**
   - Upload files to target storage
   - Recreate vector stores
   - Deploy custom tools

### Phase 4: Validation
1. **Functional Testing**
   - Run test conversations
   - Verify tool functionality
   - Check file access

2. **Performance Validation**
   - Response time testing
   - Load testing if applicable
   - Resource utilization monitoring

## Automation Scripts

### 1. Agent Export Script
```bash
#!/bin/bash
# export-agent.sh
source_endpoint="$1"
agent_id="$2"
output_file="$3"

# Get access token
token=$(az account get-access-token --resource 'https://ai.azure.com' --query accessToken -o tsv)

# Export agent configuration
curl -H "Authorization: Bearer $token" \
     "$source_endpoint/assistants/$agent_id?api-version=2025-05-01" \
     -o "$output_file"
```

### 2. Agent Import Script
```bash
#!/bin/bash
# import-agent.sh
target_endpoint="$1"
config_file="$2"

# Get access token
token=$(az account get-access-token --resource 'https://ai.azure.com' --query accessToken -o tsv)

# Create agent in target environment
curl -X POST -H "Authorization: Bearer $token" \
     -H "Content-Type: application/json" \
     -d "@$config_file" \
     "$target_endpoint/assistants?api-version=2025-05-01"
```

## Integration with Existing CI/CD

This agent migration strategy complements the existing fine-tuning model promotion workflow by:

1. **Shared Authentication**: Using the same Azure OIDC federated identity credentials
2. **Common Configuration**: Leveraging similar environment configuration patterns
3. **Unified Workflow**: Extending the existing GitHub Actions workflow structure
4. **Consistent Monitoring**: Using similar validation and error handling approaches

## Recommended Next Steps

1. **Create Agent Migration Workflow**: Develop a GitHub Actions workflow similar to `promote-ft.yml`
2. **Develop Configuration Templates**: Create standardized agent configuration templates
3. **Build Migration Tools**: Implement PowerShell/CLI scripts for agent operations
4. **Establish Testing Framework**: Create validation scripts for migrated agents
5. **Document Procedures**: Create operational runbooks for agent lifecycle management

## Security Considerations

- **Token Management**: Secure handling of Azure access tokens
- **Configuration Secrets**: Avoid embedding sensitive data in agent configurations
- **Access Control**: Implement proper RBAC for cross-environment operations
- **Audit Trail**: Log all migration activities for compliance and troubleshooting

## Limitations and Constraints

1. **API Compatibility**: Agent Service follows OpenAI Assistants API but may have Azure-specific extensions
2. **Cross-Region**: Some resources may not support cross-region migration
3. **State Preservation**: Conversation history migration may require separate tooling
4. **Tool Dependencies**: Custom tools may need individual migration strategies
5. **Model Availability**: Target environment must have compatible model deployments

## Conclusion

Agent migration in Azure AI Foundry requires a structured approach focusing on configuration management and resource recreation rather than direct data migration. The recommended strategy treats agents as code artifacts that can be version-controlled, tested, and deployed across environments using standard CI/CD practices.

This approach ensures consistency, maintainability, and security while providing the flexibility needed for enterprise-scale agent lifecycle management.