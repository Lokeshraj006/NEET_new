import requests, json
url = "http://127.0.0.1:8000/mock-test/unit/generate"
payload = {"subject":"Physics","unit":"Kinematics"}
try:
    r = requests.post(url, json=payload, timeout=30)
    print(r.status_code)
    print(r.text[:4000])
except Exception as e:
    print("EXC:", repr(e))
