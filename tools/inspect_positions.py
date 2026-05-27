from pathlib import Path
p=Path(r'C:\Users\dines\Desktop\NEET\frontend\flutter_application_1\lib\screens\mock_test_flow.dart')
s=p.read_text()
pos1=38194
pos2=56117
print('len',len(s))
for pos in (pos1,pos2):
    ch=s[pos-1]
    start=max(0,pos-40)
    end=min(len(s),pos+40)
    context=s[start:end]
    line = s.count('\n',0,pos)+1
    col = pos - (s.rfind('\n',0,pos) if s.rfind('\n',0,pos)!=-1 else 0)
    print('pos',pos,'char',repr(ch),'line',line,'col',col)
    print('context:\n',context)
