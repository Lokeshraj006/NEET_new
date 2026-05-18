"""Simple PDF ingestion utility.
Scans `backend/pdfs/` for .pdf files, extracts text using pdfplumber,
and writes corresponding .txt files into `backend/docs/` for the backend to index.

Usage:
    python ingest_pdfs.py

This script is intentionally simple and safe. It will not overwrite existing .txt
files unless `--overwrite` is passed.
"""
from pathlib import Path
import pdfplumber
import argparse

BASE = Path(__file__).parent
PDF_DIR = BASE / 'pdfs'
DOCS_DIR = BASE / 'docs'


def extract_pdf_to_text(pdf_path: Path) -> str:
    text_chunks = []
    try:
        with pdfplumber.open(pdf_path) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text_chunks.append(page_text)
    except Exception as e:
        print(f"Error reading {pdf_path}: {e}")
    return '\n\n'.join(text_chunks).strip()


def main(overwrite: bool = False):
    DOCS_DIR.mkdir(exist_ok=True)
    if not PDF_DIR.exists():
        print(f"No PDF directory found at {PDF_DIR}. Place PDFs there and re-run.")
        return

    pdfs = list(PDF_DIR.glob('*.pdf'))
    if not pdfs:
        print(f"No PDFs found in {PDF_DIR}.")
        return

    for p in pdfs:
        out_txt = DOCS_DIR / (p.stem + '.txt')
        if out_txt.exists() and not overwrite:
            print(f"Skipping existing: {out_txt}")
            continue
        print(f"Extracting {p} -> {out_txt}")
        text = extract_pdf_to_text(p)
        if text:
            out_txt.write_text(text, encoding='utf-8')
        else:
            print(f"No text extracted from {p}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--overwrite', action='store_true')
    args = parser.parse_args()
    main(overwrite=args.overwrite)
