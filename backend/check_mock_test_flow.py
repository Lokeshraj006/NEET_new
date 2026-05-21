with open('frontend/flutter_application_1/lib/screens/mock_test_flow.dart', 'r', encoding='utf-8', errors='ignore') as f:
    for idx, line in enumerate(f, 1):
        if 'initState' in line or '_load' in line or 'async' in line:
            if 'void ' in line or 'Future' in line or 'override' in line or 'fetch' in line:
                print(f"{idx}: {line.strip()}")
