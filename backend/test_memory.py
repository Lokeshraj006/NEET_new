import asyncio
import json
import os

import app


async def run_sequence():
    # start fresh
    res = await app.reindex()
    print('Reindex:', res)

    m1 = app.Msg(message='What is the brain?', history=[])
    r1 = await app.chat(m1)
    print('Q1 ->', r1)

    sid = r1.get('session_id')
    m2 = app.Msg(message='Explain its parts', history=[], session_id=sid)
    r2 = await app.chat(m2)
    print('Q2 ->', r2)

    m3 = app.Msg(message="What are its functions?", history=[], session_id=sid)
    r3 = await app.chat(m3)
    print('Q3 ->', r3)


if __name__ == '__main__':
    asyncio.run(run_sequence())
