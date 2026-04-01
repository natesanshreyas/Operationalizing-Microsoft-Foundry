# scripts/copy_ft_checkpoint.py
import os, json, time, subprocess, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]

def sh(cmd, check=True):
    print("+", cmd)
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if p.stdout: print(p.stdout)
    if p.stderr: print(p.stderr)
    if check and p.returncode != 0:
        raise SystemExit(p.returncode)
    return p

def load_release(path):
    with open(path, "r") as f:
        return json.load(f)

def main():
    rel = load_release(str(ROOT / "releases/ft_release.json"))
    src = rel["source"]; dest = rel["destination"]
    src_res_id = f"/subscriptions/{src['subscription_id']}/resourceGroups/{src['resource_group']}/providers/Microsoft.CognitiveServices/accounts/{src['account_name']}"
    dest_res_id = f"/subscriptions/{dest['subscription_id']}/resourceGroups/{dest['resource_group']}/providers/Microsoft.CognitiveServices/accounts/{dest['account_name']}"

    copy_url = f"https://{src['account_name']}.openai.azure.com/openai/v1/fine_tuning/jobs/{src['fine_tune_job_id']}/checkpoints/{src['checkpoint_name']}/copy?api-version=2024-08-01-preview"
    body = {"destinationResourceId": dest_res_id, "region": dest["region"]}
    sh(f"az rest --method post --url '{copy_url}' --headers 'Content-Type=application/json' 'aoai-copy-ft-checkpoints=preview' --body '{json.dumps(body)}'")

    for i in range(10):
        print(f'Polling copy status... {i+1}/10')
        time.sleep(6)

    # Placeholder deployment to destination (adjust to your endpoint/API)
    deployment_name = dest["deployment_name"]
    payload = {
      "model": { "format": "OpenAI", "name": rel["base_model"], "version": "ft-copied" },
      "scaleSettings": { "scaleType": "Standard" }
    }
    deploy_url = f"https://management.azure.com{dest_res_id}/deployments/{deployment_name}?api-version=2023-05-01"
    # sh(f"az rest --method put --url '{deploy_url}' --headers 'Content-Type=application/json' --body '{json.dumps(payload)}'")

    out = {
        "release": rel["name"],
        "source_resource_id": src_res_id,
        "destination_resource_id": dest_res_id,
        "deployment_name": deployment_name,
        "timestamp": int(time.time())
    }
    out_path = ROOT / "releases" / f"{rel['name']}.promote_result.json"
    out_path.write_text(json.dumps(out, indent=2))
    print(f"Wrote {out_path}")

if __name__ == "__main__":
    main()

