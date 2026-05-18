import sys
sys.path.insert(0, r'c:\Users\dines\Desktop\NEET\backend')
import app

samples = [
    ('snell', 'Definition\n### Snell\'s Law\nFormula\nn1 sin theta1 = n2 sin theta2'),
    ('summary', 'Summary\nThis is an incomplete idea...'),
    ('non-neet', 'Refuse in one short sentence'),
]

for name, text in samples:
    print(f'--- {name} ---')
    print(app.format_mistral_response(text, 'test', False))
    print()
