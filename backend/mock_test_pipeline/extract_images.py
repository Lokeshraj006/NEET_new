from __future__ import annotations

import base64
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List

try:
    import fitz
except ImportError:  # pragma: no cover - optional dependency
    fitz = None


BASE_DIR = Path(__file__).resolve().parent
DEFAULT_IMAGES_DIR = BASE_DIR / "images"


@dataclass(frozen=True)
class ExtractedImage:
    page_number: int
    image_path: str
    xref: int


def ensure_image_dir(images_dir: Path | None = None) -> Path:
    target = Path(images_dir or DEFAULT_IMAGES_DIR)
    target.mkdir(parents=True, exist_ok=True)
    return target


def _safe_suffix(ext: str | None) -> str:
    suffix = (ext or "png").lower().strip().lstrip(".")
    if suffix in {"jpg", "jpeg", "png", "webp"}:
        return suffix
    return "png"


def extract_images(pdf_path: str | Path, images_dir: str | Path | None = None) -> Dict[int, List[str]]:
    """Extract embedded diagrams/images with PyMuPDF and save them on disk.

    Returns a mapping of page number to relative image paths so questions can
    attach the nearest diagram assets without depending on a binary payload.
    """

    if fitz is None:
        raise RuntimeError("PyMuPDF is required for diagram extraction.")

    pdf_file = Path(pdf_path)
    output_dir = ensure_image_dir(Path(images_dir) if images_dir else None)
    page_to_images: Dict[int, List[str]] = {}

    doc = fitz.open(str(pdf_file))
    try:
        for page_index in range(len(doc)):
            page = doc[page_index]
            page_number = page_index + 1
            page_images: List[str] = []
            for image_index, image_info in enumerate(page.get_images(full=True), start=1):
                xref = int(image_info[0])
                extracted = doc.extract_image(xref)
                if not extracted:
                    continue
                image_bytes = extracted.get("image")
                if not image_bytes:
                    continue
                extension = _safe_suffix(extracted.get("ext"))
                file_name = f"page_{page_number:03d}_img_{image_index:02d}.{extension}"
                file_path = output_dir / file_name
                file_path.write_bytes(image_bytes)
                page_images.append(str(file_path))
            if page_images:
                page_to_images[page_number] = page_images
    finally:
        doc.close()

    return page_to_images


def encode_image_base64(image_path: str | Path) -> str:
    path = Path(image_path)
    if not path.exists():
        candidates = [
            DEFAULT_IMAGES_DIR / path,
            BASE_DIR / path,
            Path(__file__).resolve().parent / path,
        ]
        for candidate in candidates:
            if candidate.exists():
                path = candidate
                break
        else:
            return ""
    return base64.b64encode(path.read_bytes()).decode("ascii")
