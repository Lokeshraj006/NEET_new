NEET Chatbot backend

Run the FastAPI backend locally for development. This backend uses a lightweight RAG pipeline over NEET notes and (optionally) an external LLM via the Mistel API.

Install dependencies (recommended in a venv):

```
python -m venv .venv
source .venv/bin/activate    # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
```

Run the server:

```
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

Notes:
- The server reads docs from `backend/docs/*.txt` and retrieves relevant passages for each question.
- To enable an external LLM (Mistel), set the `MISTEL_API_KEY` environment variable (do NOT commit your key). Optionally set `MISTEL_API_URL` if your provider uses a non-default endpoint.
- If the Mistel key is missing or the API call fails, the server falls back to deterministic local NEET answers so the app still works.
- The backend uses a PageIndex lexical retrieval over `backend/docs/*.txt`. Direct NEET definition questions like `osmosis` and `photosynthesis` are answered deterministically when retrieval is noisy.
- The assistant refuses non-NEET questions.

PDF ingestion:
- Place your NEET PDFs into `backend/pdfs/` and run:

```
python ingest_pdfs.py
```

- That will extract text to `backend/docs/*.txt`. After adding or updating docs, call the reindex endpoint to rebuild the search index:

```
curl -X POST http://localhost:8000/admin/reindex
```

If you change the PDF set, re-run ingestion and then call `/admin/reindex` again so the page index stays in sync.

Session memory
---------------

This backend supports lightweight in-memory session memory to maintain conversational context across messages.

- The `/chat` endpoint now accepts an optional `session_id` field. If omitted, the backend creates a new session and returns `session_id` in the response.
- Session messages (user and assistant) are stored in memory and a recent window is included in prompt composition and retrieval.
- To reset a session use `POST /session/reset` with JSON `{ "session_id": "<id>" }`.

Example `/chat` request (create/continue session):

```
POST /chat
Content-Type: application/json

{
	"message": "What is the brain?",
	"history": [],
	"session_id": null,
	"detailed": false
}
```

Response includes `session_id`:

```
{
	"reply": "...",
	"sources": ["NEET_Syllabus.txt"],
	"session_id": "<uuid>",
	"detailed": false
}
```

Follow-up example (use same `session_id`):

```
POST /chat
Content-Type: application/json

{
	"message": "Explain its parts",
	"history": [],
	"session_id": "<uuid>",
	"detailed": false
}
```

Concise vs detailed mode:
- `detailed: false` (default): concise revision-friendly response (about 5-6 lines).
- `detailed: true`: expanded explanation with more depth.
- For physics/chemistry queries, relevant formulas/equations are included clearly when applicable.

Notes:
- Memory is in-process and will be lost when the server restarts. The code is modular and can be swapped to Redis or a database by replacing `backend/memory.py`.
- The backend keeps a recent window of messages to avoid prompt size blowup. This window is configurable in `memory.DEFAULT_WINDOW`.

Environment example (PowerShell):

```
$Env:MISTEL_API_KEY = 'your_mistel_key_here'
```

The Flutter app posts chat messages to `/chat`. Responses include a `reply` plus a `sources` list of text files used by the retriever.
