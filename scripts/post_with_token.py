from jose import jwt
import requests

JWT_SECRET = 'neet_super_secret_key_2024'
JWT_ALGORITHM = 'HS256'

def make_token(user_id=1):
    payload = {"sub": str(user_id)}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

if __name__ == '__main__':
    token = make_token(1)
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    url = "http://127.0.0.1:8000/mock-test/unit/generate"
    payload = {"subject": "Physics", "unit": "Kinematics"}
    try:
        r = requests.post(url, json=payload, headers=headers, timeout=30)
        print(r.status_code)
        print(r.text[:4000])
    except Exception as e:
        print("EXC:", repr(e))
