"""
setup_foundryiq.py
Creates a FoundryIQ knowledge source (Azure Blob → Azure AI Search) and
knowledge base, with all required RBAC role assignments and managed-identity
wiring.

FoundryIQ uses Azure AI Search as its underlying indexing and retrieval engine.
A "knowledge source" points at an external data store (blob container) and
auto-generates a search index + indexer pipeline.  A "knowledge base" groups
one or more knowledge sources and exposes them for agentic retrieval.

Prerequisites:
    pip install azure-identity requests

    You must be logged in with ``az login`` (or have DefaultAzureCredential
    configured) and have Owner / User Access Administrator on the resource
    group so the script can create RBAC assignments.

Usage:
    python setup_foundryiq.py --env dev
    python setup_foundryiq.py --env dev --skip-rbac        # if roles already assigned
    python setup_foundryiq.py --env dev --container mydata  # custom container name

What the script does (idempotent – safe to re-run):
    1. Enables system-assigned managed identity on the AI Search service.
    2. Retrieves principal IDs for the Search MI and the Foundry (AIServices) MI.
    3. Creates RBAC role assignments:
       - Search MI  → Storage Blob Data Reader  on the storage account
       - Search MI  → Cognitive Services OpenAI User on the Foundry account
       - Foundry MI → Search Index Data Contributor on the search service
       - Foundry MI → Search Service Contributor on the search service
    4. Enables public network access on the storage account (required for
       Search indexer connectivity unless private endpoints are configured).
    5. Creates the blob knowledge source via the Search REST API
       (``PUT /knowledgesources``).
    6. Creates the knowledge base via the Search REST API
       (``PUT /knowledgebases``).
    7. Registers Foundry project connections (CognitiveSearch + knowledge
       base MCP) so the KB is visible in the Foundry portal.
    8. Polls ingestion status until the first sync completes.
"""

import argparse
import json
import os
import subprocess
import sys
import time

import requests as http_requests
from azure.identity import DefaultAzureCredential

# ── Search REST API version (agentic retrieval preview) ─────────────────────
SEARCH_API_VERSION = "2025-11-01-preview"

# ── Environment configs ─────────────────────────────────────────────────────
CONFIGS = {
    "dev": {
        "subscription_id": "68837237-5a48-41a9-bed4-947f5c277684",
        "resource_group": "default-activitylogalerts",
        # Foundry (AIServices) account
        "foundry_account_name": "ExternalFoundry",
        "foundry_openai_endpoint": "https://externalfoundry.openai.azure.com",
        "project_name": "dev",
        # AI Search service
        "search_service_name": "shreyassearch",
        # Storage account
        "storage_account_name": "shreyasblob",
        "default_container": "sample-grounded-documents",
        # Model deployments
        "embedding_deployment": "text-embedding-3-small",
        "embedding_model": "text-embedding-3-small",
        "chat_deployment": "gpt-4.1",
        "chat_model": "gpt-4.1",
        # Naming
        "knowledge_source_name": "foundryiq-blob-ks-dev",
        "knowledge_base_name": "foundryiq-kb-dev",
    },
    "qa": {
        "subscription_id": "68837237-5a48-41a9-bed4-947f5c277684",
        "resource_group": "default-activitylogalerts",
        # Foundry (AIServices) account
        "foundry_account_name": "ExternalFoundry",
        "foundry_openai_endpoint": "https://externalfoundry.openai.azure.com",
        "project_name": "test",
        # AI Search service
        "search_service_name": "shreyassearch",
        # Storage account
        "storage_account_name": "shreyasblob",
        "default_container": "sample-grounded-documents",
        # Model deployments
        "embedding_deployment": "text-embedding-3-small",
        "embedding_model": "text-embedding-3-small",
        "chat_deployment": "gpt-4.1",
        "chat_model": "gpt-4.1",
        # Naming
        "knowledge_source_name": "foundryiq-blob-ks-test",
        "knowledge_base_name": "foundryiq-kb-test",
    },
}

# ── RBAC role definition IDs (well-known Azure built-in roles) ──────────────
ROLES = {
    "Storage Blob Data Reader": "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1",
    "Cognitive Services OpenAI User": "5e0bd9bd-7b93-4f28-af87-19fc36ad61bd",
    "Search Index Data Contributor": "8ebe5a00-799e-43f5-93ac-243d3dce84a7",
    "Search Service Contributor": "7ca78c08-252a-4471-8644-bb5ff32d4ba0",
}

POLL_INTERVAL = 10  # seconds between ingestion status checks
MAX_POLL_TIME = 300  # 5 minutes max wait


# ═════════════════════════════════════════════════════════════════════════════
#  Helpers
# ═════════════════════════════════════════════════════════════════════════════

def az_cli(args: list[str], check: bool = True) -> dict | str:
    """Run an ``az`` CLI command and return parsed JSON (or raw text)."""
    cmd = ["az"] + args + ["-o", "json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"  ✗ az {' '.join(args[:4])}... failed:\n{result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return result.stdout.strip()


def get_search_admin_key(service_name: str, resource_group: str) -> str:
    """Retrieve the primary admin key for the search service."""
    result = az_cli([
        "search", "admin-key", "show",
        "--service-name", service_name,
        "--resource-group", resource_group,
    ])
    return result["primaryKey"]


def search_api(method: str, path: str, search_url: str, api_key: str,
               body: dict | None = None) -> dict:
    """Call the Azure AI Search REST API."""
    url = f"{search_url}/{path}"
    params = {"api-version": SEARCH_API_VERSION}
    headers = {
        "Content-Type": "application/json",
        "api-key": api_key,
    }
    resp = http_requests.request(method, url, headers=headers, params=params,
                                 json=body, timeout=60)
    if resp.status_code >= 400:
        print(f"  ✗ {method} {path} → {resp.status_code}\n{resp.text}", file=sys.stderr)
        sys.exit(1)
    return resp.json() if resp.text else {}


# ═════════════════════════════════════════════════════════════════════════════
#  Step functions
# ═════════════════════════════════════════════════════════════════════════════

def enable_search_managed_identity(cfg: dict) -> str:
    """Enable system-assigned MI on the search service and return its principal ID."""
    print("\n── Step 1: Enable system-assigned managed identity on AI Search ──")
    result = az_cli([
        "search", "service", "update",
        "--name", cfg["search_service_name"],
        "--resource-group", cfg["resource_group"],
        "--identity-type", "SystemAssigned",
    ])
    principal_id = result["identity"]["principalId"]
    print(f"  ✓ Search MI principal: {principal_id}")
    return principal_id


def get_foundry_managed_identity(cfg: dict) -> str:
    """Get the Foundry (AIServices) system-assigned MI principal ID."""
    print("\n── Step 2: Retrieve Foundry account managed identity ─────────────")
    result = az_cli([
        "cognitiveservices", "account", "show",
        "--name", cfg["foundry_account_name"],
        "--resource-group", cfg["resource_group"],
    ])
    identity = result.get("identity", {})
    if not identity or identity.get("type") != "SystemAssigned":
        print("  ✗ Foundry account does not have a system-assigned MI.", file=sys.stderr)
        print("    Enable it in the portal or with:", file=sys.stderr)
        print(f"    az cognitiveservices account identity assign "
              f"--name {cfg['foundry_account_name']} "
              f"--resource-group {cfg['resource_group']}", file=sys.stderr)
        sys.exit(1)
    principal_id = identity["principalId"]
    print(f"  ✓ Foundry MI principal: {principal_id}")
    return principal_id


def _get_project_mi(cfg: dict) -> str | None:
    """Get the Foundry project system-assigned MI principal ID (if any)."""
    sub = cfg["subscription_id"]
    rg = cfg["resource_group"]
    foundry = cfg["foundry_account_name"]
    project = cfg["project_name"]
    url = (
        f"https://management.azure.com/subscriptions/{sub}"
        f"/resourceGroups/{rg}/providers/Microsoft.CognitiveServices"
        f"/accounts/{foundry}/projects/{project}"
        f"?api-version=2025-04-01-preview"
    )
    result = subprocess.run(
        ["az", "rest", "--method", "GET", "--url", url,
         "--query", "identity.principalId", "-o", "tsv"],
        capture_output=True, text=True,
    )
    pid = result.stdout.strip()
    if pid:
        print(f"  Project MI principal: {pid}")
    return pid or None


def assign_rbac_roles(cfg: dict, search_mi: str, foundry_mi: str):
    """Create the RBAC assignments needed for FoundryIQ."""
    print("\n── Step 3: Assign RBAC roles ─────────────────────────────────────")
    sub = cfg["subscription_id"]
    rg = cfg["resource_group"]

    search_scope = (f"/subscriptions/{sub}/resourceGroups/{rg}"
                    f"/providers/Microsoft.Search/searchServices/{cfg['search_service_name']}")

    assignments = [
        # Search MI → read blobs from storage
        {
            "assignee": search_mi,
            "role": "Storage Blob Data Reader",
            "scope": f"/subscriptions/{sub}/resourceGroups/{rg}"
                     f"/providers/Microsoft.Storage/storageAccounts/{cfg['storage_account_name']}",
            "desc": "Search MI → Storage Blob Data Reader",
        },
        # Search MI → call embedding model on Foundry
        {
            "assignee": search_mi,
            "role": "Cognitive Services OpenAI User",
            "scope": f"/subscriptions/{sub}/resourceGroups/{rg}"
                     f"/providers/Microsoft.CognitiveServices/accounts/{cfg['foundry_account_name']}",
            "desc": "Search MI → Cognitive Services OpenAI User",
        },
        # Foundry MI → write to search indexes
        {
            "assignee": foundry_mi,
            "role": "Search Index Data Contributor",
            "scope": search_scope,
            "desc": "Foundry MI → Search Index Data Contributor",
        },
        # Foundry MI → manage search service objects
        {
            "assignee": foundry_mi,
            "role": "Search Service Contributor",
            "scope": search_scope,
            "desc": "Foundry MI → Search Service Contributor",
        },
    ]

    # Also assign roles to the project MI (needed for portal KB browsing)
    project_mi = _get_project_mi(cfg)
    if project_mi:
        assignments.extend([
            {
                "assignee": project_mi,
                "role": "Search Index Data Reader",
                "scope": search_scope,
                "desc": "Project MI → Search Index Data Reader",
            },
            {
                "assignee": project_mi,
                "role": "Search Service Contributor",
                "scope": search_scope,
                "desc": "Project MI → Search Service Contributor",
            },
        ])

    for a in assignments:
        cmd = [
            "role", "assignment", "create",
            "--assignee", a["assignee"],
            "--role", a["role"],
            "--scope", a["scope"],
        ]
        result = subprocess.run(
            ["az"] + cmd + ["-o", "json"],
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            print(f"  ✓ {a['desc']}")
        elif "RoleAssignmentExists" in result.stderr or "Conflict" in result.stderr:
            print(f"  • {a['desc']} (already exists)")
        else:
            print(f"  ✗ {a['desc']} failed: {result.stderr.strip()}", file=sys.stderr)
            sys.exit(1)


def enable_storage_public_access(cfg: dict):
    """Enable public network access on the storage account (for indexer connectivity)."""
    print("\n── Step 4: Enable public network access on storage account ───────")
    result = az_cli([
        "storage", "account", "show",
        "-n", cfg["storage_account_name"],
        "--query", "publicNetworkAccess",
    ])
    if result == "Enabled":
        print("  • Already enabled")
        return

    az_cli([
        "storage", "account", "update",
        "-n", cfg["storage_account_name"],
        "-g", cfg["resource_group"],
        "--public-network-access", "Enabled",
    ])
    print("  ✓ Public network access enabled")


def create_knowledge_source(cfg: dict, search_url: str, api_key: str,
                            container: str):
    """Create the blob knowledge source via the Search REST API."""
    print("\n── Step 5: Create blob knowledge source ──────────────────────────")
    sub = cfg["subscription_id"]
    rg = cfg["resource_group"]
    storage = cfg["storage_account_name"]
    ks_name = cfg["knowledge_source_name"]

    # Use ResourceId connection string for managed-identity auth (no keys)
    resource_id_conn = (
        f"ResourceId=/subscriptions/{sub}/resourceGroups/{rg}"
        f"/providers/Microsoft.Storage/storageAccounts/{storage};"
    )

    body = {
        "name": ks_name,
        "kind": "azureBlob",
        "description": (
            f"FoundryIQ knowledge source connected to {storage} "
            f"blob storage via system-assigned managed identity"
        ),
        "azureBlobParameters": {
            "connectionString": resource_id_conn,
            "containerName": container,
            "isADLSGen2": False,
            "ingestionParameters": {
                "disableImageVerbalization": False,
                "contentExtractionMode": "minimal",
                "embeddingModel": {
                    "kind": "azureOpenAI",
                    "azureOpenAIParameters": {
                        "resourceUri": cfg["foundry_openai_endpoint"],
                        "deploymentId": cfg["embedding_deployment"],
                        "modelName": cfg["embedding_model"],
                    },
                },
                "chatCompletionModel": {
                    "kind": "azureOpenAI",
                    "azureOpenAIParameters": {
                        "resourceUri": cfg["foundry_openai_endpoint"],
                        "deploymentId": cfg["chat_deployment"],
                        "modelName": cfg["chat_model"],
                    },
                },
            },
        },
    }

    result = search_api("PUT", f"knowledgesources/{ks_name}", search_url,
                        api_key, body)

    created = result.get("azureBlobParameters", {}).get("createdResources", {})
    print(f"  ✓ Knowledge source '{ks_name}' created")
    print(f"    Container : {container}")
    print(f"    Auth      : system-assigned managed identity (ResourceId)")
    print(f"    Embedding : {cfg['embedding_deployment']}")
    print(f"    Chat model: {cfg['chat_deployment']}")
    if created:
        print(f"    Auto-generated objects:")
        for kind, name in created.items():
            print(f"      - {kind}: {name}")
    return result


def create_knowledge_base(cfg: dict, search_url: str, api_key: str):
    """Create the knowledge base that references the knowledge source."""
    print("\n── Step 6: Create knowledge base ─────────────────────────────────")
    kb_name = cfg["knowledge_base_name"]
    ks_name = cfg["knowledge_source_name"]

    body = {
        "name": kb_name,
        "description": (
            f"FoundryIQ knowledge base for {cfg['foundry_account_name']}, "
            f"grounded on blob storage data"
        ),
        "knowledgeSources": [{"name": ks_name}],
        "models": [
            {
                "kind": "azureOpenAI",
                "azureOpenAIParameters": {
                    "resourceUri": cfg["foundry_openai_endpoint"],
                    "deploymentId": cfg["chat_deployment"],
                    "modelName": cfg["chat_model"],
                },
            }
        ],
        "retrievalReasoningEffort": {"kind": "low"},
    }

    result = search_api("PUT", f"knowledgebases/{kb_name}", search_url,
                        api_key, body)
    print(f"  ✓ Knowledge base '{kb_name}' created")
    print(f"    Knowledge sources: [{ks_name}]")
    print(f"    Reasoning effort : low")
    print(f"    Chat model       : {cfg['chat_deployment']}")
    return result


def register_foundry_project_connections(cfg: dict):
    """Register the AI Search service and knowledge base as Foundry project connections.

    This makes the knowledge base visible in the Foundry portal under
    Build → Knowledge.  Both connections are idempotent (PUT = upsert).
    """
    print("\n── Step 7: Register Foundry project connections ──────────────────")
    sub = cfg["subscription_id"]
    rg = cfg["resource_group"]
    foundry = cfg["foundry_account_name"]
    project = cfg["project_name"]
    search = cfg["search_service_name"]
    kb_name = cfg["knowledge_base_name"]

    base_url = (
        f"https://management.azure.com/subscriptions/{sub}"
        f"/resourceGroups/{rg}/providers/Microsoft.CognitiveServices"
        f"/accounts/{foundry}/projects/{project}/connections"
    )
    api_version = "2025-04-01-preview"

    # Sanitised connection name (lowercase alphanumeric only)
    search_conn_name = search.replace("-", "").replace("_", "")
    kb_conn_name = f"kb-{kb_name}"

    # ── 7a. CognitiveSearch connection (links the Search service) ────────
    search_body = {
        "properties": {
            "authType": "AAD",
            "category": "CognitiveSearch",
            "group": "AzureAI",
            "isDefault": True,
            "isSharedToAll": False,
            "target": f"https://{search}.search.windows.net/",
            "useWorkspaceManagedIdentity": False,
            "metadata": {
                "ApiType": "Azure",
                "ApiVersion": "2024-05-01-preview",
                "DeploymentApiVersion": "2023-11-01",
                "ResourceId": (
                    f"/subscriptions/{sub}/resourceGroups/{rg}"
                    f"/providers/Microsoft.Search/searchServices/{search}"
                ),
                "displayName": search,
                "type": "azure_ai_search",
            },
        }
    }
    result = subprocess.run(
        ["az", "rest", "--method", "PUT",
         "--url", f"{base_url}/{search_conn_name}?api-version={api_version}",
         "--body", json.dumps(search_body), "-o", "json"],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        print(f"  ✓ Search connection '{search_conn_name}' → {search}")
    else:
        print(f"  ✗ Search connection failed: {result.stderr.strip()}", file=sys.stderr)
        # Non-fatal: knowledge source/base still works, just not visible in portal

    # ── 7b. Knowledge base MCP connection ────────────────────────────────
    kb_body = {
        "properties": {
            "audience": "https://search.azure.com",
            "authType": "ProjectManagedIdentity",
            "category": "RemoteTool",
            "group": "GenericProtocol",
            "isDefault": False,
            "isSharedToAll": False,
            "target": (
                f"https://{search}.search.windows.net"
                f"/knowledgebases/{kb_name}/mcp?api-version={SEARCH_API_VERSION}"
            ),
            "useWorkspaceManagedIdentity": False,
            "metadata": {
                "knowledgeBaseName": kb_name,
                "type": "knowledgeBase_MCP",
            },
        }
    }
    result = subprocess.run(
        ["az", "rest", "--method", "PUT",
         "--url", f"{base_url}/{kb_conn_name}?api-version={api_version}",
         "--body", json.dumps(kb_body), "-o", "json"],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        print(f"  ✓ Knowledge base connection '{kb_conn_name}' → {kb_name}")
    else:
        print(f"  ✗ KB connection failed: {result.stderr.strip()}", file=sys.stderr)


def poll_ingestion_status(cfg: dict, search_url: str, api_key: str):
    """Poll the knowledge source ingestion status until available."""
    print("\n── Step 8: Check ingestion status ────────────────────────────────")
    ks_name = cfg["knowledge_source_name"]
    elapsed = 0

    while elapsed < MAX_POLL_TIME:
        status = search_api("GET", f"knowledgesources/{ks_name}/status",
                            search_url, api_key)
        sync_status = status.get("synchronizationStatus", "unknown")
        last_sync = status.get("lastSynchronizationState")

        if last_sync:
            processed = last_sync.get("itemsUpdatesProcessed", 0)
            failed = last_sync.get("itemsUpdatesFailed", 0)
            print(f"  ✓ Ingestion complete (status: {sync_status})")
            print(f"    Items processed: {processed}")
            print(f"    Items failed   : {failed}")
            if processed == 0:
                print(f"    ℹ  Container appears empty — upload documents to "
                      f"trigger indexing on the next scheduled run.")
            return status

        print(f"  ⏳ Waiting for first sync... ({elapsed}s elapsed)")
        time.sleep(POLL_INTERVAL)
        elapsed += POLL_INTERVAL

    print("  ⚠ Timed out waiting for ingestion — check status in the portal")
    return None


# ═════════════════════════════════════════════════════════════════════════════
#  Main
# ═════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Set up FoundryIQ knowledge source & knowledge base",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python setup_foundryiq.py --env dev
  python setup_foundryiq.py --env dev --container my-docs
  python setup_foundryiq.py --env dev --skip-rbac
        """,
    )
    parser.add_argument(
        "--env", required=True, choices=CONFIGS.keys(),
        help="Target environment (dev, qa, etc.)",
    )
    parser.add_argument(
        "--container", default=None,
        help="Blob container name (default: from config)",
    )
    parser.add_argument(
        "--skip-rbac", action="store_true",
        help="Skip RBAC role assignments (if already configured)",
    )
    args = parser.parse_args()

    cfg = CONFIGS[args.env]
    container = args.container or cfg["default_container"]
    search_url = f"https://{cfg['search_service_name']}.search.windows.net"

    print("=" * 70)
    print("  FoundryIQ Knowledge Source Setup")
    print("=" * 70)
    print(f"  Environment    : {args.env}")
    print(f"  Foundry account: {cfg['foundry_account_name']}")
    print(f"  Search service : {cfg['search_service_name']}")
    print(f"  Storage account: {cfg['storage_account_name']}")
    print(f"  Container      : {container}")
    print("=" * 70)

    # ── Step 1 & 2: Get managed identities ──────────────────────────────
    search_mi = enable_search_managed_identity(cfg)
    foundry_mi = get_foundry_managed_identity(cfg)

    # ── Step 3: RBAC ────────────────────────────────────────────────────
    if args.skip_rbac:
        print("\n── Step 3: RBAC (skipped) ────────────────────────────────────────")
    else:
        assign_rbac_roles(cfg, search_mi, foundry_mi)

    # ── Step 4: Storage network access ──────────────────────────────────
    enable_storage_public_access(cfg)

    # ── Step 5: Get admin key & create knowledge source ─────────────────
    print("\n  Retrieving search admin key...")
    api_key = get_search_admin_key(cfg["search_service_name"], cfg["resource_group"])

    create_knowledge_source(cfg, search_url, api_key, container)

    # ── Step 6: Create knowledge base ───────────────────────────────────
    create_knowledge_base(cfg, search_url, api_key)

    # ── Step 7: Register Foundry project connections ────────────────
    register_foundry_project_connections(cfg)

    # ── Step 8: Verify ──────────────────────────────────────────────
    poll_ingestion_status(cfg, search_url, api_key)

    # ── Done ────────────────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print("  ✅ FoundryIQ setup complete!")
    print("=" * 70)
    print(f"""
  Next steps:
    1. Upload documents to the blob container:
       az storage blob upload-batch \\
         --account-name {cfg['storage_account_name']} \\
         --destination {container} \\
         --source ./my-documents \\
         --auth-mode login

    2. Trigger a manual indexer run (or wait for the daily schedule):
       curl -X POST "{search_url}/indexers/{cfg['knowledge_source_name']}-indexer/run?api-version={SEARCH_API_VERSION}" \\
         -H "api-key: <your-key>"

    3. Connect the knowledge base to a Foundry agent:
       - Foundry Portal → Build → Agents → select agent → add knowledge base
       - Or programmatically via the Foundry Agent API

    4. View in the portal:
       - Azure Portal    → AI Search → {cfg['search_service_name']} → Agentic retrieval
       - Foundry Portal  → Build → Knowledge → {cfg['knowledge_base_name']}
""")


if __name__ == "__main__":
    main()
