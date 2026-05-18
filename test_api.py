import requests
import json

url = "http://localhost:8000/chat"
headers = {"Content-Type": "application/json"}

# Test 1: NEET question (should get formatted answer)
payload1 = {"message": "explain snell's law", "session_id": "test1"}
print("TEST 1: NEET Question - 'explain snell's law'")
print("=" * 60)
try:
    r = requests.post(url, json=payload1, timeout=30)
    response = r.json()
    print(json.dumps(response, indent=2))
    if 'response' in response:
        print("\nFormatted Response:")
        print(response['response'])
except Exception as e:
    print(f"Error: {e}")

print("\n" + "=" * 60 + "\n")

# Test 2: Out-of-scope question (should get simple refusal)
payload2 = {"message": "how can I meet the chief minister", "session_id": "test2"}
print("TEST 2: Out-of-scope Question - 'how can I meet the chief minister'")
print("=" * 60)
try:
    r = requests.post(url, json=payload2, timeout=30)
    response = r.json()
    print(json.dumps(response, indent=2))
    if 'response' in response:
        print("\nFormatted Response:")
        print(response['response'])
except Exception as e:
    print(f"Error: {e}")

print("\n" + "=" * 60 + "\n")

# Test 3: Another NEET question
payload3 = {"message": "what is photosynthesis", "session_id": "test3"}
print("TEST 3: NEET Question - 'what is photosynthesis'")
print("=" * 60)
try:
    r = requests.post(url, json=payload3, timeout=30)
    response = r.json()
    print(json.dumps(response, indent=2))
    if 'response' in response:
        print("\nFormatted Response (first 500 chars):")
        print(response['response'][:500])
except Exception as e:
    print(f"Error: {e}")
