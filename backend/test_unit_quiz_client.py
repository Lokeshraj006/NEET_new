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
print('Using token:', token)

base = 'http://127.0.0.1:8000'
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

data = {'subject': 'Physics', 'unit': 'Physics and Measurement'}
resp = requests.post(f"{base}/mock-test/unit/generate", headers=headers, json=data, timeout=60)
print(resp.status_code)
print(resp.text)
