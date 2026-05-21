import os
import sys
import pdfplumber
from pathlib import Path

sys.path.insert(0, os.path.join(os.getcwd(), 'backend'))
import mock_test_api

def test():
    pdf_dir = mock_test_api.PDFS_DIR
    pdfs = list(pdf_dir.glob('*.pdf'))
    print(f"Found {len(pdfs)} PDFs in {pdf_dir}\n")
    
    for pdf_path in pdfs:
        print(f"--- File: {pdf_path.name} ({pdf_path.stat().st_size / 1024 / 1024:.2f} MB) ---")
        try:
            with pdfplumber.open(pdf_path) as pdf:
                print(f"Total pages: {len(pdf.pages)}")
                if len(pdf.pages) > 0:
                    text = pdf.pages[0].extract_text()
                    if text:
                        # Clean non-ascii for console printing
                        lines = [line.encode('ascii', errors='ignore').decode('ascii') for line in text.split('\n')[:5]]
                        print("First 5 lines:")
                        for line in lines:
                            print("  ", line)
                    else:
                        print("No text on page 1")
        except Exception as e:
            print(f"Error: {e}")
        print()

if __name__ == '__main__':
    test()
