import sys
sys.path.insert(0, r'c:\Users\dines\Desktop\NEET\backend')
import app

query = "how can i meet you"
print(f"Query: {query}")
print(f"is_neet_question: {app.is_neet_question(query)}")
print(f"\nFormatted reply:")
reply = app.format_mistral_response("I am an AI chatbot here to help with NEET questions.", query, False)
print(reply)
