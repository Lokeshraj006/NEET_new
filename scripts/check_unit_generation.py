#!/usr/bin/env python3
"""Check unit/quiz generation latency and uniqueness across attempts.
Usage:
  Set env vars or pass args:
    AUTH_BASE_URL (default http://127.0.0.1:8000)
    AUTH_TOKEN (required) or will prompt
  Example:
    AUTH_BASE_URL=http://10.247.10.248:8000 AUTH_TOKEN="Bearer <token>" python scripts/check_unit_generation.py Physics "Kinematics" --attempts 5
"""
import os
import sys
import time
import argparse
import requests
from typing import List


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('subject', help='Subject (e.g., Physics)')
    parser.add_argument('unit', help='Unit/topic (e.g., Kinematics)')
    parser.add_argument('--attempts', type=int, default=5)
    parser.add_argument('--url', default=os.environ.get('AUTH_BASE_URL', 'http://127.0.0.1:8000'))
    parser.add_argument('--token', default=os.environ.get('AUTH_TOKEN'))
    args = parser.parse_args()

    if not args.token:
        args.token = input('Enter Authorization header value (e.g. Bearer <token>): ').strip()
    if not args.token:
        print('Authorization token required. Set AUTH_TOKEN env or pass --token.')
        sys.exit(2)

    headers = {'Authorization': args.token, 'Content-Type': 'application/json'}
    url = args.url.rstrip('/') + '/mock-test/unit/generate'

    all_hashes: List[str] = []
    attempts_hashes: List[List[str]] = []
    durations: List[float] = []

    for i in range(args.attempts):
        payload = {
            'subject': args.subject,
            'unit': args.unit,
        }
        print(f'Attempt {i+1}/{args.attempts} -> POST {url} subject={args.subject} unit={args.unit}')
        start = time.perf_counter()
        try:
            resp = requests.post(url, json=payload, headers=headers, timeout=120)
        except Exception as exc:
            duration = time.perf_counter() - start
            print(f'  Request failed after {duration:.2f}s: {exc}')
            durations.append(duration)
            attempts_hashes.append([])
            continue
        duration = time.perf_counter() - start
        durations.append(duration)
        print(f'  HTTP {resp.status_code} in {duration:.2f}s')
        try:
            data = resp.json()
        except Exception:
            print('  Response not JSON:')
            print(resp.text[:1000])
            attempts_hashes.append([])
            continue

        if not data.get('success') and resp.status_code != 200:
            # allow some endpoints to return 200 with success True
            print('  Error response:', data.get('detail') or data)
        questions = data.get('questions') or data.get('quiz', {}).get('questions') or []
        hashes = [str(q.get('hash', '')).strip() for q in questions if q]
        attempts_hashes.append(hashes)
        all_hashes.extend(hashes)
        print(f'  Returned {len(hashes)} questions')

    print('\nSummary:')
    for i, d in enumerate(durations):
        print(f' - Attempt {i+1}: {d:.2f}s, questions: {len(attempts_hashes[i])}')

    total_returned = sum(len(h) for h in attempts_hashes)
    unique_hashes = len(set(all_hashes))
    duplicates_across = total_returned - unique_hashes
    print(f'\nTotal questions returned across attempts: {total_returned}')
    print(f'Unique question hashes across attempts: {unique_hashes}')
    print(f'Duplicates across attempts: {duplicates_across}')

    # Per-attempt uniqueness
    for i, hlist in enumerate(attempts_hashes):
        dup = len(hlist) - len(set(hlist))
        print(f' - Attempt {i+1} internal duplicates: {dup}')

    if duplicates_across == 0:
        print('\nAll questions across attempts are unique.')
    else:
        print('\nSome questions repeated across attempts.')

    # Print slowest attempt
    if durations:
        idx = max(range(len(durations)), key=lambda k: durations[k])
        print(f'\nSlowest attempt: {idx+1} at {durations[idx]:.2f}s')


if __name__ == '__main__':
    main()
