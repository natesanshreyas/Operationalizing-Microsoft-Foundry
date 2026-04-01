"""
promote.py
Orchestrates the full dev -> QA promotion flow locally.
Usage: python promote.py
"""

import subprocess
import sys


def run(cmd: str):
    print(f"\n$ {cmd}")
    result = subprocess.run(cmd, shell=True)
    if result.returncode != 0:
        print(f"\n✗ Command failed: {cmd}")
        sys.exit(result.returncode)


if __name__ == "__main__":
    print("=" * 50)
    print(" Starting Dev -> QA Promotion")
    print("=" * 50)

    run("python scripts/run_evaluation.py --env dev")
    run("python scripts/check_eval_threshold.py --results eval_results.json --threshold 0.8")
    run("python scripts/deploy_agent.py --env qa")
    run("python scripts/run_evaluation.py --env qa --smoke-test")

    print("\n✓ Promotion to QA complete!\n")
