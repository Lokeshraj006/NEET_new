from __future__ import annotations

import argparse
import json
import hashlib
import re
from pathlib import Path
from typing import List

from .parser import (
    DEFAULT_PDF,
    DEFAULT_CONFIG_ID,
    BASE_DIR,
    parse_questions,
    build_mock_test_bundle,
    KEEP_PER_SUBJECT,
    SUBJECT_SPECS,
)
from .validator import validate_mock_test_bundle

OUTPUT_DIR = BASE_DIR / "output"


def _question_key(question: dict) -> str:
    question_text = re.sub(r"[^a-z0-9]+", " ", str(question.get("question", "")).lower()).strip()
    option_text = "|".join(
        re.sub(r"[^a-z0-9]+", " ", str(option).lower()).strip()
        for option in question.get("options", [])[:4]
    )
    return hashlib.sha1(f"{question_text}|{option_text}".encode("utf-8")).hexdigest()


def make_hash(question: str, options: List[str]) -> str:
    payload = question.strip() + "|" + "|".join(opt.strip() for opt in options[:4])
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()[:16]


def pad_pool(question_pool: List[dict]) -> List[dict]:
    grouped = {name: [] for name, _, _ in SUBJECT_SPECS}
    for q in question_pool:
        grouped.setdefault(q.get("subject_name"), []).append(q)

    for subject_name, _, _ in SUBJECT_SPECS:
        cur = grouped.get(subject_name, [])
        selected = []
        seen = set()
        for item in cur:
            key = _question_key(item)
            if key in seen:
                continue
            seen.add(key)
            selected.append(item)
            if len(selected) == KEEP_PER_SUBJECT:
                break
        cur = selected
        grouped[subject_name] = cur

    normalized_pool = []
    for subject_name, _, _ in SUBJECT_SPECS:
        items = grouped.get(subject_name, [])[:KEEP_PER_SUBJECT]
        for idx, item in enumerate(items, start=1):
            item = dict(item)
            item["question_number"] = idx
            item["section"] = "A" if idx <= 35 else "B"
            normalized_pool.append(item)

    return normalized_pool


def write_bundles(padded_pool: List[dict], set_count: int, output_dir: Path) -> List[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for set_number in range(1, set_count + 1):
        bundle = build_mock_test_bundle(padded_pool, set_number)
        bundle_path = output_dir / f"mock_test_set_{set_number}.json"
        validate_mock_test_bundle(bundle)
        bundle_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8")
        written.append(bundle_path)
    return written


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", type=Path, default=DEFAULT_PDF)
    parser.add_argument("--set-count", type=int, default=5)
    parser.add_argument("--config-id", type=str, default=DEFAULT_CONFIG_ID)
    parser.add_argument("--api-key", type=str, default=None)
    args = parser.parse_args()

    pool = parse_questions(args.pdf, api_key=args.api_key, config_id=args.config_id)
    print(f"Parsed {len(pool)} questions, padding to {KEEP_PER_SUBJECT * len(SUBJECT_SPECS)} total.")
    padded = pad_pool(pool)
    written = write_bundles(padded, args.set_count, OUTPUT_DIR)
    for p in written:
        print(p)


if __name__ == "__main__":
    main()
