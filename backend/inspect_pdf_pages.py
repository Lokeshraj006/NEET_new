import pdfplumber
from pathlib import Path

pdf_path = Path("backend/pdfs/Online_NEET_UG_10_Mock_Test_Solved_Paper_1.pdf")
with pdfplumber.open(pdf_path) as pdf:
    for page_num in [21, 28, 72, 79, 119, 120, 168, 169]:
        print(f"\n================ PAGE {page_num} ================")
        text = pdf.pages[page_num - 1].extract_text()
        if text:
            # Clean non-ascii
            clean_text = text.encode('ascii', errors='ignore').decode('ascii')
            print("\n".join(clean_text.split("\n")[:25]))
        else:
            print("No text")
