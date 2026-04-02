"""
deploy_agent.py
Deploys an agent to Microsoft Foundry (new non-hub project).

Requirements:
    pip install "azure-ai-projects>=2.0.0b4" azure-identity

Endpoint format:
    https://<AIFoundryResourceName>.services.ai.azure.com/api/projects/<ProjectName>
    Find it in: Foundry Portal > Your Project > Overview > Libraries > Foundry

Usage:
    python deploy_agent.py --env dev
    python deploy_agent.py --env qa
"""

import argparse
import json
import sys

from azure.ai.projects import AIProjectClient
from azure.core.rest import HttpRequest
from azure.identity import DefaultAzureCredential


# ── Config ────────────────────────────────────────────────────────────────────

CONFIGS = {
    "dev": {
        "endpoint": "https://externalfoundry.services.ai.azure.com/api/projects/dev",
        "model_deployment": "gpt-4.1",
    },
    "qa": {
        "endpoint": "https://externalfoundry.services.ai.azure.com/api/projects/test",
        "model_deployment": "gpt-4.1",
    },
}

AGENT_NAME = "seattle-hotel-agent"

AGENT_INSTRUCTIONS = (
    "You are a helpful travel assistant specializing in finding hotels in Seattle, Washington. "
    "When a user asks about hotels in Seattle: "
    "1. Ask for their check-in and check-out dates if not provided. "
    "2. Ask about their budget preferences if not mentioned. "
    "3. Present results in a friendly, informative way. "
    "4. Offer to help with additional questions about the hotels or Seattle. "
    "If users ask about things outside of Seattle hotels, politely let them know you specialise "
    "in Seattle hotel recommendations."
)

AGENT_TOOLS = [
    {
        "type": "function",
        "name": "get_available_hotels",
        "description": "Retrieve available hotels in Seattle based on filters",
        "parameters": {
            "type": "object",
            "properties": {
                "checkin_date":  {"type": "string", "description": "Check-in date YYYY-MM-DD"},
                "checkout_date": {"type": "string", "description": "Check-out date YYYY-MM-DD"},
                "budget":        {"type": "string", "enum": ["budget", "mid-range", "luxury"]},
                "location":      {"type": "string", "description": "Neighbourhood in Seattle"},
            },
            "required": ["checkin_date", "checkout_date"],
        },
    }
]


# ── Main ──────────────────────────────────────────────────────────────────────

def deploy_agent(env: str) -> None:
    if env not in CONFIGS:
        print(f"Unknown environment '{env}'. Choose from: {list(CONFIGS.keys())}")
        sys.exit(1)

    config   = CONFIGS[env]
    endpoint = config["endpoint"]
    model    = config["model_deployment"]

    print(f"Connecting to : {endpoint}")
    print(f"Environment   : {env}")
    print(f"Agent         : {AGENT_NAME}")
    print(f"Model         : {model}")

    client = AIProjectClient(
        endpoint=endpoint,
        credential=DefaultAzureCredential(),
    )

    # Check for existing versions
    print("\nChecking for existing agent...")
    try:
        existing = client.agents.get(agent_name=AGENT_NAME)
        print(f"  Found existing '{AGENT_NAME}'. Creating new version...")
    except Exception:
        print(f"  No existing agent found. Creating fresh in '{env}'...")

    # Deploy — send raw HTTP to avoid SDK serialization stripping 'name'
    print(f"\nDeploying agent to '{env}'...")
    body = {
        "name": AGENT_NAME,
        "description": "A travel assistant agent specializing in Seattle hotel recommendations.",
        "definition": {
            "kind": "prompt",
            "model": model,
            "instructions": AGENT_INSTRUCTIONS,
            "tools": AGENT_TOOLS,
        },
    }

    request = HttpRequest(
        method="POST",
        url=f"agents/{AGENT_NAME}/versions?api-version=v1",
        headers={"Content-Type": "application/json"},
        content=json.dumps(body).encode("utf-8"),
    )

    response = client.send_request(request, stream=False)
    if response.status_code >= 400:
        print(f"Error {response.status_code}: {response.text()}")
        sys.exit(1)

    result = response.json()
    print(f"\n✓ Agent deployed successfully in '{env}'")
    print(f"  ID      : {result['id']}")
    print(f"  Name    : {result['name']}")
    print(f"  Version : {result['version']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Deploy Seattle Hotel Agent to Foundry")
    parser.add_argument("--env", required=True, choices=["dev", "qa"], help="Target environment")
    args = parser.parse_args()
    deploy_agent(args.env)