from pathlib import Path

p = Path(r'C:\Users\dines\Desktop\NEET\frontend\flutter_application_1\lib\screens\mock_test_flow.dart')
s = p.read_text()

pairs = {'(': ')', '{': '}', '[': ']'}
opening = '({['
closing = ')}]'
stack = []

for i, ch in enumerate(s, 1):
    if ch in opening:
        stack.append((ch, i))
    elif ch in closing:
        if not stack:
            print('Unmatched closing', ch, 'at', i)
            break
        last, pos = stack.pop()
        if pairs[last] != ch:
            # compute line/col for opening and closing
            open_line = s.count('\n', 0, pos) + 1
            open_col = pos - (s.rfind('\n', 0, pos) if s.rfind('\n', 0, pos) != -1 else 0)
            close_line = s.count('\n', 0, i) + 1
            close_col = i - (s.rfind('\n', 0, i) if s.rfind('\n', 0, i) != -1 else 0)
            print(f"Mismatched {last} opened at {pos} (line {open_line} col {open_col}) but closed by {ch} at {i} (line {close_line} col {close_col})")
            break
else:
    if stack:
        last, pos = stack[-1]
        line = s.count('\n', 0, pos) + 1
        col = pos - (s.rfind('\n', 0, pos) if s.rfind('\n', 0, pos) != -1 else 0)
        print('Unclosed opening', last, 'opened at', pos, '(line', line, 'col', col, ')')
    else:
        print('All brackets balanced')
