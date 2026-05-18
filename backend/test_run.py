import sys, asyncio, os

sys.path.insert(0, os.path.join(os.getcwd(), 'backend'))

# Keep MISTRAL_API_KEY if the caller set it. Set TEST_DISABLE_MISTRAL_API_KEY=1
# to force the local fallback path during tests.
if os.environ.get('TEST_DISABLE_MISTRAL_API_KEY') == '1':
    os.environ.pop('MISTRAL_API_KEY', None)

from app import Msg, chat

async def run_test():
    m = Msg(message='What happens to the speed of light when passing from air into glass?')
    res = await chat(m)
    print('Response:')
    print(res)

if __name__ == '__main__':
    asyncio.run(run_test())
