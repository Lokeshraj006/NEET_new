import json
import time
import hmac
import hashlib
import base64
import urllib.request
import urllib.error

# Config
secret = b"neet_secret"
host = "http://127.0.0.1:8000"
set_id = 1

# Build JWT (HS256) manually
header = {"alg": "HS256", "typ": "JWT"}
payload = {"sub": "1", "email": "dev@local", "exp": int(time.time()) + 24 * 3600}

def b64url(inp: bytes) -> str:
    return base64.urlsafe_b64encode(inp).decode('ascii').rstrip('=')

header_b = json.dumps(header, separators=(',', ':')).encode('utf-8')
payload_b = json.dumps(payload, separators=(',', ':')).encode('utf-8')

msg = f"{b64url(header_b)}.{b64url(payload_b)}".encode('ascii')
sig = hmac.new(secret, msg, hashlib.sha256).digest()
token = f"{msg.decode('ascii')}.{b64url(sig)}"

print('Generated token:', token)

# POST to endpoint
url = f"{host}/mock-test/fixed-set/{set_id}"
req = urllib.request.Request(url, method='POST')
req.add_header('Authorization', f'Bearer {token}')
req.add_header('Content-Type', 'application/json')

try:
    with urllib.request.urlopen(req, timeout=20) as resp:
        body = resp.read().decode('utf-8')
        print('Status:', resp.status)
        print('Response body (truncated 2000 chars):')
        print(body[:2000])
except urllib.error.HTTPError as e:
    print('HTTP Error:', e.code, e.reason)
    try:
        print(e.read().decode('utf-8')[:2000])
    except Exception:
        pass
except Exception as exc:
    print('Request failed:', str(exc))
