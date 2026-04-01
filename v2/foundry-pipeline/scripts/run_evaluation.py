"""
run_evaluation.py
Runs evaluations via the OpenAI Evals API on the Foundry project endpoint.
Results appear in the **new** Microsoft Foundry portal (ai.azure.com).

The key insight: the project-level OpenAI endpoint requires an explicit
``api-version`` query parameter (e.g. ``2025-10-15-preview``).  The vanilla
``openai`` Python SDK does not attach one, so we use ``requests`` directly.

Usage: python run_evaluation.py --env dev
       python run_evaluation.py --env qa
"""

import argparse
import json
import os
import sys
import time

import requests as http_requests
from azure.identity import DefaultAzureCredential

# ── constants ────────────────────────────────────────────────────────────────
API_VERSION = "2025-10-15-preview"
TOKEN_SCOPE = "https://ai.azure.com/.default"
POLL_INTERVAL_SECONDS = 5
MAX_POLL_SECONDS = 600  # 10 minutes

# Evaluators available in the new Foundry Evals API
BUILTIN_EVALUATORS = {
    "violence": "builtin.violence",
    "hate_unfairness": "builtin.hate_unfairness",
    "protected_material": "builtin.protected_material",
    "self_harm": "builtin.self_harm",
    "sexual": "builtin.sexual",
    "indirect_attack": "builtin.indirect_attack",
}


# ── helpers ──────────────────────────────────────────────────────────────────
def _openai_base(project_endpoint: str) -> str:
    """Return the OpenAI file/eval base URL for a project endpoint."""
    return f"{project_endpoint.rstrip('/')}/openai"


def _api(extra: str = "") -> str:
    return f"?api-version={API_VERSION}{extra}"


def load_config(env: str) -> dict:
    config_path = os.path.join(os.path.dirname(__file__), f"../config/{env}.json")
    with open(config_path) as f:
        return json.load(f)


def load_eval_config(env: str) -> dict:
    """Load the environment-specific eval config (eval-config-{env}.json).

    Falls back to the shared eval-config.json if the env-specific file
    does not exist.
    """
    base = os.path.join(os.path.dirname(__file__), "../evaluations")
    env_path = os.path.join(base, f"eval-config-{env}.json")
    fallback_path = os.path.join(base, "eval-config.json")
    path = env_path if os.path.exists(env_path) else fallback_path
    print(f"  Loading eval config: {os.path.basename(path)}")
    with open(path) as f:
        return json.load(f)


def _get_token(credential) -> str:
    return credential.get_token(TOKEN_SCOPE).token


# ── upload ───────────────────────────────────────────────────────────────────
def upload_dataset(base_url: str, token: str, dataset_path: str) -> str:
    """Upload a JSONL file via the OpenAI Files API and return the file ID."""
    url = f"{base_url}/files{_api()}"
    with open(dataset_path, "rb") as f:
        resp = http_requests.post(
            url,
            headers={"Authorization": f"Bearer {token}"},
            files={"file": (os.path.basename(dataset_path), f, "application/jsonl")},
            data={"purpose": "evals"},
        )
    resp.raise_for_status()
    file_id = resp.json()["id"]
    print(f"  Uploaded file: {file_id}")
    return file_id


# ── eval CRUD ────────────────────────────────────────────────────────────────
def create_eval(
    base_url: str,
    token: str,
    name: str,
    evaluators: list[dict],
    item_schema: dict,
) -> str:
    """Create an Eval object and return its ID."""
    url = f"{base_url}/evals{_api()}"
    body = {
        "name": name,
        "data_source_config": {
            "type": "custom",
            "item_schema": item_schema,
            "include_sample_schema": True,
        },
        "testing_criteria": evaluators,
    }
    resp = http_requests.post(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json=body,
    )
    resp.raise_for_status()
    eval_id = resp.json()["id"]
    print(f"  Eval created: {eval_id}")
    return eval_id


def create_eval_run(
    base_url: str,
    token: str,
    eval_id: str,
    run_name: str,
    file_id: str,
) -> str:
    """Create an Eval Run and return its ID."""
    url = f"{base_url}/evals/{eval_id}/runs{_api()}"
    body = {
        "name": run_name,
        "data_source": {
            "type": "jsonl",
            "source": {"type": "file_id", "id": file_id},
        },
    }
    resp = http_requests.post(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json=body,
    )
    resp.raise_for_status()
    data = resp.json()
    run_id = data["id"]
    print(f"  Run created: {run_id}  (status: {data.get('status')})")
    return run_id


def poll_run(base_url: str, token: str, eval_id: str, run_id: str) -> dict:
    """Poll the run until it reaches a terminal state; return full run dict."""
    url = f"{base_url}/evals/{eval_id}/runs/{run_id}{_api()}"
    headers = {"Authorization": f"Bearer {token}"}
    elapsed = 0
    while elapsed < MAX_POLL_SECONDS:
        time.sleep(POLL_INTERVAL_SECONDS)
        elapsed += POLL_INTERVAL_SECONDS
        resp = http_requests.get(url, headers=headers)
        resp.raise_for_status()
        data = resp.json()
        status = data.get("status", "unknown")
        print(f"  [{elapsed}s] status={status}")
        if status in ("completed", "failed", "canceled"):
            return data
    raise TimeoutError(
        f"Evaluation run {run_id} did not finish within {MAX_POLL_SECONDS}s"
    )


def get_output_items(
    base_url: str, token: str, eval_id: str, run_id: str
) -> list[dict]:
    """Fetch all output items for a completed run."""
    url = f"{base_url}/evals/{eval_id}/runs/{run_id}/output_items{_api()}"
    headers = {"Authorization": f"Bearer {token}"}
    items = []
    while url:
        resp = http_requests.get(url, headers=headers)
        resp.raise_for_status()
        body = resp.json()
        items.extend(body.get("data", []))
        # Handle pagination
        if body.get("has_more") and body.get("last_id"):
            last = body["last_id"]
            url = (
                f"{base_url}/evals/{eval_id}/runs/{run_id}"
                f"/output_items{_api(f'&after={last}')}"
            )
        else:
            url = None
    return items


# ── build evaluator testing criteria ─────────────────────────────────────────
def build_testing_criteria(eval_config: dict) -> list[dict]:
    """Convert eval-config.json evaluators → OpenAI Evals testing_criteria."""
    criteria = []
    for entry in eval_config["evaluators"]:
        name = entry["name"]
        evaluator_name = BUILTIN_EVALUATORS.get(name)
        if evaluator_name is None:
            print(f"  WARNING: unknown evaluator '{name}' — skipping")
            continue

        # Convert ${data.field} mapping → {{item.field}} mapping
        data_mapping = {}
        for key, value in entry.get("data_mapping", {}).items():
            if value.startswith("${data.") and value.endswith("}"):
                field = value[7:-1]  # strip ${data. and }
                data_mapping[key] = "{{item." + field + "}}"
            else:
                data_mapping[key] = value

        criteria.append(
            {
                "type": "azure_ai_evaluator",
                "name": name,
                "evaluator_name": evaluator_name,
                "data_mapping": data_mapping,
            }
        )
    return criteria


# ── main evaluation logic ────────────────────────────────────────────────────
def run_evaluation(env: str, smoke_test: bool = False):
    config = load_config(env)
    eval_config = load_eval_config(env)
    endpoint = config["endpoint"]
    base_url = _openai_base(endpoint)

    print(f"Running evaluation against {env}: {config['project_name']}")

    credential = DefaultAzureCredential()
    token = _get_token(credential)

    # ──────────── 1. Upload dataset ────────────
    dataset_path = os.path.join(
        os.path.dirname(__file__), f"../{eval_config['dataset']}"
    )
    print("\n[1/4] Uploading evaluation dataset...")
    file_id = upload_dataset(base_url, token, dataset_path)

    # ──────────── 2. Build testing criteria ────────────
    print("\n[2/4] Building testing criteria...")
    criteria = build_testing_criteria(eval_config)
    print(f"  Evaluators: {', '.join(c['name'] for c in criteria)}")

    # Item schema — matches the JSONL dataset columns
    item_schema = {
        "type": "object",
        "properties": {
            "id": {"type": "number"},
            "prompt": {"type": "string"},
            "expected_output": {"type": "string"},
        },
        "required": ["prompt", "expected_output"],
    }

    # ──────────── 3. Create eval + run ────────────
    eval_name = f"{eval_config['evaluation_name']}-{env}"
    run_name = f"{eval_name}-{int(time.time())}"
    print(f"\n[3/4] Creating eval '{eval_name}' and starting run...")
    eval_id = create_eval(base_url, token, eval_name, criteria, item_schema)
    run_id = create_eval_run(base_url, token, eval_id, run_name, file_id)

    # ──────────── 4. Poll + analyze results ────────────
    print("\n[4/4] Waiting for evaluation to complete...")
    run_data = poll_run(base_url, token, eval_id, run_id)

    status = run_data.get("status")
    result_counts = run_data.get("result_counts", {})
    total = result_counts.get("total", 0)
    passed = result_counts.get("passed", 0)
    failed = result_counts.get("failed", 0)
    errored = result_counts.get("errored", 0)

    print(f"\n{'='*60}")
    print(f"Evaluation Status : {status}")
    print(f"Total items       : {total}")
    print(f"Passed            : {passed}")
    print(f"Failed            : {failed}")
    print(f"Errored           : {errored}")

    if status != "completed":
        print(f"\nERROR: evaluation ended with status '{status}'")
        print(f"Details: {json.dumps(run_data.get('error', {}), indent=2)}")
        sys.exit(1)

    # Pass rate and threshold
    pass_rate = passed / total if total > 0 else 0.0
    threshold = eval_config.get("pass_threshold", 0.8)
    overall_pass = pass_rate >= threshold

    print(f"\nPass rate         : {pass_rate:.1%}")
    print(f"Threshold         : {threshold:.0%}")
    print(f"Overall           : {'PASS' if overall_pass else 'FAIL'}")

    # Per-evaluator breakdown from output items
    print(f"\nPer-evaluator breakdown:")
    items = get_output_items(base_url, token, eval_id, run_id)
    evaluator_stats: dict[str, dict] = {}
    for item in items:
        for result in item.get("results", []):
            ename = result.get("name", "unknown")
            if ename not in evaluator_stats:
                evaluator_stats[ename] = {"passed": 0, "failed": 0}
            if result.get("passed", False):
                evaluator_stats[ename]["passed"] += 1
            else:
                evaluator_stats[ename]["failed"] += 1

    all_evaluators_pass = True
    for ename, stats in evaluator_stats.items():
        etotal = stats["passed"] + stats["failed"]
        erate = stats["passed"] / etotal if etotal > 0 else 0.0
        epassed = erate >= threshold
        if not epassed:
            all_evaluators_pass = False
        print(
            f"  {ename:<25} "
            f"{stats['passed']}/{etotal} ({erate:.0%}) "
            f"{'PASS' if epassed else 'FAIL'}"
        )

    # Write results JSON for downstream check_eval_threshold.py
    results_for_gate = {}
    for ename, stats in evaluator_stats.items():
        etotal = stats["passed"] + stats["failed"]
        results_for_gate[ename] = {
            "pass_rate": stats["passed"] / etotal if etotal > 0 else 0.0,
            "passed": stats["passed"],
            "failed": stats["failed"],
        }
    results_path = os.path.join(os.path.dirname(__file__), "../eval_results.json")
    with open(results_path, "w") as f:
        json.dump(results_for_gate, f, indent=2)
    print(f"\nResults written to {os.path.abspath(results_path)}")

    print(f"{'='*60}")

    if not overall_pass or not all_evaluators_pass:
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Run evaluations via Foundry OpenAI Evals API (visible in new Foundry portal)"
    )
    parser.add_argument("--env", required=True, choices=["dev", "qa"])
    parser.add_argument(
        "--smoke-test",
        action="store_true",
        help="Run a quick subset evaluation",
    )
    args = parser.parse_args()
    run_evaluation(args.env, args.smoke_test)
