"""
Create 5 placeholder mock test JSON bundles (180 questions each) for testing.
These are deterministic, valid payloads that the backend will prefer when present.
"""
import json
import hashlib
from pathlib import Path

BASE_DIR = Path(__file__).parent
OUTPUT_DIR = BASE_DIR / "output"

SUBJECTS = ["Physics", "Chemistry", "Botany", "Zoology"]
QUESTIONS_PER_SUBJECT = 45
TOTAL_QUESTIONS = QUESTIONS_PER_SUBJECT * len(SUBJECTS)

def make_question(subject: str, idx: int, set_id: int) -> dict:
    q_text = f"{subject} placeholder question {idx} for set {set_id}. What is the correct option?"
    options = [f"{subject} Option A {idx}", f"{subject} Option B {idx}", f"{subject} Option C {idx}", f"{subject} Option D {idx}"]
    payload = q_text + '|' + '|'.join(options[:4])
    h = hashlib.sha1(payload.encode('utf-8')).hexdigest()[:16]
    answer_index = idx % 4
    return {
        "subject": subject,
        "unit": f"Set {set_id}",
        "chapter": f"Set {set_id}",
        "question_type": "MCQ",
        "difficulty": "Medium",
        "question": q_text,
        "options": options,
        "answer_index": answer_index,
        "correct_answer": chr(ord('A') + answer_index),
        "passage": "",
        "explanation": "",
        "concept": f"Set {set_id}",
        "topic": f"Set {set_id}",
        "concept_key": f"set{set_id}_q{idx}",
        "source_page": 0,
        "question_image": "",
        "hash": h,
    }


def build_bundle(set_id: int) -> dict:
    questions = []
    subjects_arr = []
    for subj in SUBJECTS:
        subj_questions = []
        start = (SUBJECTS.index(subj) * QUESTIONS_PER_SUBJECT) + 1
        for i in range(QUESTIONS_PER_SUBJECT):
            qnum = start + i
            q = make_question(subj, qnum, set_id)
            subj_questions.append(q)
            questions.append(q)
        subjects_arr.append({
            "subject_name": subj,
            "subject": subj,
            "questions": subj_questions,
        })

    bundle = {
        "mock_test_number": set_id,
        "title": f"Mock Test Set {set_id} (placeholder)",
        "total_questions": len(questions),
        "total_marks": len(questions) * 4,
        "duration_seconds": 3 * 60 * 60,
        "questions": questions,
        "subjects": subjects_arr,
        "notes": "Placeholder bundles so backend uses pipeline outputs for testing. Replace with real pipeline outputs when ready.",
    }
    return bundle


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    written = []
    for sid in range(1, 6):
        path = OUTPUT_DIR / f"mock_test_set_{sid}.json"
        bundle = build_bundle(sid)
        path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding='utf-8')
        written.append(path)
    for p in written:
        print(p)

if __name__ == '__main__':
    main()
