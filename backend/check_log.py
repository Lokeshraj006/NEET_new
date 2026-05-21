log_path = r"C:\Users\dines\.gemini\antigravity\brain\46205e72-dc84-428d-be03-27455bd71d78\.system_generated\logs\overview.txt"
with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
    for idx, line in enumerate(f, 1):
        if 'Online_NEET' in line or 'NEW_MOCK_TEST_PDF' in line:
            print(f"{idx}: {line[:150]}")
