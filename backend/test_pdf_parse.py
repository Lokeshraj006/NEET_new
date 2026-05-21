import sys
import os
import pdfplumber
from pathlib import Path

sys.path.insert(0, os.path.join(os.getcwd(), 'backend'))
import mock_test_api

def test():
    pdf_path = mock_test_api.NEW_MOCK_TEST_PDF
    print("PDF path:", pdf_path)
    
    # Let's parse NEET 2023: Page 1 to 20, answers at Page 28
    start_page = 1
    end_page = 20
    answer_page = 28
    
    page_entries = []
    with pdfplumber.open(pdf_path) as pdf:
        for page_number in range(start_page, end_page + 1):
            page = pdf.pages[page_number - 1]
            page_text = mock_test_api._extract_pdf_page_text(page, split_columns=True)
            page_entries.append({
                "page_number": page_number,
                "text": page_text,
                "has_visuals": mock_test_api._page_has_visual_content(page),
                "image": mock_test_api._render_pdf_page_image_base64(page),
            })
        
        answer_text = mock_test_api._extract_pdf_page_text(pdf.pages[answer_page - 1], split_columns=True)
        # also read next pages for explanations/answers if needed, but let's see how _parse_fixed_set_answers does it
        
    print("Answer text length:", len(answer_text))
    answers = mock_test_api._parse_fixed_set_answers(answer_text)
    print("Parsed answers count:", len(answers))
    print("First 10 answers:", list(answers.items())[:10])
    
    questions = mock_test_api._parse_fixed_set_questions(page_entries, answers, 1)
    print("Parsed questions count:", len(questions))
    if questions:
        print("First question parsed:", questions[0]["question"][:100])
        print("First question options:", questions[0]["options"])
        print("First question answer index:", questions[0]["answer_index"])

if __name__ == '__main__':
    test()
