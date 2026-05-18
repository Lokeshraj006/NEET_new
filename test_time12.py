import sys
sys.path.insert(0, r'c:\Users\dines\Desktop\NEET\backend')
import app

query = "when the time 12 comes .what is the answer"
print(f"Query: {query}")
print(f"is_neet_question: {app.is_neet_question(query)}")
print(f"\nFormatted reply:")
reply = app.format_mistral_response("The time 12 refers to noon or midnight.", query, False)
print(reply)
