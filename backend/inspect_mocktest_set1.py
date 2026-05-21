import sys
import os
import pdfplumber
from pathlib import Path

# Add backend to python path
sys.path.insert(0, os.path.join(os.getcwd(), 'backend'))

import mock_test_api

def test():
    pdf_path = mock_test_api.PDFS_DIR / "mocktest_set1.pdf"
    print("mocktest_set1.pdf exists:", pdf_path.exists())
    if pdf_path.exists():
        with pdfplumber.open(pdf_path) as pdf:
            print(f"Total pages: {len(pdf.pages)}")
            for i in range(min(5, len(pdf.pages))):
                print(f"\n--- Page {i+1} ---")
                text = pdf.pages[i].extract_text()
                if text:
                    lines = text.split('\n')
                    print("First 5 lines:")
                    for line in lines[:5]:
                        print("  ", line)
                else:
                    print("No text extracted.")

if __name__ == '__main__':
    test()
