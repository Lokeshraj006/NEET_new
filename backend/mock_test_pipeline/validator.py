from __future__ import annotations

import hashlib
import re
from typing import Dict, Iterable, List

REQUIRED_SUBJECTS = ["Physics", "Chemistry", "Botany", "Zoology"]
EXPECTED_QUESTION_COUNT = 45


def _normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip().lower()


def _question_fingerprint(question: Dict) -> str:
    options = question.get("options", [])
    payload = _normalize(str(question.get("question", "")))
    payload += "|" + "|".join(_normalize(str(option)) for option in options[:4])
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()


def _is_non_empty_text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_question(question: Dict, *, subject_name: str, question_number: int) -> List[str]:
    errors: List[str] = []

    if _normalize(str(question.get("subject_name", ""))) != _normalize(subject_name):
        errors.append(f"question {question_number}: subject_name mismatch")

    if int(question.get("question_number", 0) or 0) != question_number:
        errors.append(f"question {question_number}: question_number mismatch")

    if not _is_non_empty_text(question.get("question", "")):
        errors.append(f"question {question_number}: empty question text")

    options = question.get("options", [])
    if not isinstance(options, list) or len(options) != 4:
        errors.append(f"question {question_number}: expected exactly 4 options")
    else:
        for index, option in enumerate(options, start=1):
            if not _is_non_empty_text(option):
                errors.append(f"question {question_number}: option {index} is empty")

    answer_index = question.get("answer_index")
    if not isinstance(answer_index, int) or answer_index < 0 or answer_index > 3:
        errors.append(f"question {question_number}: invalid answer_index")

    if str(question.get("correct_answer", "")).strip().upper() not in {"A", "B", "C", "D"}:
        errors.append(f"question {question_number}: invalid correct_answer")

    if not _is_non_empty_text(question.get("hash", "")):
        errors.append(f"question {question_number}: missing hash")

    if not _is_non_empty_text(question.get("source_page", "")) and not isinstance(question.get("source_page"), int):
        errors.append(f"question {question_number}: missing source_page")

    return errors


def validate_subject_bundle(subject_bundle: Dict) -> List[str]:
    errors: List[str] = []
    subject_name = str(subject_bundle.get("subject_name", "")).strip()
    if subject_name not in REQUIRED_SUBJECTS:
        errors.append(f"invalid subject_name: {subject_name!r}")
        return errors

    questions = subject_bundle.get("questions", [])
    if not isinstance(questions, list):
        errors.append(f"{subject_name}: questions must be a list")
        return errors

    if len(questions) != EXPECTED_QUESTION_COUNT:
        errors.append(f"{subject_name}: expected {EXPECTED_QUESTION_COUNT} questions, found {len(questions)}")

    seen_hashes = set()
    for index, question in enumerate(questions, start=1):
        if not isinstance(question, dict):
            errors.append(f"{subject_name} question {index}: not an object")
            continue
        errors.extend(validate_question(question, subject_name=subject_name, question_number=index))
        fingerprint = _question_fingerprint(question)
        if fingerprint in seen_hashes:
            errors.append(f"{subject_name} question {index}: duplicate question detected")
        seen_hashes.add(fingerprint)

    return errors


def validate_mock_test_bundle(bundle: Dict) -> None:
    errors: List[str] = []

    if not isinstance(bundle, dict):
        raise ValueError("mock test bundle must be an object")

    if int(bundle.get("total_questions", 0) or 0) != 180:
        errors.append("total_questions must be 180")

    subjects = bundle.get("subjects", [])
    if not isinstance(subjects, list):
        raise ValueError("subjects must be a list")

    subject_names = [str(item.get("subject_name", "")).strip() for item in subjects if isinstance(item, dict)]
    if subject_names != REQUIRED_SUBJECTS:
        errors.append(f"subjects must be exactly {REQUIRED_SUBJECTS}")

    for subject_bundle in subjects:
        if not isinstance(subject_bundle, dict):
            errors.append("each subject entry must be an object")
            continue
        errors.extend(validate_subject_bundle(subject_bundle))

    flattened = bundle.get("questions", [])
    if not isinstance(flattened, list):
        errors.append("questions must be a list")
    elif len(flattened) != 180:
        errors.append(f"questions must contain 180 items, found {len(flattened)}")

    if errors:
        raise ValueError("; ".join(errors))
