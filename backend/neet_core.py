from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import json
import hashlib
from typing import List, Dict, Optional, Tuple
import os
import requests
import re
import time
import traceback

try:
    from . import memory as session_memory
    from .neet_config import (
        ANSWER_STYLE_GUIDE,
        CONCISE_RESPONSE_GUIDE,
        CONCEPT_GLOSSARY,
        DETAILED_RESPONSE_GUIDE,
        FALLBACK_TOPIC_HINTS,
        FORMULA_HINTS,
        FORMULA_RELEVANCE_HINTS,
        IN_SCOPE_HINTS,
        MISTRAL_MAX_TOKENS,
        NEET_REFUSAL,
        NEET_TOPICS,
        NON_NEET_MEDIA_HINTS,
        NON_NEET_SOCIAL_HINTS,
        PHYSICS_CHEM_TRIGGERS,
        PRIMARY_SUBJECTS,
        STOPWORDS,
        SYSTEM_PROMPT_LINES,
    )

    from .pageindex import get_page_index
    from . import auth as auth_router
    from . import mock_test_api
    from . import streak_api
except ImportError:
    import memory as session_memory
    from neet_config import (
        ANSWER_STYLE_GUIDE,
        CONCISE_RESPONSE_GUIDE,
        CONCEPT_GLOSSARY,
        DETAILED_RESPONSE_GUIDE,
        FALLBACK_TOPIC_HINTS,
        FORMULA_HINTS,
        FORMULA_RELEVANCE_HINTS,
        IN_SCOPE_HINTS,
        MISTRAL_MAX_TOKENS,
        NEET_REFUSAL,
        NEET_TOPICS,
        NON_NEET_MEDIA_HINTS,
        NON_NEET_SOCIAL_HINTS,
        PHYSICS_CHEM_TRIGGERS,
        PRIMARY_SUBJECTS,
        STOPWORDS,
        SYSTEM_PROMPT_LINES,
    )

    from pageindex import get_page_index
    import auth as auth_router
    import mock_test_api
    import streak_api
PAGE_INDEX = get_page_index()
RAG_AVAILABLE = False
_PAGE_INDEX_READY = False

app = FastAPI(title="NEET Chatbot API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router)
app.include_router(mock_test_api.router)
app.include_router(streak_api.router)


@app.get('/health')
async def health():
    return {'status': 'OK', 'message': 'Backend is running'}


class Msg(BaseModel):
    message: str
    history: List[Dict] = Field(default_factory=list)
    session_id: Optional[str] = None
    detailed: bool = False


class MockTestRequest(BaseModel):
    session_id: Optional[str] = None
    count: int = 10
    exclude_hashes: List[str] = Field(default_factory=list)


def load_knowledge_docs():
    docs = []
    base = os.path.join(os.path.dirname(__file__), 'docs')
    if not os.path.exists(base):
        return docs
    for fn in os.listdir(base):
        if fn.endswith('.txt'):
            path = os.path.join(base, fn)
            with open(path, 'r', encoding='utf-8') as f:
                docs.append({'source': fn, 'text': f.read()})
    return docs


def build_doc_chunks():
    """Return the current document list as retrieval chunks.

    The admin reindex endpoint expects a chunk list, and the existing
    knowledge loader already returns the document payloads needed for it.
    """
    return load_knowledge_docs()


DOCS = load_knowledge_docs()


def _ensure_page_index_ready() -> None:
    global _PAGE_INDEX_READY
    if _PAGE_INDEX_READY:
        return
    try:
        PAGE_INDEX.build_index(docs_dir=os.path.join(os.path.dirname(__file__), 'docs'))
        _PAGE_INDEX_READY = True
    except Exception:
        _PAGE_INDEX_READY = False


def _page_index_has_signal(query: str, min_score: float = 1.0) -> bool:
    _ensure_page_index_ready()
    if not _PAGE_INDEX_READY:
        return False
    try:
        hits = PAGE_INDEX.query(query, k=1)
    except Exception:
        return False
    if not hits:
        return False
    return float(hits[0].get('score', 0.0)) >= float(min_score)


def _tokens(text: str):
    return [t for t in re.findall(r'[a-zA-Z]{3,}', text.lower()) if t not in STOPWORDS]


def is_neet_question(query: str) -> bool:
    query_lower = query.lower()
    tokens = set(_tokens(query))
    if any(trigger in tokens for trigger in NON_NEET_SOCIAL_HINTS) and 'you' in tokens:
        return False
    if any(trigger in query_lower for trigger in NON_NEET_MEDIA_HINTS):
        return False
    if tokens.intersection(PRIMARY_SUBJECTS):
        return True
    if tokens.intersection(NEET_TOPICS | IN_SCOPE_HINTS):
        return True
    if tokens and _page_index_has_signal(query):
        return True
    return len(tokens) > 1


@app.post('/admin/reindex')
async def reindex():
    """Reload text docs from `backend/docs/` and rebuild retrieval chunks.
    Useful after adding new .txt files (e.g., from `ingest_pdfs.py`)."""
    global DOCS, DOC_CHUNKS
    DOCS = load_knowledge_docs()
    DOC_CHUNKS = load_knowledge_docs()
    result = {'status': 'ok', 'docs': len(DOCS), 'chunks': len(DOC_CHUNKS)}
    # rebuild page index
    global _PAGE_INDEX_READY
    try:
        r = PAGE_INDEX.build_index(docs_dir=os.path.join(os.path.dirname(__file__), 'docs'))
        _PAGE_INDEX_READY = True
        result['pageindex_docs'] = r.get('docs', 0)
    except Exception as e:
        _PAGE_INDEX_READY = False
        result['pageindex_error'] = str(e)[:300]
    try:
        result['sessions'] = len(session_memory.list_sessions())
    except Exception:
        pass
    return result


def simple_rag_retrieve(query: str, k: int = 3):
    # Use page index lexical retrieval for compatibility with prior behaviour.
    _ensure_page_index_ready()
    try:
        return PAGE_INDEX.query(query, k=k)
    except Exception:
        return []


def get_retrieved(query: str, k: int = 3):
    lexical_hits = simple_rag_retrieve(query, k=max(6, k))
    vector_hits = []

    q_tokens = set(_tokens(query))
    combined = {}

    def lexical_score(text: str) -> float:
        text = str(text).lower()
        t_tokens = set(_tokens(text))
        overlap = len(q_tokens.intersection(t_tokens))
        phrase_bonus = 0.0
        for token in q_tokens:
            if token and token in text:
                phrase_bonus += 0.25
        return float(overlap) + phrase_bonus

    for item in lexical_hits:
        key = (item.get('source', ''), item.get('text', ''))
        combined[key] = {
            'source': item.get('source', ''),
            'text': item.get('text', ''),
            'score': lexical_score(item.get('text', '')) + 2.0,
        }

    for item in vector_hits:
        key = (item.get('source', ''), item.get('text', ''))
        vec_bonus = max(0.0, 1.0 - float(item.get('score', 0.0)))
        item_score = lexical_score(item.get('text', '')) + vec_bonus
        if key not in combined or item_score > combined[key]['score']:
            combined[key] = {
                'source': item.get('source', ''),
                'text': item.get('text', ''),
                'score': item_score,
            }

    ranked = sorted(combined.values(), key=lambda d: d.get('score', 0.0), reverse=True)
    if ranked:
        return ranked[:k]
    return simple_rag_retrieve(query, k=k)


def _compose_retrieval_query(query: str, session_history: List[Dict], window: int = 4) -> str:
    parts = [query.strip()]
    if session_history:
        user_texts = [m['text'] for m in session_history if m.get('role') == 'user']
        recents = user_texts[-window:]
        if recents:
            parts.append(' '.join(recents))
    return ' '.join(parts)


def _ensure_session(msg: Msg) -> Tuple[str, List[Dict]]:
    sid = msg.session_id or ''
    if not sid:
        sid = session_memory.create_session()
    history = session_memory.get_session(sid)
    if history is None:
        session_memory.add_message(sid, 'system', 'new session created')
        history = session_memory.get_session(sid) or []
    windowed = session_memory.pop_window(sid, window=8)
    return sid, windowed


def format_history(history: List[Dict], max_turns: int = 6):
    if not history:
        return []

    formatted = []
    for item in history[-max_turns:]:
        role = str(item.get('role', '')).lower()
        text = str(item.get('text', '')).strip()
        if not text:
            continue
        if role in {'user', 'model', 'assistant', 'bot'}:
            formatted.append(f"{role.upper()}: {text}")
    return formatted


def _is_physics_chem_query(query: str) -> bool:
    q = query.lower()
    return any(re.search(rf'\b{re.escape(t)}\b', q) for t in PHYSICS_CHEM_TRIGGERS)


def _formula_hint(query: str) -> str:
    q = query.lower()
    for key, formula in FORMULA_HINTS.items():
        if key in q:
            return formula
    return ''


def _formula_relevant(query: str) -> bool:
    q = query.lower()
    return _is_physics_chem_query(query) or any(hint in q for hint in FORMULA_RELEVANCE_HINTS)


def _remove_irrelevant_formula_lines(text: str, query: str) -> str:
    if _formula_relevant(query):
        return text
    lines = []
    for line in text.split('\n'):
        if re.match(r'^\s*[-•]?\s*Formula\s*:', line, flags=re.I):
            continue
        cleaned = re.sub(r'\bFormula\s*:\s*[^\n]*', '', line, flags=re.I).strip()
        cleaned = re.sub(r'\s{2,}', ' ', cleaned).strip(' -:;,.')
        if cleaned:
            lines.append(cleaned)
    return '\n'.join(lines).strip()


def _extract_concept_topic(query: str) -> str:
    compact = re.sub(r'[^a-z ]+', ' ', query.lower())
    compact = re.sub(r'\s+', ' ', compact).strip()
    prefixes = ['what is ', 'what are ', 'define ', 'explain ', 'describe ', 'tell me about ']
    for prefix in prefixes:
        if compact.startswith(prefix):
            topic = compact[len(prefix):].strip()
            topic = re.sub(r'^(the|a|an)\s+', '', topic)
            return topic
    return compact


def build_prompt(query: str, history: List[Dict], retrieved: List[Dict], detailed: bool = False):
    history_lines = format_history(history)
    context_lines = []
    for item in retrieved[:4]:
        source = item.get('source', 'source')
        text = str(item.get('text', '')).strip()
        if text:
            context_lines.append(f"- [{source}] {text}")

    response_guide = [
        'RESPONSE FORMAT:',
        *(DETAILED_RESPONSE_GUIDE if detailed else CONCISE_RESPONSE_GUIDE),
    ]

    sections = [
        'SYSTEM:',
        *SYSTEM_PROMPT_LINES,
        '',
        *response_guide,
        '',
        'RETRIEVED CONTEXT:',
        *(context_lines if context_lines else ['- None']),
        '',
        'CHAT HISTORY:',
        *(history_lines if history_lines else ['- None']),
        '',
        'QUESTION:',
        query.strip(),
        '',
        'FINAL ANSWER:',
    ]
    return '\n'.join(sections)


def _strip_code_fences(text: str) -> str:
    text = text.strip()
    if text.startswith('```') and text.endswith('```'):
        text = text[3:-3].strip()
    return text


def _repair_mojibake(text: str) -> str:
    try:
        candidate = text.encode('latin1').decode('utf-8')
        if candidate and candidate.count('\uFFFD') <= text.count('\uFFFD'):
            return candidate
    except UnicodeError:
        pass
    return text


def _normalize_formula_line(value: str) -> str:
    replacements = {
        'θ': 'theta', 'Î¸': 'theta', 'π': 'pi', 'μ': 'mu', 'λ': 'lambda', 'Δ': 'Delta',
        '×': '*', '÷': '/', '−': '-', '–': '-', '—': '-', '∝': ' proportional to ', '∞': 'infinity',
        '≈': '~=', '≠': '!=', '≤': '<=', '≥': '>=', '√': 'sqrt', '·': '*', '₀': '0', '₁': '1',
        '₂': '2', '₃': '3', '₄': '4', '₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9',
        '⁰': '^0', '¹': '^1', '²': '^2', '³': '^3', '⁴': '^4', '⁵': '^5', '⁶': '^6', '⁷': '^7',
        '⁸': '^8', '⁹': '^9', 'âˆ’': '-', 'â‰¤': '<=', 'â‰¥': '>=', 'â‰ ': '!=', 'âˆš': 'sqrt',
        'â‚': '', 'â': '', '‚': '', '\uFFFD': '',
    }
    for old, new in replacements.items():
        value = value.replace(old, new)
    value = re.sub(r'\s+', ' ', value).strip()
    probe = re.sub(r'[^a-z0-9=+\-*/()\s]', '', value.lower())
    if re.search(r'\bn\s*sin\s*i\s*=\s*n\s*sin\s*r\b', probe):
        return 'n1 sin i1 = n2 sin r2'
    return value


def _is_out_of_scope_reply(text: str) -> bool:
    compact = re.sub(r'\s+', ' ', text.lower()).strip()
    checks = [
        'outside neet scope', 'outside neet', 'out of neet', 'not in neet', 'non-neet',
        'i can only help with neet', 'neet-focused assistant', 'this is outside neet',
    ]
    return any(marker in compact for marker in checks)


def format_mistral_response(text: str, query: str, detailed: bool = False) -> str:
    text = _strip_code_fences(text)
    text = _repair_mojibake(text)
    text = text.replace('\r\n', '\n').replace('\r', '\n').strip()
    text = re.sub(r'<[^>]+>', '', text)
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    text = re.sub(r'`([^`]*)`', r'\1', text)
    # Strip ** bold markers — no highlighting needed
    text = re.sub(r'\*\*(.+?)\*\*', r'\1', text, flags=re.S)
    text = re.sub(r'__(.+?)__', r'\1', text, flags=re.S)
    text = re.sub(r'^#+\s*', '', text, flags=re.M)
    text = text.replace('â€¢', '•').replace('â€"', '-').replace('â€"', '-').replace('â€™', "'").replace('â€˜', "'")
    text = text.replace('â€œ', '"').replace('Â', '').replace('\uFFFD', '')
    text = text.replace('θ', 'theta').replace('Î¸', 'theta')
    text = text.replace('₁', '1').replace('₂', '2').replace('₃', '3').replace('₄', '4')
    text = '\n'.join(line for line in text.split('\n') if not re.match(r'^[\*\-•\s]{2,}$', line.strip()))
    if not text.strip():
        return 'No response generated.'
    if _is_out_of_scope_reply(text):
        return NEET_REFUSAL

    heading_only_re = re.compile(r'^(Definition|Structure|Function/Mechanism|Function|Mechanism|Key Points|Key Point|Key Poin|Summary|Formula)\s*$', re.I)
    heading_inline_re = re.compile(r'^(Definition|Structure|Function/Mechanism|Function|Mechanism|Key Points|Key Point|Key Poin|Summary|Formula)\s*:\s*(.*)$', re.I)
    alias = {
        'definition': 'Definition', 'structure': 'Structure', 'function': 'Function/Mechanism',
        'mechanism': 'Function/Mechanism', 'function/mechanism': 'Function/Mechanism',
        'key points': 'Key Points', 'key point': 'Key Points', 'key poin': 'Key Points',
        'summary': 'Summary', 'formula': 'Formula',
    }
    sections: Dict[str, List[str]] = {}
    current = None

    for raw in text.split('\n'):
        line = raw.strip()
        if not line:
            continue
        match = heading_inline_re.match(line) or heading_only_re.match(line)
        if match:
            current = match.group(1).strip().lower()
            rest = (match.group(2) if len(match.groups()) > 1 and match.group(2) else '').strip()
            if rest:
                sections.setdefault(current, []).append(rest)
            continue
        if current:
            sections.setdefault(current, []).append(line)
        else:
            sections.setdefault('preamble', []).append(line)

    if 'function' in sections and 'function/mechanism' not in sections:
        sections['function/mechanism'] = sections['function']
    if 'mechanism' in sections and 'function/mechanism' not in sections:
        sections['function/mechanism'] = sections['mechanism']

    def clean_line(label: str, value: str) -> str:
        value = value.strip()
        value = re.sub(r'^#+\s*', '', value)
        value = re.sub(r'^(definition|structure|function\/mechanism|function|mechanism|key points|key point|key poin|summary|formula)\s*[:\-.)]*\s*', '', value, flags=re.I)
        value = re.sub(r'^(human brain structure|brain structure)\s*$', '', value, flags=re.I)
        if label == 'formula':
            value = _normalize_formula_line(value)
        value = re.sub(r'\s+', ' ', value).strip()
        value = re.sub(r'\.\.\.\s*$', '.', value)
        if value.lower() in {'definition', 'structure', 'function/mechanism', 'function', 'mechanism', 'key points', 'key point', 'key poin', 'summary', 'formula'}:
            return ''
        if label == 'formula':
            if value and not re.search(r'[.!?]$', value):
                value += '.'
            return value
        if label == 'definition' and len(value.split()) <= 4 and not re.search(r'[\.\!?]$', value):
            return ''
        if value and not re.search(r'[\.\!?]$', value):
            value += '.'
        return value

    def clean_bullet_body(value: str) -> str:
        value = re.sub(r'^[•\-\*\s]+', '', value).strip()
        return clean_line('key points', value)

    out_lines: List[str] = []
    order = ['definition', 'structure', 'function/mechanism', 'key points', 'summary']
    if _formula_relevant(query):
        order.append('formula')

    for label in order:
        if label not in sections:
            continue
        values = [v for v in sections[label] if v.strip()]
        if label == 'key points':
            values = values[:3 if detailed else 2]

        cleaned_values: List[str] = []
        for value in values:
            if re.match(r'^[•\-\*]\s*', value):
                bullet_body = clean_bullet_body(value)
                if bullet_body:
                    cleaned_values.append(f'• {bullet_body}')
            else:
                cleaned_value = clean_line(label, value)
                if cleaned_value:
                    cleaned_values.append(cleaned_value)

        if not cleaned_values:
            continue

        out_lines.append(alias[label])
        out_lines.extend(cleaned_values)
        out_lines.append('')

    if out_lines:
        preamble_lines = [l for l in sections.get('preamble', []) if l.strip()]
        preamble_text = ' '.join(preamble_lines).strip()

        # If AI put the direct answer inside Definition instead of before it,
        # pull the first sentence out as the preamble
        if not preamble_text and 'definition' in sections:
            def_lines = [l for l in sections['definition'] if l.strip()]
            if def_lines:
                preamble_text = def_lines[0]
                sections['definition'] = def_lines[1:]
                # Rebuild out_lines without the first definition line
                out_lines = []
                for label in order:
                    if label not in sections:
                        continue
                    values = [v for v in sections[label] if v.strip()]
                    if not values:
                        continue
                    if label == 'key points':
                        values = values[:3 if detailed else 2]
                    cleaned_values = []
                    for value in values:
                        if re.match(r'^[•\-\*]\s*', value):
                            b = clean_bullet_body(value)
                            if b:
                                cleaned_values.append(f'• {b}')
                        else:
                            cv = clean_line(label, value)
                            if cv:
                                cleaned_values.append(cv)
                    if cleaned_values:
                        out_lines.append(alias[label])
                        out_lines.extend(cleaned_values)
                        out_lines.append('')

        result_parts = []
        if preamble_text:
            result_parts.append(preamble_text)
            result_parts.append('')
        result_parts.extend(out_lines)
        result = '\n'.join(result_parts).strip()
        result = re.sub(r'\n{3,}', '\n\n', result)
        return _remove_irrelevant_formula_lines(result, query)

    sentences = [s.strip() for s in re.split(r'(?<=[\.\!?])\s+', text) if s.strip()]
    if not sentences:
        return 'No response generated.'

    fallback_lines = ['Definition', sentences[0].rstrip('.') + '.']
    if len(sentences) > 1:
        fallback_lines.extend(['', 'Function/Mechanism', sentences[1].rstrip('.') + '.'])
    if len(sentences) > 2:
        fallback_lines.extend(['', 'Key Points'])
        for sentence in sentences[2:4]:
            fallback_lines.append(f'• {sentence.rstrip(".")}.')

    result = '\n'.join(fallback_lines).strip()
    return _remove_irrelevant_formula_lines(result, query)


def safety_gate(query: str) -> str:
    q = query.lower().strip()
    if not q:
        return 'Empty message'
    if len(q) > 2500:
        return 'Query too long'
    forbidden = ['how to hack', 'make bomb', 'suicide', 'kill yourself', 'weapon', 'explosive']
    if any(item in q for item in forbidden):
        return 'I can only help with NEET physics, chemistry, and biology questions.'
    return ''


def synthesize_answer(query: str, history: List[Dict], retrieved: List[Dict], detailed: bool = False):
    concept_hint = get_concept_hint(query)
    if concept_hint and is_neet_question(query) and not detailed:
        return format_mistral_response(concept_hint, query=query, detailed=False)

    api_key = get_mistral_api_key()
    prompt = build_prompt(query, history, retrieved, detailed=detailed)

    if api_key:
        try:
            raw = call_mistral_generate(api_key, prompt)
            return format_mistral_response(raw, query=query, detailed=detailed)
        except Exception as e:
            print(f"[DEBUG] Mistral API failed: {type(e).__name__}: {str(e)[:300]}")
            pass
    else:
        print("[DEBUG] No MISTRAL_API_KEY found, using local fallback")

    if retrieved:
        reply = retrieved[0]['text'].strip()
        if len(retrieved) > 1:
            reply = f"{reply} {retrieved[1]['text'].strip()}"
        return format_mistral_response(reply, query=query, detailed=detailed)
    return fallback_neet_answer(query)


def fallback_neet_answer(query: str) -> str:
    q = query.lower()
    compact = _extract_concept_topic(query)

    for key, answer in CONCEPT_GLOSSARY.items():
        if key in compact:
            return answer

    for key, answer in FALLBACK_TOPIC_HINTS.items():
        if key in q or key in compact:
            return answer

    if is_neet_question(query):
        return 'Short answer: this is a NEET topic. Ask the exact term or concept, and I will give a brief definition or steps.'

    return NEET_REFUSAL


def get_concept_hint(query: str) -> str:
    compact = _extract_concept_topic(query)
    if compact.startswith('bio chemistry'):
        return CONCEPT_GLOSSARY['biochemistry']
    if compact.startswith('bio molecule'):
        return CONCEPT_GLOSSARY['biomolecule']
    if compact in CONCEPT_GLOSSARY:
        return CONCEPT_GLOSSARY[compact]

    return ''


def get_mistral_api_key():
    return os.environ.get('MISTRAL_API_KEY', '').strip()


def _mistral_model_candidates() -> List[str]:
    primary = os.environ.get('MISTRAL_MODEL', 'mistral-small-latest').strip() or 'mistral-small-latest'
    fallback_raw = os.environ.get('MISTRAL_FALLBACK_MODELS', '').strip()
    fallback = [part.strip() for part in fallback_raw.split('||') if part.strip()]
    models: List[str] = []
    for item in [primary, *fallback]:
        if item not in models:
            models.append(item)
    return models


def _parse_retry_attempts() -> int:
    raw = os.environ.get('MISTRAL_RETRY_ATTEMPTS', '2').strip()
    try:
        value = int(raw)
    except ValueError:
        value = 2
    return max(1, min(value, 4))


def call_mistral_generate(api_key: str, prompt: str) -> str:
    if not api_key:
        raise RuntimeError('Missing MISTRAL_API_KEY')

    base_url = os.environ.get('MISTRAL_API_URL', 'https://api.mistral.ai/v1/chat/completions')
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json'
    }
    models = _mistral_model_candidates()
    retry_attempts = _parse_retry_attempts()
    last_error = 'unknown_error'

    for model_name in models:
        for attempt in range(retry_attempts):
            body = {
                'model': model_name,
                'messages': [
                    {'role': 'user', 'content': prompt}
                ],
                'temperature': 0.2,
                'max_tokens': MISTRAL_MAX_TOKENS
            }

            try:
                resp = requests.post(base_url, headers=headers, json=body, timeout=60)
                if resp.status_code == 200:
                    data = resp.json()
                    if isinstance(data, dict):
                        for key in ('text', 'response', 'generated_text', 'output'):
                            if key in data and isinstance(data[key], str):
                                text = data[key].strip()
                                return text
                        if 'choices' in data and isinstance(data['choices'], list) and data['choices']:
                            c0 = data['choices'][0]
                            if isinstance(c0, dict):
                                message = c0.get('message')
                                if isinstance(message, dict):
                                    content = message.get('content')
                                    if isinstance(content, str) and content.strip():
                                        txt = content.strip()
                                        return txt

                        if 'choices' in data and isinstance(data['choices'], list) and data['choices']:
                            c0 = data['choices'][0]
                            if isinstance(c0, dict):
                                txt = c0.get('text') or c0.get('message') or c0.get('output')
                                if isinstance(txt, str):
                                    txt = txt.strip()
                                    return txt
                    return resp.text.strip()

                body_preview = resp.text[:200]
                is_capacity_429 = (
                    resp.status_code == 429
                    and (
                        'service_tier_capacity_exceeded' in body_preview
                        or 'capacity exceeded' in body_preview.lower()
                    )
                )
                last_error = f'{resp.status_code} {body_preview}'
                if is_capacity_429 and attempt + 1 < retry_attempts:
                    time.sleep(0.8 * (attempt + 1))
                    continue

                if is_capacity_429:
                    break

                raise RuntimeError(f'Mistral API failed: {last_error}')
            except Exception as e:
                last_error = f'{type(e).__name__}: {str(e)[:300]}'
                if attempt + 1 < retry_attempts:
                    time.sleep(0.8 * (attempt + 1))
                    continue
                break

    raise RuntimeError(f'Mistral API unavailable after retries/models: {last_error}')


def build_answer_payload(query: str, history: List[Dict], retrieved: List[Dict], reply: str):
    sources = []
    seen = set()
    for item in retrieved:
        source = str(item.get('source', '')).strip()
        if source and source not in seen:
            seen.add(source)
            sources.append(source)

    response = {
        'reply': reply,
        'sources': sources,
    }
    return response


def _question_hash(text: str) -> str:
    return hashlib.sha1(text.strip().lower().encode('utf-8')).hexdigest()[:12]


def _mock_prompt(contexts: List[Dict], count: int, exclude_hashes: List[str]) -> str:
    context_lines = []
    for item in contexts[:12]:
        source = item.get('source', 'source')
        text = str(item.get('text', '')).strip().replace('\n', ' ')
        if text:
            context_lines.append(f'- [{source}] {text[:240]}')
    return (
        'Generate valid JSON only. Return an array of NEET MCQs with keys '
        '[subject, unit, question, options, answer_index, explanation]. '
        f'Create {count} unique questions across Physics, Chemistry, and Biology. '
        f'Avoid repeating these question hashes: {exclude_hashes}. '
        'Each options list must contain exactly 4 strings and answer_index must be 0-3. '\
        'Use the following PDF-derived context:\n' + '\n'.join(context_lines)
    )


def _parse_question_list(raw: str) -> List[Dict]:
    raw = _strip_code_fences(raw)
    start = raw.find('[')
    end = raw.rfind(']')
    if start >= 0 and end > start:
        raw = raw[start:end + 1]
    data = json.loads(raw)
    if isinstance(data, dict):
        data = data.get('questions', [])
    if not isinstance(data, list):
        return []
    cleaned = []
    seen = set()
    for item in data:
        if not isinstance(item, dict):
            continue
        question = str(item.get('question', '')).strip()
        options = item.get('options', [])
        if not question or not isinstance(options, list) or len(options) != 4:
            continue
        answer_index = item.get('answer_index', 0)
        try:
            answer_index = int(answer_index)
        except Exception:
            answer_index = 0
        answer_index = max(0, min(3, answer_index))
        fingerprint = _question_hash(question)
        if fingerprint in seen:
            continue
        seen.add(fingerprint)
        cleaned.append({
            'subject': str(item.get('subject', 'NEET')).strip() or 'NEET',
            'unit': str(item.get('unit', '')).strip(),
            'question': question,
            'options': [str(opt).strip() for opt in options[:4]],
            'answer_index': answer_index,
            'explanation': str(item.get('explanation', '')).strip(),
            'hash': fingerprint,
        })
    return cleaned


def _fallback_mock_questions(count: int, exclude_hashes: List[str]) -> List[Dict]:
    retrieved = get_retrieved('NEET physics chemistry biology pdf notes', k=max(10, count))
    if not retrieved:
        retrieved = [{'source': 'NEET', 'text': 'NEET full syllabus revision.'}]
    items = []
    used = set(exclude_hashes)
    for idx in range(count):
        item = retrieved[idx % len(retrieved)]
        unit = str(item.get('source', 'NEET concept')).replace('.txt', '').replace('_', ' ').strip()
        question = f'Which NEET concept is most closely related to {unit}?' 
        fingerprint = _question_hash(question)
        if fingerprint in used:
            continue
        used.add(fingerprint)
        distractors = [
            'General revision',
            'Mixed practice',
            'Concept linking',
            'Chapter recap',
        ]
        options = [unit, *distractors[:3]]
        items.append({
            'subject': 'NEET',
            'unit': unit,
            'question': question,
            'options': options,
            'answer_index': 0,
            'explanation': str(item.get('text', ''))[:160],
            'hash': fingerprint,
        })
        if len(items) >= count:
            break
    return items


@app.post('/mock-test/generate')
async def generate_mock_test(req: MockTestRequest):
    # Allow up to 180 questions (full mock) — prefer pipeline outputs if present
    count = max(1, min(int(req.count or 180), 180))
    exclude_hashes = [str(x) for x in req.exclude_hashes if str(x).strip()]
    query = 'Physics Chemistry Biology NEET full syllabus'
    retrieved = get_retrieved(query, k=max(12, count))
    payload = {
        'session_id': req.session_id or session_memory.create_session(),
        'questions': [],
    }
    # If pipeline JSON bundles exist, prefer them to assemble the full paper quickly
    try:
        from pathlib import Path
        from .mock_test_api import _flatten_pipeline_bundle
        pipeline_dir = Path(__file__).parent / 'mock_test_pipeline' / 'output'
        if pipeline_dir.exists():
            pipeline_questions = []
            for p in sorted(pipeline_dir.glob('mock_test_set_*.json')):
                try:
                    import json
                    payload_json = json.loads(p.read_text(encoding='utf-8'))
                    flattened = _flatten_pipeline_bundle(payload_json)
                    if isinstance(flattened, list) and flattened:
                        pipeline_questions.extend(flattened)
                except Exception:
                    continue
            if pipeline_questions:
                payload['questions'] = pipeline_questions[:count]
                return payload
    except Exception:
        # Fall back to existing generation logic on any error
        pass
    api_key = get_mistral_api_key()
    if api_key:
        try:
            raw = call_mistral_generate(api_key, _mock_prompt(retrieved, count, exclude_hashes))
            questions = _parse_question_list(raw)
            payload['questions'] = [q for q in questions if q['hash'] not in set(exclude_hashes)][:count]
        except Exception:
            payload['questions'] = []
    if len(payload['questions']) < count:
        payload['questions'].extend(_fallback_mock_questions(count - len(payload['questions']), exclude_hashes))
    payload['questions'] = payload['questions'][:count]
    return payload


@app.post('/dev/fixed-set/{set_id}')
async def dev_fixed_set(set_id: int):
    """Developer-only endpoint to return a fixed-set bundle without auth.

    This is a temporary helper for local testing. Do not expose in production.
    """
    try:
        # Prefer the pipeline bundle loader from mock_test_api if available
        try:
            bundle = mock_test_api._load_fixed_set_bundle(set_id)
            return bundle
        except Exception:
            # Fall back to loading via the module function if direct call fails
            from .mock_test_api import _load_fixed_set_bundle as _loader
            return _loader(set_id)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post('/session/reset')
async def reset_session_endpoint(data: Dict):
    sid = data.get('session_id')
    if not sid:
        raise HTTPException(status_code=400, detail='session_id required')
    try:
        ok = session_memory.reset_session(sid)
        if ok:
            return {'status': 'ok', 'session_id': sid}
        else:
            raise HTTPException(status_code=404, detail='session not found')
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post('/chat')
async def chat(msg: Msg):
    query = msg.message.strip()
    gate = safety_gate(query)
    if gate:
        if gate == 'Empty message':
            raise HTTPException(status_code=400, detail=gate)
        return {'reply': gate, 'sources': [], 'session_id': msg.session_id, 'detailed': msg.detailed}

    if not is_neet_question(query):
        # Allow follow-up detail requests that refer to a previous NEET answer
        detail_triggers = ['explain', 'detail', 'elaborate', 'more', 'tell me more', 'expand', 'describe']
        q_lower = query.lower()
        is_detail_request = any(t in q_lower for t in detail_triggers)
        has_neet_history = any(
            m.get('role') in ('assistant', 'bot') for m in (msg.history or [])
        )
        if not (is_detail_request and has_neet_history):
            return {'reply': NEET_REFUSAL, 'sources': [], 'session_id': msg.session_id, 'detailed': msg.detailed}

    session_id, windowed_history = _ensure_session(msg)
    session_memory.add_message(session_id, 'user', query)

    # If this is a detail follow-up, prepend the last user topic to the query
    detail_triggers = ['explain', 'detail', 'elaborate', 'more', 'tell me more', 'expand', 'describe']
    q_lower = query.lower()
    is_detail_request = any(t in q_lower for t in detail_triggers) and len(_tokens(query)) <= 4
    if is_detail_request:
        past_user_msgs = [m['text'] for m in (msg.history or []) if m.get('role') == 'user']
        if past_user_msgs:
            last_topic = past_user_msgs[-1]
            query = f"{last_topic} - explain in detail"
    retrieval_query = _compose_retrieval_query(query, windowed_history, window=4)
    retrieved = get_retrieved(retrieval_query)
    combined_history = (windowed_history or []) + (msg.history or [])
    reply = synthesize_answer(query, combined_history, retrieved, detailed=msg.detailed)
    session_memory.add_message(session_id, 'assistant', reply)
    payload = build_answer_payload(query, combined_history, retrieved, reply)
    payload['session_id'] = session_id
    payload['detailed'] = msg.detailed
    return payload
