#!/usr/bin/env python3
"""Register/login then run unit generation attempts and report timings & uniqueness.
Usage:
  python scripts/run_checker_with_register.py --url http://127.0.0.1:8000 --subject Physics --unit Kinematics --attempts 5
This will try to register a local user (localtest@example.com). If registration fails due to existing user,
it will attempt to login with the same credentials.
"""
import argparse
import requests
import time
import sys

DEFAULT_EMAIL = "localtest@example.com"
DEFAULT_PASSWORD = "localpass123"
DEFAULT_NAME = "Local Test"


def get_token(base_url: str):
    # Try register
    reg_url = base_url.rstrip('/') + '/register'
    payload = {"name": DEFAULT_NAME, "email": DEFAULT_EMAIL, "password": DEFAULT_PASSWORD}
    try:
        r = requests.post(reg_url, json=payload, timeout=10)
    except Exception as e:
        print(f"Registration request failed: {e}")
        return None
    if r.status_code == 200:
        try:
            data = r.json()
            tok = data.get('token')
            if tok:
                print("Registered and obtained token.")
                return 'Bearer ' + tok
        except Exception:
            pass
    # If not 200, try login
    login_url = base_url.rstrip('/') + '/login'
    payload = {"email": DEFAULT_EMAIL, "password": DEFAULT_PASSWORD}
    try:
        r = requests.post(login_url, json=payload, timeout=10)
    except Exception as e:
        print(f"Login request failed: {e}")
        return None
    if r.status_code == 200:
        try:
            data = r.json()
            tok = data.get('token')
            if tok:
                print("Logged in and obtained token.")
                return 'Bearer ' + tok
        except Exception:
            pass
    print(f"Unable to obtain token: status={r.status_code}, body={r.text[:200]}")
    return None


def run_attempts(base_url: str, token: str, subject: str, unit: str, attempts: int):
    headers = {'Authorization': token, 'Content-Type': 'application/json'}
    url = base_url.rstrip('/') + '/mock-test/unit/generate'
    all_hashes = []
    attempts_hashes = []
    durations = []

    for i in range(attempts):
        payload = {'subject': subject, 'unit': unit}
        print(f'Attempt {i+1}/{attempts} -> POST {url} subject={subject} unit={unit}')
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

        if resp.status_code != 200 or not data.get('success', True):
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

    for i, hlist in enumerate(attempts_hashes):
        dup = len(hlist) - len(set(hlist))
        print(f' - Attempt {i+1} internal duplicates: {dup}')

    if duplicates_across == 0:
        print('\nAll questions across attempts are unique.')
    else:
        print('\nSome questions repeated across attempts.')

    if durations:
        idx = max(range(len(durations)), key=lambda k: durations[k])
        print(f'\nSlowest attempt: {idx+1} at {durations[idx]:.2f}s')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', default='http://127.0.0.1:8000')
    parser.add_argument('--subject', default='Physics')
    parser.add_argument('--unit', default='Kinematics')
    parser.add_argument('--attempts', type=int, default=5)
    args = parser.parse_args()

    token = get_token(args.url)
    if not token:
        print('Failed to obtain token; aborting.')
        sys.exit(1)
    print('Token obtained; running checks...')
    run_attempts(args.url, token, args.subject, args.unit, args.attempts)
