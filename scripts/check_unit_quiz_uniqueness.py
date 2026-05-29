#!/usr/bin/env python3
"""Check unit quiz generation for duplicate questions across attempts.

Usage:
  python scripts/check_unit_quiz_uniqueness.py --base http://127.0.0.1:8000 --token <JWT> --subject Physics --unit Kinematics --runs 5

The script will optionally call the async prefill endpoint, then call /mock-test/unit/generate
multiple times and report any repeated question hashes.
"""
import argparse
import json
import sys
import time
from typing import List

import requests


def post(url: str, token: str, payload: dict, timeout: int = 15):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    resp = requests.post(url, headers=headers, json=payload, timeout=timeout)
    resp.raise_for_status()
    return resp.json()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base", required=True)
    p.add_argument("--token", required=True)
    p.add_argument("--subject", required=True)
    p.add_argument("--unit", required=True)
    p.add_argument("--runs", type=int, default=5)
    p.add_argument("--prefill-size", type=int, default=150)
    args = p.parse_args()

    base = args.base.rstrip("/")
    token = args.token
    subject = args.subject
    unit = args.unit
    runs = args.runs

    print(f"Prefilling unit {subject}/{unit} (async, size={args.prefill_size})")
    try:
        post(f"{base}/mock-test/unit/prefill?mode=async&size={args.prefill_size}", token, {"subject": subject, "unit": unit}, timeout=10)
    except Exception as exc:
        print(f"Prefill request failed (continuing): {exc}")

    time.sleep(2)

    all_hashes: List[List[str]] = []

    for i in range(runs):
        print(f"Run {i+1}/{runs}: requesting /mock-test/unit/generate")
        try:
            payload = {"subject": subject, "unit": unit}
            data = post(f"{base}/mock-test/unit/generate", token, payload, timeout=30)
        except Exception as exc:
            print(f"  Request failed: {exc}")
            continue

        questions = data.get("questions") or data.get("quiz", {}).get("questions") or []
        hashes = [str(q.get("hash", "")).strip() for q in questions]
        print(f"  Received {len(hashes)} questions; first hashes: {hashes[:5]}")
        all_hashes.append(hashes)

        # small delay between runs
        time.sleep(1)

    # analyze duplicates
    seen = {}
    duplicates = []
    for run_idx, hashes in enumerate(all_hashes, start=1):
        for h in hashes:
            if not h:
                continue
            if h in seen and seen[h] != run_idx:
                duplicates.append((h, seen[h], run_idx))
            seen[h] = run_idx

    if not all_hashes:
        print("No successful runs recorded.")
        sys.exit(2)

    if duplicates:
        print("Duplicates found across attempts:")
        for h, first_run, later_run in duplicates:
            print(f"  hash {h} seen in run {first_run} and run {later_run}")
        sys.exit(1)
    else:
        print("No duplicates detected across runs.")
        sys.exit(0)


if __name__ == '__main__':
    main()
