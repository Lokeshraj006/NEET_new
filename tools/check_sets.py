import sys
sys.path.insert(0, r'C:\Users\dines\Desktop\NEET\backend')
import mock_test_api

for set_id in (1,2):
    bundle = mock_test_api._load_fixed_set_bundle(set_id)
    questions = bundle.get('questions', [])
    print(f'set {set_id} questions:', len(questions))
    bad = 0
    for i,q in enumerate(questions):
        opts = q.get('options')
        if not isinstance(opts, list) or len(opts) != 4:
            bad += 1
            continue
        cleaned = [str(o).strip() for o in opts]
        if any(not c for c in cleaned) or len(set(cleaned)) != 4:
            bad += 1
    print(f'set {set_id} bad_questions:', bad)

# check overlap
b1 = mock_test_api._load_fixed_set_bundle(1)['questions']
b2 = mock_test_api._load_fixed_set_bundle(2)['questions']
hashes1 = {q.get('hash') for q in b1}
hashes2 = {q.get('hash') for q in b2}
print('overlap:', len(hashes1 & hashes2))
