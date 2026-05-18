import sys
sys.path.insert(0, r'c:\Users\dines\Desktop\NEET\backend')
import app

query = "when the world war 4 happens"
print(f"Query: {query}")
print(f"is_neet_question: {app.is_neet_question(query)}")
print(f"\nFormatted reply:")
print(app.format_mistral_response("World War 4 is a hypothetical future conflict scenario.", query, False))
