import sys
import os
from pathlib import Path

# Add backend to python path
sys.path.insert(0, os.path.join(os.getcwd(), 'backend'))

import mock_test_api

def test():
    print("NEW_MOCK_TEST_PDF exists:", mock_test_api.NEW_MOCK_TEST_PDF.exists())
    
    for set_id in range(1, 9):
        try:
            print(f"\n--- Loading Fixed Set {set_id} ---")
            bundle = mock_test_api._load_fixed_set_bundle(set_id)
            print(f"Set {set_id} loaded successfully. Questions count: {bundle['total_questions']}")
        except Exception as e:
            print(f"Set {set_id} FAILED to load: {e}")

if __name__ == '__main__':
    test()
