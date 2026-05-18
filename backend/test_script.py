import asyncio
import app

async def main():
    await app.reindex()
    p = await app.chat(app.Msg(message='What is photosynthesis?', detailed=False))
    sid = p.get('session_id')
    o1 = await app.chat(app.Msg(message='State Ohm law', detailed=False, session_id=sid))
    o2 = await app.chat(app.Msg(message='State Ohm law', detailed=True, session_id=sid))
    print('P', p)
    print('O1', o1)
    print('O2', o2)

if __name__ == '__main__':
    asyncio.run(main())
