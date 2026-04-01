#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# provision_foundryiq_infra.sh
#
# Idempotent script that ensures all Azure infrastructure prerequisites
# for FoundryIQ exist in the target environment.
#
# What it checks / creates (skipping anything that already exists):
#   1. AI Search service              (Basic tier, system-assigned MI)
#   2. Embedding model deployment     (text-embedding-3-small)
#   3. Storage blob container         (for grounded documents)
#   4. RBAC role assignments          (Search MI ↔ Storage, Foundry ↔ Search)
#   5. Storage public network access  (enabled for indexer connectivity)
#
# Usage:
#   bash provision_foundryiq_infra.sh --env dev
#   bash provision_foundryiq_infra.sh --env qa
#
# All outputs use GitHub Actions ::group:: / ::notice:: / ::warning:: syntax
# so they render nicely in workflow logs.
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Parse arguments ─────────────────────────────────────────────────────────
ENV=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --env) ENV="$2"; shift 2 ;;
    *) echo "::error::Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "::error::--env is required (dev or qa)"
  exit 1
fi

# ── Environment configuration ──────────────────────────────────────────────
SUBSCRIPTION="00000000-0000-0000-0000-000000000000"

case "$ENV" in
  dev)
    RG="rg-YOUR-DEV-RESOURCE"
    FOUNDRY_ACCOUNT="YOUR-DEV-RESOURCE"
    PROJECT_NAME="agent-dev-project"
    SEARCH_SERVICE="your-ai-search-dev"
    STORAGE_ACCOUNT="yourstorageaccountdev"
    LOCATION="eastus2"
    ;;
  qa)
    RG="rg-YOUR-TEST-RESOURCE"
    FOUNDRY_ACCOUNT="YOUR-TEST-RESOURCE"
    PROJECT_NAME="agent-test-project"
    SEARCH_SERVICE="your-ai-search-test"
    STORAGE_ACCOUNT="yourstorageaccounttest"
    LOCATION="eastus2"
    ;;
  *)
    echo "::error::Unknown environment '$ENV'. Use 'dev' or 'qa'."
    exit 1
    ;;
esac

EMBEDDING_DEPLOYMENT="text-embedding-3-small"
EMBEDDING_MODEL="text-embedding-3-small"
EMBEDDING_VERSION="1"
CONTAINER_NAME="sample-grounded-documents"

echo "══════════════════════════════════════════════════════════════════════"
echo "  FoundryIQ Infrastructure Provisioning"
echo "══════════════════════════════════════════════════════════════════════"
echo "  Environment     : $ENV"
echo "  Resource Group  : $RG"
echo "  Foundry Account : $FOUNDRY_ACCOUNT"
echo "  Search Service  : $SEARCH_SERVICE"
echo "  Storage Account : $STORAGE_ACCOUNT"
echo "  Location        : $LOCATION"
echo "══════════════════════════════════════════════════════════════════════"

# ════════════════════════════════════════════════════════════════════════════
#  Step 0: Ensure the CI/CD service principal has storage roles
# ════════════════════════════════════════════════════════════════════════════
#  Step 0: Ensure the CI/CD service principal has required RBAC roles
#          (storage network rules, container creation, search management)
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "::group::Step 0 — Service principal RBAC"

STORAGE_SCOPE="/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"
RG_SCOPE="/subscriptions/$SUBSCRIPTION/resourceGroups/$RG"

assign_sp_role() {
  local ROLE="$1"
  local SCOPE="$2"
  local DESC="$3"
  local ASSIGNEE="$4"

  EXISTING=$(az role assignment list \
    --assignee "$ASSIGNEE" \
    --role "$ROLE" \
    --scope "$SCOPE" \
    --query "length(@)" -o tsv 2>/dev/null || echo "0")

  if [[ "$EXISTING" -gt 0 ]]; then
    echo "::notice::  • $DESC (already exists)"
  else
    az role assignment create \
      --assignee "$ASSIGNEE" \
      --role "$ROLE" \
      --scope "$SCOPE" \
      -o none 2>/dev/null || true
    echo "::notice::  ✓ $DESC"
  fi
}

# The SP object ID used by GitHub Actions OIDC — configure via env or fallback
CICD_SP="${AZURE_CLIENT_OBJECT_ID:-00000000-0000-0000-0000-000000000003}"

assign_sp_role "Storage Account Contributor" "$STORAGE_SCOPE" \
  "CI/CD SP → Storage Account Contributor (manage network rules)" "$CICD_SP"

assign_sp_role "Storage Blob Data Contributor" "$STORAGE_SCOPE" \
  "CI/CD SP → Storage Blob Data Contributor (create containers)" "$CICD_SP"

assign_sp_role "Search Service Contributor" "$RG_SCOPE" \
  "CI/CD SP → Search Service Contributor (manage search service)" "$CICD_SP"

echo "::endgroup::"

# ════════════════════════════════════════════════════════════════════════════
#  Step 1: AI Search service
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "::group::Step 1 — AI Search service ($SEARCH_SERVICE)"

SEARCH_EXISTS=$(az search service show \
  --name "$SEARCH_SERVICE" \
  --resource-group "$RG" \
  --query "name" -o tsv 2>/dev/null || echo "")

if [[ -n "$SEARCH_EXISTS" ]]; then
  echo "::notice::✓ AI Search service '$SEARCH_SERVICE' already exists — skipping creation"
else
  echo "Creating AI Search service '$SEARCH_SERVICE' (Basic tier)..."
  az search service create \
    --name "$SEARCH_SERVICE" \
    --resource-group "$RG" \
    --sku Basic \
    --location "$LOCATION" \
    --identity-type SystemAssigned \
    --partition-count 1 \
    --replica-count 1 \
    -o none
  echo "::notice::✓ Created AI Search service '$SEARCH_SERVICE'"
fi

# Ensure system-assigned MI is enabled (idempotent)
echo "Ensuring system-assigned managed identity..."
az search service update \
  --name "$SEARCH_SERVICE" \
  --resource-group "$RG" \
  --identity-type SystemAssigned \
  -o none 2>/dev/null || true

# Enable AAD + API key authentication (required for Foundry portal CognitiveSearch connections)
CURRENT_AUTH=$(az search service show \
  --name "$SEARCH_SERVICE" \
  --resource-group "$RG" \
  --query "authOptions" -o json 2>/dev/null || echo "{}")

if echo "$CURRENT_AUTH" | grep -q "aadOrApiKey"; then
  echo "::notice::  • AAD auth already enabled"
else
  echo "Enabling AAD + API key authentication..."
  az search service update \
    --name "$SEARCH_SERVICE" \
    --resource-group "$RG" \
    --auth-options aadOrApiKey \
    --aad-auth-failure-mode http401WithBearerChallenge \
    -o none 2>/dev/null || true
  echo "::notice::  ✓ Enabled AAD auth (aadOrApiKey)"
fi

SEARCH_MI=$(az search service show \
  --name "$SEARCH_SERVICE" \
  --resource-group "$RG" \
  --query "identity.principalId" -o tsv)

echo "  Search MI principal: $SEARCH_MI"
echo "::endgroup::"

# ════════════════════════════════════════════════════════════════════════════
#  Step 2: Embedding model deployment
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "::group::Step 2 — Embedding model deployment ($EMBEDDING_DEPLOYMENT)"

DEPLOY_EXISTS=$(az cognitiveservices account deployment show \
  --name "$FOUNDRY_ACCOUNT" \
  --resource-group "$RG" \
  --deployment-name "$EMBEDDING_DEPLOYMENT" \
  --query "name" -o tsv 2>/dev/null || echo "")

if [[ -n "$DEPLOY_EXISTS" ]]; then
  echo "::notice::✓ Embedding deployment '$EMBEDDING_DEPLOYMENT' already exists — skipping"
else
  echo "Deploying '$EMBEDDING_MODEL' (v$EMBEDDING_VERSION) as '$EMBEDDING_DEPLOYMENT'..."
  az cognitiveservices account deployment create \
    --name "$FOUNDRY_ACCOUNT" \
    --resource-group "$RG" \
    --deployment-name "$EMBEDDING_DEPLOYMENT" \
    --model-name "$EMBEDDING_MODEL" \
    --model-version "$EMBEDDING_VERSION" \
    --model-format OpenAI \
    --sku-capacity 120 \
    --sku-name "Standard" \
    -o none
  echo "::notice::✓ Deployed embedding model '$EMBEDDING_DEPLOYMENT'"
fi
echo "::endgroup::"

# ════════════════════════════════════════════════════════════════════════════
#  Step 3: Storage network access (must run before container creation)
#          Enables public network access AND sets default firewall action
#          to Allow so the GitHub Actions runner (and Search indexer) can
#          reach the storage account.
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "::group::Step 3 — Storage network access"

NETWORK_CHANGED=false

# 3a. Enable public network access
PUBLIC_ACCESS=$(az storage account show \
  -n "$STORAGE_ACCOUNT" \
  --query "publicNetworkAccess" -o tsv 2>/dev/null || echo "Unknown")

if [[ "$PUBLIC_ACCESS" == "Enabled" ]]; then
  echo "::notice::  • Public network access already enabled"
else
  echo "Enabling public network access on '$STORAGE_ACCOUNT'..."
  az storage account update \
    -n "$STORAGE_ACCOUNT" \
    -g "$RG" \
    --public-network-access Enabled \
    -o none
  NETWORK_CHANGED=true
  echo "::notice::  ✓ Enabled public network access"
fi

# 3b. Set firewall default action to Allow
DEFAULT_ACTION=$(az storage account show \
  -n "$STORAGE_ACCOUNT" \
  --query "networkRuleSet.defaultAction" -o tsv 2>/dev/null || echo "Unknown")

if [[ "$DEFAULT_ACTION" == "Allow" ]]; then
  echo "::notice::  • Firewall default action already 'Allow'"
else
  echo "Setting firewall default action to 'Allow'..."
  az storage account update \
    -n "$STORAGE_ACCOUNT" \
    -g "$RG" \
    --default-action Allow \
    -o none
  NETWORK_CHANGED=true
  echo "::notice::  ✓ Set firewall default action to 'Allow'"
fi

# Wait for network rule propagation if anything changed
if [[ "$NETWORK_CHANGED" == "true" ]]; then
  echo "  Waiting 30s for network rule propagation..."
  sleep 30
fi

echo "::endgroup::"

# ════════════════════════════════════════════════════════════════════════════
#  Step 4: Storage blob container
#          Uses ARM management plane (az rest) which only needs Storage
#          Account Contributor — avoids data-plane RBAC issues entirely.
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "::group::Step 4 — Storage blob container ($CONTAINER_NAME)"

CONTAINER_ARM_URL="https://management.azure.com/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT/blobServices/default/containers/$CONTAINER_NAME?api-version=2023-05-01"

CONTAINER_EXISTS=$(az rest --method GET --url "$CONTAINER_ARM_URL" --query "name" -o tsv 2>/dev/null || echo "")

if [[ -n "$CONTAINER_EXISTS" ]]; then
  echo "::notice::✓ Container '$CONTAINER_NAME' already exists — skipping"
else
  echo "Creating blob container '$CONTAINER_NAME' via ARM..."
  az rest --method PUT --url "$CONTAINER_ARM_URL" --body '{}' -o none
  echo "::notice::✓ Created container '$CONTAINER_NAME'"
fi
echo "::endgroup::"

# ════════════════════════════════════════════════════════════════════════════
#  Step 5: RBAC role assignments
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "::group::Step 5 — RBAC role assignments"

FOUNDRY_MI=$(az cognitiveservices account show \
  --name "$FOUNDRY_ACCOUNT" \
  --resource-group "$RG" \
  --query "identity.principalId" -o tsv)

echo "  Foundry MI principal: $FOUNDRY_MI"
echo "  Search MI principal : $SEARCH_MI"

assign_role() {
  local ASSIGNEE="$1"
  local ROLE="$2"
  local SCOPE="$3"
  local DESC="$4"

  # Check if assignment already exists
  EXISTING=$(az role assignment list \
    --assignee "$ASSIGNEE" \
    --role "$ROLE" \
    --scope "$SCOPE" \
    --query "length(@)" -o tsv 2>/dev/null || echo "0")

  if [[ "$EXISTING" -gt 0 ]]; then
    echo "::notice::  • $DESC (already exists)"
  else
    az role assignment create \
      --assignee "$ASSIGNEE" \
      --role "$ROLE" \
      --scope "$SCOPE" \
      -o none 2>/dev/null || true
    echo "::notice::  ✓ $DESC"
  fi
}

STORAGE_SCOPE="/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"
FOUNDRY_SCOPE="/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.CognitiveServices/accounts/$FOUNDRY_ACCOUNT"
SEARCH_SCOPE="/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.Search/searchServices/$SEARCH_SERVICE"

# Search MI → read blobs
assign_role "$SEARCH_MI" "Storage Blob Data Reader" "$STORAGE_SCOPE" \
  "Search MI → Storage Blob Data Reader"

# Search MI → call embedding model on Foundry
assign_role "$SEARCH_MI" "Cognitive Services OpenAI User" "$FOUNDRY_SCOPE" \
  "Search MI → Cognitive Services OpenAI User"

# Foundry MI → write to search indexes
assign_role "$FOUNDRY_MI" "Search Index Data Contributor" "$SEARCH_SCOPE" \
  "Foundry MI → Search Index Data Contributor"

# Foundry MI → manage search service objects
assign_role "$FOUNDRY_MI" "Search Service Contributor" "$SEARCH_SCOPE" \
  "Foundry MI → Search Service Contributor"

# Project MI → read search data (needed for Foundry portal KB browsing)
PROJECT_MI=$(az rest --method GET \
  --url "https://management.azure.com/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.CognitiveServices/accounts/$FOUNDRY_ACCOUNT/projects/$PROJECT_NAME?api-version=2025-04-01-preview" \
  --query "identity.principalId" -o tsv 2>/dev/null || echo "")

if [[ -n "$PROJECT_MI" ]]; then
  echo "  Project MI principal: $PROJECT_MI"
  assign_role "$PROJECT_MI" "Search Index Data Reader" "$SEARCH_SCOPE" \
    "Project MI → Search Index Data Reader"
  assign_role "$PROJECT_MI" "Search Service Contributor" "$SEARCH_SCOPE" \
    "Project MI → Search Service Contributor"
else
  echo "::warning::Could not retrieve project MI — skipping project RBAC"
fi

echo "::endgroup::"

# ════════════════════════════════════════════════════════════════════════════
#  Summary
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════════════════════"
echo "  ✅ FoundryIQ infrastructure provisioning complete for '$ENV'"
echo "══════════════════════════════════════════════════════════════════════"
echo "  Search Service  : $SEARCH_SERVICE (MI: $SEARCH_MI)"
echo "  Foundry Account : $FOUNDRY_ACCOUNT (MI: $FOUNDRY_MI)"
echo "  Storage Account : $STORAGE_ACCOUNT"
echo "  Container       : $CONTAINER_NAME"
echo "  Embedding Model : $EMBEDDING_DEPLOYMENT"
echo "══════════════════════════════════════════════════════════════════════"
