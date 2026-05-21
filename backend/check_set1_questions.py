import sys
import os
import re

sys.path.insert(0, os.path.join(os.getcwd(), 'backend'))
import mock_test_api

def test():
    paths = {
        "paper": mock_test_api.DOCS_DIR / "set1.txt",
        "answer": mock_test_api.DOCS_DIR / "set1_answers.txt"
    }
    
    paper_text = paths["paper"].read_text(encoding="utf-8", errors="ignore")
    answer_text = paths["answer"].read_text(encoding="utf-8", errors="ignore")
    answers = mock_test_api._parse_fixed_set_answers(answer_text)
    
    print(f"Total parsed answers: {len(answers)}")
    
    page_entries = [{
        "page_number": 1,
        "text": paper_text,
        "has_visuals": False,
        "image": "",
    }]
    
    questions = mock_test_api._parse_fixed_set_questions(page_entries, answers, 1)
    print(f"Total parsed questions: {len(questions)}")
    
    parsed_nums = set()
    for q in questions:
        # find the number in hash or we can see which numbers were seen
        pass
        
    # Let's inspect which question blocks were extracted
    cleaned_text = mock_test_api._clean_fixed_set_text(paper_text)
    blocks = mock_test_api._extract_question_blocks(cleaned_text)
    print(f"Total extracted question blocks: {len(blocks)}")
    
    all_nums = [b[0] for b in blocks]
    print("First 20 question block numbers:", all_nums[:20])
    print("Last 20 question block numbers:", all_nums[-20:])
    
    # Check why some question blocks were not parsed as valid questions
    failed_blocks = []
    for num, block in blocks:
        option_matches = list(re.finditer(r"(?ms)^\s*[\(\[]?([A-Da-d1-4])\s*[\)\].:-]\s*(.*?)(?=^\s*[\(\[]?[A-Da-d1-4]\s*[\)\].:-]\s*|\Z)", block))
        options = [mock_test_api._normalize_multiline_text(m.group(2)) for m in option_matches[:4]]
        if len(options) < 4:
            alt_options = re.findall(r"(?ms)^\s*[\(\[]?([A-Da-d1-4])\s*[\)\].:-]\s*(.*?)(?=^\s*[\(\[]?[A-Da-d1-4]\s*[\)\].:-]\s*|\Z)", block)
            options = [mock_test_api._normalize_multiline_text(opt) for _, opt in alt_options[:4]]
        
        question_text = block
        if option_matches:
            question_text = block[:option_matches[0].start()].strip()
        question_text = re.sub(r"^\s*(?:Q\.\s*)?\d{1,3}\.\s*", "", question_text, count=1).strip()
        question_text = mock_test_api._normalize_multiline_text(question_text)
        
        if len(options) != 4:
            failed_blocks.append((num, "Options count != 4 (found {})".format(len(options))))
        elif not mock_test_api._looks_like_fixed_question(question_text, options):
            failed_blocks.append((num, "Looks like noise/invalid"))
            
    print(f"Failed blocks count: {len(failed_blocks)}")
    for num, reason in failed_blocks[:15]:
        print(f"  Q.{num}: {reason}")

if __name__ == '__main__':
    test()
