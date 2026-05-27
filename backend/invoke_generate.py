import asyncio
import sys
sys.path.insert(0, 'C:/Users/dines/Desktop/NEET')
from backend.neet_core import generate_mock_test, MockTestRequest

async def run():
    req = MockTestRequest(count=180)
    res = await generate_mock_test(req)
    import json
    print('keys:', list(res.keys()))
    print('questions:', len(res.get('questions', [])))
    if res.get('questions'):
        print(json.dumps(res['questions'][0], indent=2)[:1000])

if __name__ == '__main__':
    asyncio.run(run())
