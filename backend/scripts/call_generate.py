import json
import urllib.request

url = 'http://127.0.0.1:8000/mock-test/generate'
body = {'count': 180, 'exclude_hashes': []}
req = urllib.request.Request(url, method='POST')
req.add_header('Content-Type', 'application/json')
try:
    resp = urllib.request.urlopen(req, data=json.dumps(body).encode('utf-8'), timeout=30)
    data = resp.read().decode('utf-8')
    print('Status:', resp.status)
    j = json.loads(data)
    qcount = len(j.get('questions') or [])
    print('Questions returned:', qcount)
    print('Sample item (first):')
    if qcount:
        print(json.dumps(j.get('questions')[0], ensure_ascii=False, indent=2)[:2000])
    else:
        print(data[:2000])
except Exception as e:
    print('Request failed:', e)
    try:
        import traceback
        traceback.print_exc()
    except Exception:
        pass
