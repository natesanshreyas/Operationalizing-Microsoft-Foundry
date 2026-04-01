# Azure AI Foundry – CI/CD Pipeline with FoundryIQ

End-to-end CI/CD pipeline for deploying agents, running safety evaluations, gating promotions, and setting up FoundryIQ knowledge sources in Microsoft Foundry (new portal).

## Project Structure

```
foundry-pipeline/
├── agents/                        # Agent definitions as JSON
│   └── seattle-hotel-agent.json
├── models/                        # Model deployment configs
│   └── gpt-deployment.json
├── datasets/                      # Evaluation JSONL datasets
│   └── seattle_hotel_eval.jsonl
├── evaluations/                   # Evaluator configs and thresholds
│   └── eval-config.json
├── config/
│   ├── dev.json                   # Dev environment config
│   └── qa.json                    # QA environment config
├── scripts/                       # Python automation scripts
│   ├── deploy_agent.py            # Deploy/update agent in a project
│   ├── run_evaluation.py          # Run evaluations via OpenAI Evals API
│   ├── check_eval_threshold.py    # Gate promotion on eval pass rates
│   ├── promote.py                 # Run full promotion flow locally
│   └── setup_foundryiq.py         # Set up FoundryIQ knowledge source + KB
└── .github/workflows/
    ├── deploy-dev.yml             # Triggered on push to develop
    └── promote-to-qa.yml          # Triggered on push to main
```

## Prerequisites

- Python 3.10+
- Azure CLI (`az`) authenticated
- An Azure subscription with:
  - Microsoft Foundry (AIServices) resources for Dev and QA
  - Azure AI Search service (Basic tier or higher, semantic ranker enabled)
  - Azure Blob Storage account

## Setup

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Authenticate with Azure:
   ```bash
   az login
   ```

3. Update `config/dev.json` and `config/qa.json` with your actual endpoints and project names.

## Usage

### Deploy agent to a specific environment
```bash
python scripts/deploy_agent.py --env dev
python scripts/deploy_agent.py --env qa
```

### Run evaluations

Evaluations use the **OpenAI Evals API** on the project-level endpoint with built-in safety evaluators (`builtin.violence`, `builtin.hate_unfairness`, `builtin.protected_material`). Results are visible in the Microsoft Foundry portal under **Build → Evaluations**.

```bash
python scripts/run_evaluation.py --env dev
python scripts/run_evaluation.py --env qa --smoke-test
```

### Check evaluation thresholds (quality gate)
```bash
python scripts/check_eval_threshold.py --results eval_results.json --threshold 0.8
```

### Run full promotion locally
```bash
python scripts/promote.py
```

### Set up FoundryIQ knowledge source

Creates a blob knowledge source and knowledge base in Azure AI Search for FoundryIQ agentic retrieval. The script handles managed identity, RBAC, and all necessary connections.

```bash
# Full setup (MI + RBAC + knowledge source + knowledge base)
python scripts/setup_foundryiq.py --env dev

# Use a custom blob container
python scripts/setup_foundryiq.py --env dev --container my-documents

# Skip RBAC if roles are already assigned
python scripts/setup_foundryiq.py --env dev --skip-rbac
```

**What `setup_foundryiq.py` does:**

| Step | Action |
|------|--------|
| 1 | Enables system-assigned managed identity on Azure AI Search |
| 2 | Retrieves the Foundry (AIServices) managed identity principal |
| 3 | Assigns 4 RBAC roles (Search ↔ Storage, Search ↔ Foundry, Foundry ↔ Search) |
| 4 | Enables public network access on the storage account |
| 5 | Creates the blob knowledge source (`PUT /knowledgesources`) with MI auth |
| 6 | Creates the knowledge base (`PUT /knowledgebases`) with agentic retrieval |
| 7 | Polls ingestion status until first sync completes |

## Azure Infrastructure

| Environment | Resource Group | Foundry Account | Project | Search Service |
|-------------|---------------|-----------------|---------|----------------|
| Dev | `rg-YOUR-DEV-RESOURCE` | `YOUR-DEV-RESOURCE` | `agent-dev-project` | `your-ai-search-dev` |
| QA/Test | `rg-YOUR-TEST-RESOURCE` | `YOUR-TEST-RESOURCE` | `agent-test-project` | — |

## GitHub Actions Secrets Required

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Service principal client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

The service principal needs these roles on both Dev and QA Foundry (CognitiveServices) accounts:

- **Contributor**
- **AI Foundry Agent Manager**
- **Azure AI Developer**
- **Cognitive Services OpenAI Contributor**

## Pipeline Flow

```
Push to develop  →  deploy-dev.yml
                        ├── Deploy agent to Dev
                        └── Run safety evaluations (OpenAI Evals API)

Push to main     →  promote-to-qa.yml
                        ├── Run safety evaluations on Dev
                        ├── Quality gate (check pass rates ≥ threshold)
                        ├── Deploy agent to QA
                        └── Smoke test
```

## FoundryIQ Architecture

```
┌─────────────────────┐    indexes     ┌─────────────────────────┐
│  Azure Blob Storage  │ ───────────► │  Azure AI Search         │
│  (sample-grounded-   │   (MI auth)   │  ┌─ knowledge source    │
│   documents)         │               │  ├─ index + indexer     │
└─────────────────────┘               │  ├─ skillset (chunking  │
                                       │  │   + vectorization)   │
┌─────────────────────┐   calls LLM   │  └─ knowledge base      │
│  Foundry (AIServices)│ ◄──────────  │     (agentic retrieval) │
│  gpt-5 + embedding  │               └─────────────────────────┘
│  text-embedding-3-   │                          │
│  small               │               ┌──────────┘
└──────────┬──────────┘               │  retrieve action
           │                           ▼
           │                  ┌─────────────────────┐
           └────────────────► │  Foundry Agent       │
              connected via   │  (seattle-hotel-     │
              knowledge base  │   agent)             │
                              └─────────────────────┘
```
