import sys
import os
from pathlib import Path

# Add backend to python path
sys.path.insert(0, os.path.join(os.getcwd(), 'backend'))

import mock_test_api

def mock_fixed_set_paths():
    mapping = {}
    for set_id in range(1, mock_test_api.MOCK_TEST_SET_COUNT + 1):
        paper = mock_test_api.DOCS_DIR / f"set{set_id}.txt"
        alt_paper = mock_test_api.DOCS_DIR / f"mocktest_set{set_id}.txt"
        answer = mock_test_api.DOCS_DIR / f"set{set_id}_answers.txt"
        if not paper.exists() and alt_paper.exists():
            paper = alt_paper
        if paper.exists() and answer.exists():
            mapping[set_id] = {"paper": paper, "answer": answer}
    return mapping

def test():
    # Override the _fixed_set_paths function on the module
    mock_test_api._fixed_set_paths = mock_fixed_set_paths
    
    paths = mock_test_api._fixed_set_paths()
    print("Legacy set paths mapping:", paths)
    
    for set_id in range(1, 9):
        try:
            print(f"\n--- Loading Legacy Set {set_id} ---")
            bundle = mock_test_api._load_fixed_set_bundle(set_id)
            print(f"Legacy Set {set_id} loaded successfully. Questions count: {bundle['total_questions']}")
            if bundle['total_questions'] > 0:
                print(f"First question: {bundle['questions'][0]['question']}")
        except Exception as e:
            print(f"Legacy Set {set_id} FAILED to load: {e}")

if __name__ == '__main__':
    test()
