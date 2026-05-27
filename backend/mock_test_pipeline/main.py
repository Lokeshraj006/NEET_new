from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List

from dotenv import load_dotenv

from .parser import DEFAULT_CONFIG_ID, DEFAULT_PDF, BASE_DIR, build_all_mock_test_bundles
from .validator import validate_mock_test_bundle


OUTPUT_DIR = BASE_DIR / "output"
IMAGES_DIR = BASE_DIR / "images"
ENV_PATHS = [BASE_DIR / ".env", BASE_DIR.parent / ".env"]


def load_environment() -> None:
    for env_path in ENV_PATHS:
        load_dotenv(env_path)


def write_bundles(bundles: List[dict], output_dir: Path) -> List[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    written_files: List[Path] = []
    for bundle in bundles:
        validate_mock_test_bundle(bundle)
        set_number = int(bundle["mock_test_number"])
        output_path = output_dir / f"mock_test_set_{set_number}.json"
        output_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8")
        written_files.append(output_path)
    return written_files


def generate_pipeline(
    pdf_path: Path = DEFAULT_PDF,
    *,
    config_id: str = DEFAULT_CONFIG_ID,
    api_key: str | None = None,
    set_count: int = 5,
    output_dir: Path = OUTPUT_DIR,
    images_dir: Path = IMAGES_DIR,
) -> List[Path]:
    load_environment()
    bundles = build_all_mock_test_bundles(
        pdf_path,
        set_count=set_count,
        api_key=api_key,
        config_id=config_id,
        images_dir=images_dir,
    )
    return write_bundles(bundles, output_dir)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build NEET mock-test JSON bundles from a PDF.")
    parser.add_argument("--pdf", type=Path, default=DEFAULT_PDF, help="Source NEET PDF path")
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR, help="Directory for JSON output")
    parser.add_argument("--images-dir", type=Path, default=IMAGES_DIR, help="Directory for extracted images")
    parser.add_argument("--set-count", type=int, default=5, help="Number of mock-test sets to generate")
    parser.add_argument(
        "--config-id",
        type=str,
        default=DEFAULT_CONFIG_ID,
        help="LlamaParse config_id",
    )
    parser.add_argument(
        "--api-key",
        type=str,
        default=None,
        help="LlamaParse API key (defaults to LLAMAPARSE_API_KEY from .env)",
    )
    args = parser.parse_args()

    load_environment()
    api_key = (args.api_key or "").strip() or None
    if api_key is None:
        from os import environ

        api_key = environ.get("LLAMAPARSE_API_KEY", "").strip() or None

    written_files = generate_pipeline(
        args.pdf,
        config_id=args.config_id,
        api_key=api_key,
        set_count=max(1, args.set_count),
        output_dir=args.output_dir,
        images_dir=args.images_dir,
    )
    for file_path in written_files:
        print(file_path)


if __name__ == "__main__":
    main()
