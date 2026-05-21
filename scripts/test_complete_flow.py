import requests
import random
import sys

base = 'http://127.0.0.1:8000'
email = f"testuser_{random.randint(100000, 999999)}@example.com"
password = "password123"
name = "Test Flow User"

print(f"Registering user with email: {email}")
reg_data = {"name": name, "email": email, "password": password}
r = requests.post(f"{base}/register", json=reg_data, timeout=10)
print("Register Status:", r.status_code)
if r.status_code != 200:
    print("Register Error:", r.text)
    sys.exit(1)

reg_json = r.json()
token = reg_json.get("token")
print("Token received:", token[:20] + "...")

# Verify using token on fixed set endpoint
headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
print("Calling fixed set endpoint...")
r_set = requests.post(f"{base}/mock-test/fixed-set/1", headers=headers, json={}, timeout=120)
print("Fixed Set Status:", r_set.status_code)
print("Fixed Set Response:", r_set.text[:300])

# Verify on unit generate endpoint
print("Calling unit generate endpoint...")
r_unit = requests.post(f"{base}/mock-test/unit/generate", headers=headers, json={"subject": "Physics", "unit": "Physics and Measurement"}, timeout=120)
print("Unit Generate Status:", r_unit.status_code)
print("Unit Generate Response:", r_unit.text[:300])
