import os
import json
from datetime import datetime, timedelta
import requests
from jose import jwt

JWT_SECRET = os.environ.get('JWT_SECRET', 'neet_super_secret_key_2024')
JWT_ALG = 'HS256'

# create a token for user_id 1
payload = {'sub': '1', 'email': 'tester@example.com', 'exp': datetime.utcnow() + timedelta(hours=2)}
token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)

base = 'http://127.0.0.1:8000'
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

data = {'subject': 'Physics', 'unit': 'Physics and Measurement'}
resp = requests.post(f"{base}/mock-test/unit/generate", headers=headers, json=data, timeout=60)
print('generate status', resp.status_code)
resp_json = resp.json()
session_id = resp_json.get('session_id')
questions = resp_json.get('questions', [])
print('session', session_id, 'questions', len(questions))
answers = [0 for _ in questions]
submit_resp = requests.post(f"{base}/mock-test/unit/submit", headers=headers, json={'session_id': session_id, 'answers': answers, 'marked': []}, timeout=60)
print('submit status', submit_resp.status_code)
print(submit_resp.text)
