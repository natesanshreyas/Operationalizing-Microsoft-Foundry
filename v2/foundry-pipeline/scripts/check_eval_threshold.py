"""
check_eval_threshold.py
Gates the promotion pipeline based on evaluation pass rates.
Usage: python check_eval_threshold.py --results eval_results.json --threshold 0.8
"""

import argparse
import json
import sys


def check_thresholds(results_path: str, threshold: float):
    with open(results_path) as f:
        results = json.load(f)

    if not results:
        print("\nNo evaluation results found — cannot gate promotion.")
        sys.exit(1)

    all_passed = True
    print(f"\nEvaluation Threshold Check (minimum: {threshold * 100:.0f}%)")
    print("-" * 55)

    for evaluator, stats in sorted(results.items()):
        pass_rate = stats.get("pass_rate", 0)
        passed = stats.get("passed", 0)
        failed = stats.get("failed", 0)
        total = passed + failed
        status = "✓ PASS" if pass_rate >= threshold else "✗ FAIL"
        print(f"  {status} | {evaluator:<25} | {pass_rate * 100:.1f}%  ({passed}/{total})")
        if pass_rate < threshold:
            all_passed = False

    print("-" * 55)

    if all_passed:
        print(f"\n✓ All {len(results)} evaluators passed threshold. Promotion approved.\n")
        sys.exit(0)
    else:
        print("\n✗ One or more evaluators failed threshold. Promotion blocked.\n")
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--results", required=True, help="Path to eval_results.json")
    parser.add_argument("--threshold", type=float, default=0.8, help="Minimum pass rate (0.0 - 1.0)")
    args = parser.parse_args()
    check_thresholds(args.results, args.threshold)
