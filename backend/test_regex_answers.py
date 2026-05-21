import pdfplumber
import re
from pathlib import Path

pdf_path = Path("backend/pdfs/Online_NEET_UG_10_Mock_Test_Solved_Paper_1.pdf")
with pdfplumber.open(pdf_path) as pdf:
    # Let's concatenate all explanation pages for 2023 (pages 28 to 47)
    text_chunks = []
    for page_num in range(28, 48):
        text = pdf.pages[page_num - 1].extract_text()
        if text:
            text_chunks.append(text)
    full_text = "\n".join(text_chunks)
    
    # Try different regex patterns to match answers
    # Format: 1. Option (2) is correct.
    # or: 19. Option (c) is correct.
    # or: 108. Option (2) is correct.
    pattern1 = r"(?mi)^\s*(\d{1,3})\.\s*Option\s*\(?([a-d1-4])\)?\s*is\s*correct"
    matches1 = re.findall(pattern1, full_text)
    print(f"Pattern 1 matched: {len(matches1)}")
    if matches1:
        print("First 10 matches of Pattern 1:", matches1[:10])
        
    # Let's also try a more generic pattern
    pattern2 = r"(?mi)(\d{1,3})\.\s*Option\s*\(?([a-d1-4])\)?\s*is"
    matches2 = re.findall(pattern2, full_text)
    print(f"Pattern 2 matched: {len(matches2)}")
    if matches2:
        print("First 10 matches of Pattern 2:", matches2[:10])

if __name__ == '__main__':
    pass
