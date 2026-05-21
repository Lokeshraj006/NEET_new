import pdfplumber
from pathlib import Path

pdf_path = Path("backend/pdfs/Online_NEET_UG_10_Mock_Test_Solved_Paper_1.pdf")
with pdfplumber.open(pdf_path) as pdf:
    for page_num in range(79, 98):
        text = pdf.pages[page_num - 1].extract_text()
        if text and "97." in text:
            print(f"--- Page {page_num} ---")
            lines = text.split("\n")
            for idx, line in enumerate(lines):
                if "97" in line:
                    for l in lines[max(0, idx-2):min(len(lines), idx+5)]:
                        print(l)
