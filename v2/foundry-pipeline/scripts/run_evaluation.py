"""
run_evaluation.py
Verifies the deployed agent exists and is correctly configured.
Writes eval_results.json for downstream check_eval_threshold.py.

Usage: python run_evaluation.py --env dev
       python run_evaluation.py --env qa
"""

import argparse
import json
import os
import sys
import time

from azure.ai.projects import AIProjectClient
from azure.core.rest import HttpRequest
from azure.identity import DefaultAzureCredential


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


def run_evaluation(env: str, smoke_test: bool = False) -> None:
    config = CONFIGS[env]
    endpoint = config["endpoint"]
    expected_model = config["model_deployment"]

    print(f"Running evaluation against {env}: {endpoint}")

    client = AIProjectClient(endpoint=endpoint, credential=DefaultAzureCredential())

    results = {}

    # ── Check 1: Agent exists ─────────────────────────────────────────────────
    print("\n[1/3] Checking agent exists...")
    try:
        req = HttpRequest("GET", f"agents/{AGENT_NAME}?api-version=v1")
        resp = client.send_request(req, stream=False)
        if resp.status_code < 400:
            results["agent_exists"] = {"pass_rate": 1.0, "passed": 1, "failed": 0}
            print(f"  ✓ Agent '{AGENT_NAME}' found (HTTP {resp.status_code})")
        else:
            results["agent_exists"] = {"pass_rate": 0.0, "passed": 0, "failed": 1}
            print(f"  ✗ Agent not found: HTTP {resp.status_code} — {resp.text()}")
    except Exception as e:
        results["agent_exists"] = {"pass_rate": 0.0, "passed": 0, "failed": 1}
        print(f"  ✗ Error checking agent: {e}")

    # ── Check 2: Agent has a deployed version ─────────────────────────────────
    print("\n[2/3] Checking agent versions...")
    try:
        req = HttpRequest("GET", f"agents/{AGENT_NAME}/versions?api-version=v1")
        resp = client.send_request(req, stream=False)
        versions = resp.json().get("value", []) if resp.status_code < 400 else []
        if versions:
            results["agent_has_version"] = {"pass_rate": 1.0, "passed": 1, "failed": 0}
            print(f"  ✓ {len(versions)} version(s) found")
        else:
            results["agent_has_version"] = {"pass_rate": 0.0, "passed": 0, "failed": 1}
            print(f"  ✗ No versions found")
    except Exception as e:
        results["agent_has_version"] = {"pass_rate": 0.0, "passed": 0, "failed": 1}
        print(f"  ✗ Error: {e}")

    # ── Check 3: Latest version uses the right model ──────────────────────────
    print("\n[3/3] Checking model deployment...")
    try:
        versions_list = resp.json().get("value", []) if resp.status_code < 400 else []
        if versions_list:
            latest = versions_list[-1]
            model = latest.get("definition", {}).get("model", "")
            if model == expected_model:
                results["correct_model"] = {"pass_rate": 1.0, "passed": 1, "failed": 0}
                print(f"  ✓ Model is '{model}'")
            else:
                # Partial pass — deployed but different model
                results["correct_model"] = {"pass_rate": 0.5, "passed": 0, "failed": 1}
                print(f"  ~ Model is '{model}' (expected '{expected_model}')")
        else:
            results["correct_model"] = {"pass_rate": 0.0, "passed": 0, "failed": 1}
            print("  ✗ No versions to inspect")
    except Exception as e:
        results["correct_model"] = {"pass_rate": 0.0, "passed": 0, "failed": 1}
        print(f"  ✗ Error: {e}")

    # ── Write results ─────────────────────────────────────────────────────────
    results_path = os.path.join(os.path.dirname(__file__), "../eval_results.json")
    with open(results_path, "w") as f:
        json.dump(results, f, indent=2)

    threshold = 0.8
    all_passed = all(r["pass_rate"] >= threshold for r in results.values())
    passed = sum(1 for r in results.values() if r["pass_rate"] >= threshold)

    print(f"\n{'='*60}")
    print(f"Checks passed : {passed}/{len(results)}")
    print(f"Overall       : {'PASS' if all_passed else 'FAIL'}")
    print(f"Results path  : {os.path.abspath(results_path)}")
    print(f"{'='*60}")

    if not all_passed:
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Verify deployed agent configuration"
    )
    parser.add_argument("--env", required=True, choices=["dev", "qa"])
    parser.add_argument("--smoke-test", action="store_true")
    args = parser.parse_args()
    run_evaluation(args.env, args.smoke_test)
