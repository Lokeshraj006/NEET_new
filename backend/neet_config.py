import os
from typing import List, Optional


def load_dotenv_file(path: str):
    if not os.path.exists(path):
        return

    try:
        with open(path, 'r', encoding='utf-8') as handle:
            for raw_line in handle:
                line = raw_line.strip()
                if not line or line.startswith('#') or '=' not in line:
                    continue
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                if key and key not in os.environ:
                    os.environ[key] = value
    except OSError:
        pass


def load_project_env():
    base_dir = os.path.dirname(__file__)
    load_dotenv_file(os.path.join(base_dir, '.env'))
    load_dotenv_file(os.path.join(os.path.dirname(base_dir), '.env'))


def _env_text(name: str, default: str) -> str:
    value = os.environ.get(name, default)
    return value.strip()


def _env_list(name: str, default: List[str]) -> List[str]:
    raw = os.environ.get(name)
    if not raw:
        return default
    items = [part.strip() for part in raw.split('||')]
    return [item for item in items if item]


def _env_set(name: str, default: set[str]) -> set[str]:
    raw = os.environ.get(name)
    if not raw:
        return default
    return {item for item in _env_list(name, []) if item}


def _env_dict(name: str, default: dict[str, str]) -> dict[str, str]:
    raw = os.environ.get(name)
    if not raw:
        return default
    mapping: dict[str, str] = {}
    for entry in _env_list(name, []):
        if '::' not in entry:
            continue
        key, value = entry.split('::', 1)
        key = key.strip()
        value = value.strip()
        if key and value:
            mapping[key] = value
    return mapping


def _env_int(name: str, default: int, minimum: int = 1, maximum: Optional[int] = None) -> int:
    raw = os.environ.get(name, str(default))
    try:
        value = int(str(raw).strip())
    except (TypeError, ValueError, AttributeError):
        value = default
    value = max(minimum, value)
    if maximum is not None:
        value = min(maximum, value)
    return value


load_project_env()

STOPWORDS = _env_set('STOPWORDS', set())
NEET_TOPICS = _env_set('NEET_TOPICS', set())
IN_SCOPE_HINTS = _env_set('IN_SCOPE_HINTS', set())
PRIMARY_SUBJECTS = _env_set('PRIMARY_SUBJECTS', set())
NON_NEET_SOCIAL_HINTS = _env_set('NON_NEET_SOCIAL_HINTS', set())
NON_NEET_MEDIA_HINTS = _env_set('NON_NEET_MEDIA_HINTS', set())
PHYSICS_CHEM_TRIGGERS = _env_set('PHYSICS_CHEM_TRIGGERS', set())
FORMULA_RELEVANCE_HINTS = _env_set('FORMULA_RELEVANCE_HINTS', set())

NEET_REFUSAL = _env_text('NEET_REFUSAL', '')
ANSWER_STYLE_GUIDE = _env_text('NEET_ANSWER_STYLE_GUIDE', '')
SYSTEM_PROMPT_LINES = _env_list('NEET_SYSTEM_PROMPT_LINES', [])
CONCISE_RESPONSE_GUIDE = _env_list('NEET_RESPONSE_GUIDE_CONCISE', [])
DETAILED_RESPONSE_GUIDE = _env_list('NEET_RESPONSE_GUIDE_DETAILED', [])
MISTRAL_MAX_TOKENS = _env_int('MISTRAL_MAX_TOKENS', 800, minimum=1, maximum=800)
CONCEPT_GLOSSARY = _env_dict('CONCEPT_GLOSSARY', {})
FORMULA_HINTS = _env_dict('FORMULA_HINTS', {})
FALLBACK_TOPIC_HINTS = _env_dict('FALLBACK_TOPIC_HINTS', {})