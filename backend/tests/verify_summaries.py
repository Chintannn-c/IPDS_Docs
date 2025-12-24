import requests
import json

BASE_URL = "http://localhost:8000" # Adjusted to match user's terminal output if possible, but 8000 is default for uvicorn in prompt logic usually. User's terminal says 8000 for ngrok.

# I need a valid token to test. 
# Since I can't easily get a token without login, and I don't have user credentials,
# I'll rely on the fact that the logic is straightforward and I've reviewed it carefully.
# However, I can check if the server is running and the router is registered.

def check_router():
    try:
        response = requests.get(f"{BASE_URL}/")
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        
        # Check docs to see if /summaries is there
        docs = requests.get(f"{BASE_URL}/openapi.json").json()
        paths = docs.get("paths", {})
        summary_paths = [p for p in paths if p.startswith("/summaries")]
        print(f"Summary paths found: {summary_paths}")
        return len(summary_paths) > 0
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    check_router()
