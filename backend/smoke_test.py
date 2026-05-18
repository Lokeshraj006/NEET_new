import asyncio
import app

async def test():
    try:
        res = await app.chat(app.Msg(message='Define photosynthesis', history=[]))
        print(res)
    except Exception as e:
        print(f'Error: {e}')

if __name__ == '__main__':
    asyncio.run(test())
