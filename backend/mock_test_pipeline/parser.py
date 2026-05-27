from __future__ import annotations

import hashlib
import json
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

import pdfplumber
from dotenv import dotenv_values

try:
    from llama_parse import LlamaParse
except ImportError:  # pragma: no cover - optional dependency
    LlamaParse = None

from .extract_images import encode_image_base64, extract_images, ensure_image_dir


BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent
DEFAULT_PDF = PROJECT_ROOT / "pdfs" / "Online_NEET_UG_10_Mock_Test_Solved_Paper_1.pdf"
DEFAULT_CONFIG_ID = "cfg-ahf8ebkvgv7o3ak3b9tnup6dytkb"
SUBJECT_SPECS = [
    ("Physics", 1, 50),
    ("Chemistry", 51, 100),
    ("Botany", 101, 150),
    ("Zoology", 151, 200),
]
KEEP_PER_SUBJECT = 45
SECTION_A_COUNT = 35
EXPECTED_QUESTION_TOTAL = KEEP_PER_SUBJECT * len(SUBJECT_SPECS)


@dataclass(frozen=True)
class PageText:
    page_number: int
    text: str


@dataclass(frozen=True)
class ParsedQuestion:
    subject_name: str
    source_question_number: int
    source_page: int
    question: str
    options: List[str]
    answer_index: int
    correct_answer: str
    explanation: str
    hash: str
    diagram_images: List[str]
    question_image: str = ""
    question_number: int = 0
    section: str = "A"
    mock_test_number: int = 0


def _load_env() -> None:
    for env_path in (BASE_DIR / ".env", PROJECT_ROOT / ".env"):
        for key, value in dotenv_values(env_path).items():
            if value:
                os.environ[key] = value


_CID_PATTERN = re.compile(r"\(cid:\d+\)")


def _normalize_text(value: str) -> str:
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    value = value.replace("\x00", " ").replace("\u00a0", " ")
    value = _CID_PATTERN.sub(" ", value)
    value = re.sub(r"\s*-\n\s*", "", value)
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\s*\n\s*", "\n", value)
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()


def _normalize_page_text(value: str) -> str:
    text = _normalize_text(value)
    text = re.sub(
        r"([:\.;\?!])\s+(?:Q\.?\s*)?(\d{1,3})\.\s+",
        lambda match: f"{match.group(1)}\nQ. {match.group(2)}. ",
        text,
    )
    text = re.sub(
        r"\n\s+(?:Q\.?\s*)?(\d{1,3})\.\s+",
        lambda match: f"\nQ. {match.group(1)}. ",
        text,
    )
    return text


def _clean_inline_text(value: str) -> str:
    return _normalize_text(value)


def _letter_to_index(token: str) -> int:
    normalized = token.strip().upper()
    if normalized in {"A", "1"}:
        return 0
    if normalized in {"B", "2"}:
        return 1
    if normalized in {"C", "3"}:
        return 2
    if normalized in {"D", "4"}:
        return 3
    return 0


def _index_to_letter(index: int) -> str:
    try:
        value = int(index)
    except Exception:
        value = 0
    return "ABCD"[max(0, min(3, value))]


def _subject_for_question_number(question_number: int) -> Optional[Tuple[str, int, int]]:
    for subject_name, start, end in SUBJECT_SPECS:
        if start <= question_number <= end:
            return subject_name, start, end
    return None


def _subject_index(question_number: int) -> Optional[Tuple[str, int]]:
    subject_info = _subject_for_question_number(question_number)
    if not subject_info:
        return None
    subject_name, start, _ = subject_info
    return subject_name, question_number - start + 1


def _is_question_start(line: str) -> bool:
    return bool(re.match(r"^\s*(?:Q\.?\s*)?(\d{1,3})\s*[).:-]\s+", line))


def _extract_page_number(metadata: object, fallback: int) -> int:
    if isinstance(metadata, dict):
        for key in ("page_number", "page", "pageIndex", "page_index"):
            raw_value = metadata.get(key)
            if raw_value is None:
                continue
            try:
                value = int(raw_value)
            except Exception:
                continue
            return value if value > 0 else fallback
    return fallback


def _load_llamaparse_pages(pdf_path: Path, api_key: str, config_id: str) -> List[PageText]:
    if LlamaParse is None:
        raise RuntimeError("LlamaParse is not installed.")

    parser_kwargs = {
        "api_key": api_key,
        "result_type": "markdown",
        "verbose": False,
        "language": "en",
    }
    if config_id:
        parser_kwargs["config_id"] = config_id

    parser = LlamaParse(**parser_kwargs)
    documents = parser.load_data(str(pdf_path))

    pages: List[PageText] = []
    if isinstance(documents, list):
        for index, document in enumerate(documents, start=1):
            if isinstance(document, dict):
                text = str(document.get("text", ""))
                metadata = document.get("metadata") or {}
            else:
                text = str(getattr(document, "text", ""))
                metadata = getattr(document, "metadata", {}) or {}
            page_number = _extract_page_number(metadata, index)
            if text.strip():
                pages.append(PageText(page_number=page_number, text=_normalize_page_text(text)))
    elif isinstance(documents, dict):
        raw_pages = documents.get("pages") or documents.get("documents") or []
        for index, document in enumerate(raw_pages, start=1):
            if isinstance(document, dict):
                text = str(document.get("text", ""))
                metadata = document.get("metadata") or {}
            else:
                text = str(getattr(document, "text", ""))
                metadata = getattr(document, "metadata", {}) or {}
            page_number = _extract_page_number(metadata, index)
            if text.strip():
                pages.append(PageText(page_number=page_number, text=_normalize_page_text(text)))

    pages.sort(key=lambda item: item.page_number)
    return pages


def _env_llamaparse_api_key() -> str:
    return (
        os.getenv("LLAMAPARSE_API_KEY")
        or os.getenv("LLAMA_PARSE_API_KEY")
        or ""
    ).strip()


def _env_llamaparse_config_id() -> str:
    return (
        os.getenv("LLAMAPARSE_CONFIG_ID")
        or os.getenv("LLAMA_PARSE_CONFIG_ID")
        or DEFAULT_CONFIG_ID
    ).strip()


def _extract_pdf_page_text(page, *, split_columns: bool) -> str:
    try:
        if split_columns:
            midpoint = page.width / 2
            left_text = page.crop((0, 0, midpoint, page.height)).extract_text(layout=True) or ""
            right_text = page.crop((midpoint, 0, page.width, page.height)).extract_text(layout=True) or ""
            combined = f"{left_text}\n\n{right_text}".strip()
            if combined:
                return combined
        return page.extract_text(layout=True) or ""
    except Exception:
        return ""


def _load_pdfplumber_pages(pdf_path: Path) -> List[PageText]:
    pages: List[PageText] = []
    with pdfplumber.open(pdf_path) as pdf:
        for index, page in enumerate(pdf.pages, start=1):
            text = _extract_pdf_page_text(page, split_columns=True)
            if text.strip():
                pages.append(PageText(page_number=index, text=_normalize_page_text(text)))
    return pages


def load_pages(
    pdf_path: str | Path,
    api_key: str | None = None,
    config_id: str | None = None,
    *,
    force_pdfplumber: bool = False,
) -> List[PageText]:
    _load_env()
    pdf_file = Path(pdf_path)
    resolved_api_key = (api_key or _env_llamaparse_api_key()).strip()
    resolved_config_id = (config_id or _env_llamaparse_config_id()).strip()

    if not force_pdfplumber and resolved_api_key and LlamaParse is not None:
        try:
            pages = _load_llamaparse_pages(pdf_file, resolved_api_key, resolved_config_id)
            # LlamaParse sometimes returns only a partial or low-signal layout for this PDF.
            # Fall back to the more reliable two-column pdfplumber extraction unless the page
            # coverage looks complete enough to be useful.
            if len(pages) >= 60:
                return pages
        except Exception:
            pass

    return _load_pdfplumber_pages(pdf_file)


def _extract_answer_map(pages: Sequence[PageText]) -> Dict[int, int]:
    answer_map: Dict[int, int] = {}
    best_page_matches = 0
    for page in pages:
        lowered = page.text.lower()
        matches = re.findall(r"(?mi)\b(\d{1,3})\s*[).:-]?\s*\(?([a-d1-4])\)?", page.text)
        if not matches:
            continue
        if "answer" not in lowered and len(matches) < 20:
            continue
        if len(matches) < best_page_matches and answer_map:
            continue
        page_map: Dict[int, int] = {}
        for number_text, answer_text in matches:
            try:
                number = int(number_text)
            except Exception:
                continue
            if number < 1 or number > 200:
                continue
            page_map[number] = _letter_to_index(answer_text)
        if len(page_map) >= best_page_matches:
            answer_map = page_map
            best_page_matches = len(page_map)
    return answer_map


def _extract_question_blocks(page_text: str) -> List[Tuple[int, str]]:
    starts = list(re.finditer(r"(?m)^\s*(?:Q\.?\s*)?(\d{1,3})\s*[).:-]\s+", page_text))
    if not starts:
        return []
    blocks: List[Tuple[int, str]] = []
    for index, match in enumerate(starts):
        try:
            question_number = int(match.group(1))
        except Exception:
            continue
        end = starts[index + 1].start() if index + 1 < len(starts) else len(page_text)
        block = page_text[match.start():end].strip()
        if block:
            blocks.append((question_number, block))
    return blocks


_OPTION_PATTERN = re.compile(
    r"(?ms)^\s*[\(\[]?([A-Da-d1-4])\s*[\)\].:-]\s*(.*?)(?=^\s*[\(\[]?[A-Da-d1-4]\s*[\)\].:-]\s*|\Z)",
)


def _extract_options(block: str) -> List[str]:
    matches = list(_OPTION_PATTERN.finditer(block))
    if len(matches) >= 4:
        options: List[str] = []
        for match in matches[:4]:
            body = _normalize_text(match.group(2))
            body = re.sub(r"(?:\n\s*)?Q\.?$", "", body).strip()
            if body:
                options.append(body)
        return options if len(options) == 4 else []

    fallback: List[str] = []
    for raw_line in block.splitlines():
        line = raw_line.strip()
        match = re.match(r"^\s*[\(\[]?([A-Da-d1-4])\s*[\)\].:-]\s*(.+)$", line)
        if match:
            body = _normalize_text(match.group(2))
            body = re.sub(r"(?:\n\s*)?Q\.?$", "", body).strip()
            fallback.append(body)
    return fallback[:4] if len(fallback) >= 4 else []


def _strip_question_prefix(block: str, source_number: int) -> str:
    cleaned = re.sub(rf"^\s*(?:Q\.?\s*)?{source_number}\s*[).:-]\s*", "", block, count=1).strip()
    return cleaned


def _find_question_body(block: str) -> Tuple[str, List[str]]:
    options = _extract_options(block)
    if options:
        first_option_match = _OPTION_PATTERN.search(block)
        question_text = block[: first_option_match.start()].strip() if first_option_match else block.strip()
    else:
        question_text = block.strip()
    return _normalize_text(question_text), options


def _make_hash(question: str, options: Sequence[str]) -> str:
    payload = _normalize_text(question) + "|" + "|".join(_normalize_text(option) for option in options[:4])
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()[:16]


def _relative_image_path(image_path: str) -> str:
    path = Path(image_path)
    try:
        return path.relative_to(BASE_DIR).as_posix()
    except Exception:
        return path.as_posix()


def _rotate(items: Sequence[Dict], offset: int) -> List[Dict]:
    if not items:
        return []
    actual = offset % len(items)
    return list(items[actual:]) + list(items[:actual])


def parse_questions(pdf_path: str | Path, *, api_key: str | None = None, config_id: str | None = None, images_dir: str | Path | None = None) -> List[Dict]:
    """Parse the source PDF into a normalized question pool.

    Each question keeps its original source page, source question number, and
    any extracted diagram image paths. The returned list contains only the
    first 45 questions per subject, in the Physics/Chemistry/Botany/Zoology
    order required by the new paper pattern.
    """

    _load_env()
    pdf_file = Path(pdf_path)
    image_map = extract_images(pdf_file, images_dir or ensure_image_dir())
    def _build_question_pool(pages: List[PageText]) -> List[Dict]:
        answer_map = _extract_answer_map(pages)
        page_to_questions: Dict[int, List[Dict]] = {}
        question_pool: List[Dict] = []

        for page in pages:
            blocks = _extract_question_blocks(page.text)
            if not blocks:
                continue
            for question_number, block in blocks:
                subject_info = _subject_for_question_number(question_number)
                if not subject_info:
                    continue
                subject_name, start, end = subject_info
                relative_number = question_number - start + 1
                normalized_block = _strip_question_prefix(block, question_number)
                question_text, options = _find_question_body(normalized_block)
                if not question_text or len(options) != 4:
                    continue

                answer_index = answer_map.get(question_number, 0)
                question_entry = {
                    "subject": subject_name,
                    "subject_name": subject_name,
                    "unit": f"{subject_name} Mock Test",
                    "chapter": f"{subject_name} Mock Test",
                    "topic": f"Question {relative_number}",
                    "concept": f"{subject_name} mock-test question {relative_number}",
                    "concept_key": f"{subject_name.lower()}_{relative_number:03d}",
                    "source_question_number": question_number,
                    "source_page": page.page_number,
                    "question": question_text,
                    "options": options,
                    "answer_index": int(answer_index),
                    "correct_answer": _index_to_letter(int(answer_index)),
                    "explanation": "",
                    "hash": _make_hash(question_text, options),
                }
                page_to_questions.setdefault(page.page_number, []).append(question_entry)
                question_pool.append(question_entry)

        _attach_images_to_nearest_questions(page_to_questions)
        return question_pool

    pages = load_pages(pdf_file, api_key=api_key, config_id=config_id)
    question_pool = _build_question_pool(pages)
    if len(question_pool) < 150:
        pages = load_pages(pdf_file, force_pdfplumber=True)
        question_pool = _build_question_pool(pages)

    grouped: Dict[str, List[Dict]] = {subject_name: [] for subject_name, _, _ in SUBJECT_SPECS}
    for item in question_pool:
        grouped.setdefault(item["subject_name"], []).append(item)

    normalized_pool: List[Dict] = []
    for subject_name, _, _ in SUBJECT_SPECS:
        subject_items = grouped.get(subject_name, [])
        subject_items.sort(key=lambda item: int(item.get("source_question_number", 0)))
        selected = subject_items[:KEEP_PER_SUBJECT]
        for index, item in enumerate(selected, start=1):
            normalized_item = dict(item)
            normalized_item["question_number"] = index
            normalized_item["section"] = "A" if index <= SECTION_A_COUNT else "B"
            normalized_pool.append(normalized_item)

    return normalized_pool


def _attach_images_to_nearest_questions(page_to_questions: Dict[int, List[Dict]]) -> None:
    for page_number, questions in page_to_questions.items():
        if not questions:
            continue
        images = list(questions[0].get("diagram_images", []))
        if not images:
            continue
        count = len(questions)
        if count == 1:
            questions[0]["diagram_images"] = images
            questions[0]["question_image"] = encode_image_base64(images[0])
            continue
        for index, image_path in enumerate(images):
            question_index = max(0, min(count - 1, round(((index + 1) * (count + 1)) / (len(images) + 1)) - 1))
            questions[question_index].setdefault("diagram_images", [])
            if image_path not in questions[question_index]["diagram_images"]:
                questions[question_index]["diagram_images"].append(image_path)

        for question in questions:
            diagram_images = list(question.get("diagram_images", []))
            if diagram_images and not question.get("question_image"):
                question["question_image"] = encode_image_base64(diagram_images[0])


def _build_subject_payload(subject_name: str, questions: Sequence[Dict], *, set_number: int) -> Dict:
    subject_questions: List[Dict] = []
    rotated = _rotate(list(questions), set_number - 1)
    for index, question in enumerate(rotated[:KEEP_PER_SUBJECT], start=1):
        entry = dict(question)
        entry["subject"] = subject_name
        entry["subject_name"] = subject_name
        entry["unit"] = entry.get("unit") or f"{subject_name} Mock Test"
        entry["chapter"] = entry.get("chapter") or entry["unit"]
        entry["topic"] = entry.get("topic") or f"Question {index}"
        entry["question_number"] = index
        entry["section"] = "A" if index <= SECTION_A_COUNT else "B"
        entry["mock_test_number"] = set_number
        subject_questions.append(entry)
    return {"subject_name": subject_name, "questions": subject_questions}


def build_mock_test_bundle(question_pool: Sequence[Dict], set_number: int) -> Dict:
    grouped: Dict[str, List[Dict]] = {subject_name: [] for subject_name, _, _ in SUBJECT_SPECS}
    for item in question_pool:
        grouped.setdefault(item["subject_name"], []).append(item)

    subjects = [
        _build_subject_payload(subject_name, grouped.get(subject_name, []), set_number=set_number)
        for subject_name, _, _ in SUBJECT_SPECS
    ]
    flattened = [question for subject in subjects for question in subject["questions"]]
    bundle = {
        "mock_test_number": set_number,
        "total_questions": len(flattened),
        "subjects": subjects,
        "questions": flattened,
    }
    return bundle


def build_all_mock_test_bundles(
    pdf_path: str | Path = DEFAULT_PDF,
    *,
    set_count: int = 5,
    api_key: str | None = None,
    config_id: str | None = None,
    images_dir: str | Path | None = None,
) -> List[Dict]:
    question_pool = parse_questions(pdf_path, api_key=api_key, config_id=config_id, images_dir=images_dir)
    if len(question_pool) < EXPECTED_QUESTION_TOTAL:
        raise ValueError(
            f"expected at least {EXPECTED_QUESTION_TOTAL} questions, found {len(question_pool)}"
        )

    bundles = [build_mock_test_bundle(question_pool, set_number=index) for index in range(1, set_count + 1)]
    return bundles
