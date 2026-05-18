import asyncio
import app

async def main():
    print("--- Reindexing ---")
    await app.reindex()
    
    print("--- Chat: Photosynthesis ---")
    result1 = await app.chat(app.Msg(message="Define photosynthesis"))
    print(result1)
    
    print("--- Chat: Osmosis ---")
    result2 = await app.chat(app.Msg(message="What is osmosis?"))
    print(result2)

if __name__ == "__main__":
    asyncio.run(main())
