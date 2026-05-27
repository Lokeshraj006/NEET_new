from pathlib import Path
import sys
sys.path.insert(0, '.')
try:
    import mock_test_api as m
except Exception as e:
    print('IMPORT_ERROR', e)
    raise

for set_id in (1,2):
    path = m._mysql_upload_set_path(set_id)
    print('\n== SET', set_id, 'path=', path)
    if not path:
        print('  CSV not found for set', set_id)
        continue
    bundle = m._load_questions_from_csv(path, set_id)
    qs = bundle.get('questions', [])
    print('  total_questions=', len(qs))
    bad = []
    dup_count=0
    empty_count=0
    for i,q in enumerate(qs, start=1):
        options = q.get('options', [])
        opts_trim = [ (o or '').strip() for o in options ]
        empties = [idx for idx,o in enumerate(opts_trim) if not o]
        if empties:
            empty_count +=1
            bad.append((i,'empty',empties,opts_trim))
            continue
        seen=set()
        dups=[]
        for idx,o in enumerate(opts_trim):
            if o in seen:
                dups.append((idx,o))
            seen.add(o)
        if dups:
            dup_count+=1
            bad.append((i,'dups',dups,opts_trim))
    print(f'  questions with duplicate options: {dup_count}')
    print(f'  questions with empty options: {empty_count}')
    if bad:
        print('  Sample issues (first 10):')
        for item in bad[:10]:
            print('   Q#',item[0], item[1], item[2], item[3])
