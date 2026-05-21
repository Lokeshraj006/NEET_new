import pdfplumber
import re
from pathlib import Path

pdf_path = Path("backend/pdfs/Online_NEET_UG_10_Mock_Test_Solved_Paper_1.pdf")
with pdfplumber.open(pdf_path) as pdf:
    # 2022 is pages 79 to 97
    text_chunks = []
    for page_num in range(79, 98):
        text = pdf.pages[page_num - 1].extract_text()
        if text:
            text_chunks.append(text)
    full_text = "\n".join(text_chunks)
    
    # Let's see: on page 79, we had:
    # 1. Option (3) is correct.
    # 5. Option (2) is correct.
    # What about the others?
    pattern2 = r"(?mi)(\d{1,3})\.\s*Option\s*\(?([a-d1-4])\)?\s*is"
    matches2 = re.findall(pattern2, full_text)
    
    answers = {}
    for num_str, ans_str in matches2:
        num = int(num_str)
        answers[num] = ans_str
        
    print(f"Total unique questions with answers for 2022: {len(answers)}")
    missing = [i for i in range(1, 201) if i not in answers]
    print(f"Missing answers: {missing}")
