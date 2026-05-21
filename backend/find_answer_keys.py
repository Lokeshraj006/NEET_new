import sys
import os
import pdfplumber
import re

# Add backend to python path
sys.path.insert(0, os.path.join(os.getcwd(), 'backend'))

import mock_test_api

def inspect():
    out_lines = []
    with pdfplumber.open(mock_test_api.NEW_MOCK_TEST_PDF) as pdf:
        out_lines.append(f"Total pages: {len(pdf.pages)}")
        for i, page in enumerate(pdf.pages):
            text = mock_test_api._extract_pdf_page_text(page, split_columns=False)
            
            # Find any interesting text lines
            lines = [line.strip() for line in text.splitlines() if line.strip()]
            title_lines = [l for l in lines[:10] if len(l) > 10]
            
            # Count matches
            letter_matches = re.findall(r"(?mi)\b\d{1,3}\s*[\.)]?\s*\(?[a-d1-4]\)?", text)
            
            # Check if it has answer terms
            lowered = text.lower()
            has_ans_key = "answer key" in lowered or "answers" in lowered or "hint" in lowered
            is_ans_key = mock_test_api._is_mock_test_answer_key_page(text)
            
            out_lines.append(
                f"Page {i+1}: len={len(text)} lines={len(lines)} letter_matches={len(letter_matches)} has_ans_key={has_ans_key} is_ans_key={is_ans_key}"
            )
            if title_lines:
                out_lines.append(f"  Titles: {title_lines[:3]}")
                
    with open("backend/pdf_structure.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(out_lines))
    print("Done writing backend/pdf_structure.txt")

if __name__ == '__main__':
    inspect()
