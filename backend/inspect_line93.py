with open('backend/docs/set1.txt', 'r', encoding='utf-8', errors='ignore') as f:
    lines = f.readlines()

line = lines[93]
print("Codes length:", len(line))
codes = [ord(c) for c in line]
# Let's print in chunks of 50
print("0-50:", codes[:50])
print("50-100:", codes[50:100])
print("100+:", codes[100:])
