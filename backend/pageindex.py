import os
import re
from pathlib import Path
from typing import List, Dict, Set


def _split_into_chunks(text: str, max_chars: int = 700):
    text = re.sub(r'\r\n?', '\n', text).strip()
    if not text:
        return []
    paragraphs = [p.strip() for p in re.split(r'\n\s*\n', text) if p.strip()]
    chunks = []
    for paragraph in paragraphs:
        if len(paragraph) <= max_chars:
            chunks.append(paragraph)
            continue
        start = 0
        while start < len(paragraph):
            end = min(len(paragraph), start + max_chars)
            if end < len(paragraph):
                split_at = paragraph.rfind(' ', start, end)
                if split_at > start + 120:
                    end = split_at
            chunks.append(paragraph[start:end].strip())
            if end >= len(paragraph):
                break
            start = max(end - 120, start + 1)
    return [c for c in chunks if c]


def _tokenize(text: str) -> List[str]:
    return [t for t in re.findall(r"[a-zA-Z]{3,}", text.lower())]


class PageIndex:
    """Simple page-index based retrieval for text docs.

    Builds an inverted index mapping tokens -> page ids (chunks). Each chunk
    is assigned a monotonically increasing page id. Query returns scored
    pages similar to previous lexical retrieval so behaviour remains.
    """

    def __init__(self):
        self.pages: Dict[int, Dict] = {}
        self.inverted: Dict[str, Set[int]] = {}
        self._built = False

    def build_index(self, docs_dir: str) -> Dict:
        docs_dir = Path(docs_dir)
        if not docs_dir.exists():
            return {'docs': 0}

        self.pages.clear()
        self.inverted.clear()
        pid = 0
        for txt in sorted(docs_dir.glob('*.txt')):
            text = txt.read_text(encoding='utf-8')
            chunks = _split_into_chunks(text)
            for i, c in enumerate(chunks):
                page_id = pid
                pid += 1
                tokens = set(_tokenize(c))
                self.pages[page_id] = {
                    'id': page_id,
                    'source': txt.name,
                    'text': c,
                    'tokens': tokens,
                }
                for t in tokens:
                    self.inverted.setdefault(t, set()).add(page_id)

        self._built = True
        return {'docs': len(self.pages)}

    def query(self, query_text: str, k: int = 3) -> List[Dict]:
        if not self._built:
            return []
        q_tokens = set(_tokenize(query_text))
        if not q_tokens:
            return []

        candidate_ids = set()
        for t in q_tokens:
            candidate_ids.update(self.inverted.get(t, set()))

        scored = []
        for pid in candidate_ids:
            page = self.pages.get(pid)
            if not page:
                continue
            overlap = len(q_tokens.intersection(page['tokens']))
            phrase_bonus = 0.0
            text_lower = page['text'].lower()
            for token in q_tokens:
                if token and token in text_lower:
                    phrase_bonus += 0.25
            score = float(overlap) + phrase_bonus
            scored.append((score, page))

        scored.sort(key=lambda x: x[0], reverse=True)
        out = []
        for s, p in scored[:k]:
            out.append({'source': p['source'], 'text': p['text'], 'score': float(s)})
        return out


_GLOBAL_PAGE_INDEX: PageIndex = None


def get_page_index() -> PageIndex:
    global _GLOBAL_PAGE_INDEX
    if _GLOBAL_PAGE_INDEX is None:
        _GLOBAL_PAGE_INDEX = PageIndex()
    return _GLOBAL_PAGE_INDEX
