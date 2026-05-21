import sys
import os
import re

sys.path.insert(0, os.path.join(os.getcwd(), 'backend'))
import mock_test_api

def split_bilingual_line(line: str) -> str:
    stripped = line.rstrip('\n').rstrip('\r')
    if not stripped:
        return ""
        
    last_dev_idx = -1
    for i in range(len(stripped) - 1, -1, -1):
        val = ord(stripped[i])
        if 0x0900 <= val <= 0x097F or val == 0:
            last_dev_idx = i
            break
            
    if last_dev_idx != -1:
        return stripped[last_dev_idx + 1:].strip()
        
    if len(stripped) < 10 and ' ' in stripped:
        mid = len(stripped) // 2
        return stripped[mid:].strip()
        
    if stripped.count("(1)") > 1 or stripped.count("(2)") > 1 or stripped.count("(3)") > 1 or stripped.count("(4)") > 1:
        mid = len(stripped) // 2
        return stripped[mid:].strip()
        
    return stripped

def test():
    with open('backend/docs/set1.txt', 'r', encoding='utf-8', errors='ignore') as f:
        text = f.read()
        
    lines = text.splitlines()
    cleaned_lines = [split_bilingual_line(line) for line in lines]
    cleaned_text = "\n".join(cleaned_lines)
    
    answer_path = mock_test_api.DOCS_DIR / "set1_answers.txt"
    answer_text = answer_path.read_text(encoding="utf-8", errors="ignore")
    answers = mock_test_api._parse_fixed_set_answers(answer_text)
    
    blocks = mock_test_api._extract_question_blocks(cleaned_text)
    
    for number, block in blocks:
        if number in [2, 3]:
            print(f"\n--- Analyzing Q.{number} ---")
            option_matches = list(re.finditer(r"[\(\[]([A-Da-d1-4])[\)\]]", block))
            print(f"Option matches count: {len(option_matches)}")
            
            target_indices = []
            normalized = []
            for m in option_matches:
                tok = m.group(1).upper()
                if tok == '1': tok = 'A'
                elif tok == '2': tok = 'B'
                elif tok == '3': tok = 'C'
                elif tok == '4': tok = 'D'
                normalized.append(tok)
            print(f"Normalized tokens: {normalized}")
            
            # Replicate the actual code selection
            d_idx = -1
            for i in range(len(normalized) - 1, -1, -1):
                if normalized[i] == 'D':
                    d_idx = i
                    break
            print(f"D index found: {d_idx}")
            if d_idx != -1:
                c_idx = -1
                for i in range(d_idx - 1, -1, -1):
                    if normalized[i] == 'C':
                        c_idx = i
                        break
                print(f"C index found: {c_idx}")
                if c_idx != -1:
                    b_idx = -1
                    for i in range(c_idx - 1, -1, -1):
                        if normalized[i] == 'B':
                            b_idx = i
                            break
                    print(f"B index found: {b_idx}")
                    if b_idx != -1:
                        a_idx = -1
                        for i in range(b_idx - 1, -1, -1):
                            if normalized[i] == 'A':
                                a_idx = i
                                break
                        print(f"A index found: {a_idx}")
                        if a_idx != -1:
                            target_indices = [a_idx, b_idx, c_idx, d_idx]
            print(f"Target indices: {target_indices}")
            
            if not target_indices:
                if len(option_matches) >= 4:
                    target_indices = list(range(len(option_matches) - 4, len(option_matches)))
                    print(f"Fallback target indices: {target_indices}")
                else:
                    print("SKIPPED: Not enough option matches")
                    continue
                    
            options = []
            selected_matches = [option_matches[i] for i in target_indices]
            for idx, match_obj in enumerate(selected_matches):
                start = match_obj.end()
                end = selected_matches[idx+1].start() if idx+1 < len(selected_matches) else len(block)
                opt_val = block[start:end].strip()
                options.append(opt_val)
            print(f"Parsed options: {options}")
            
            question_text = block[:selected_matches[0].start()].strip()
            print(f"Question text: {repr(question_text)}")
            
            looks = mock_test_api._looks_like_fixed_question(question_text, options)
            print(f"looks_like_fixed_question: {looks}")

if __name__ == '__main__':
    test()
