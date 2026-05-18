"""Simple in-memory session memory manager with windowing.

Provides a thread-safe dictionary-based session store. Each session stores
an ordered list of messages (dicts with role/text/timestamp). This is
intentionally lightweight and easy to replace with Redis or a DB later.
"""
from typing import List, Dict, Optional
from threading import Lock
from time import time
import uuid

_SESSIONS: Dict[str, List[Dict]] = {}
_LOCK = Lock()

# Default number of recent messages to keep when composing prompts
DEFAULT_WINDOW = 8


def create_session() -> str:
    sid = str(uuid.uuid4())
    with _LOCK:
        _SESSIONS[sid] = []
    return sid


def reset_session(session_id: str) -> bool:
    with _LOCK:
        if session_id in _SESSIONS:
            _SESSIONS[session_id] = []
            return True
    return False


def get_session(session_id: str) -> Optional[List[Dict]]:
    with _LOCK:
        return list(_SESSIONS.get(session_id, [])) if session_id in _SESSIONS else None


def add_message(session_id: str, role: str, text: str) -> None:
    msg = {'role': role, 'text': text, 'ts': int(time())}
    with _LOCK:
        if session_id not in _SESSIONS:
            _SESSIONS[session_id] = []
        _SESSIONS[session_id].append(msg)


def pop_window(session_id: str, window: int = DEFAULT_WINDOW) -> List[Dict]:
    """Return the last `window` messages for the session (copy)."""
    with _LOCK:
        msgs = _SESSIONS.get(session_id, [])
        return list(msgs[-window:])


def list_sessions() -> List[str]:
    with _LOCK:
        return list(_SESSIONS.keys())
