import os
import json
import google.generativeai as genai
from groq import Groq
from mistralai import Mistral
import requests
from dotenv import load_dotenv

load_dotenv()

def list_groq_models():
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key: return ["Groq API Key missing"]
    try:
        client = Groq(api_key=api_key)
        models = client.models.list()
        return [m.id for m in models.data]
    except Exception as e:
        return [f"Groq error: {e}"]

def list_gemini_models():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key: return ["Gemini API Key missing"]
    try:
        genai.configure(api_key=api_key)
        models = genai.list_models()
        return [m.name for m in models]
    except Exception as e:
        return [f"Gemini error: {e}"]

def list_mistral_models():
    api_key = os.getenv("MISTRAL_API_KEY")
    if not api_key: return ["Mistral API Key missing"]
    try:
        client = Mistral(api_key=api_key)
        models = client.models.list()
        return [m.id for m in models.data]
    except Exception as e:
        return [f"Mistral error: {e}"]

def list_openrouter_models():
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key: return ["OpenRouter API Key missing"]
    try:
        response = requests.get("https://openrouter.ai/api/v1/models")
        if response.status_code == 200:
            data = response.json()
            return [m['id'] for m in data['data'][:20]] # Just top 20
        return [f"OpenRouter status: {response.status_code}"]
    except Exception as e:
        return [f"OpenRouter error: {e}"]

if __name__ == "__main__":
    print("--- GROQ MODELS ---")
    print("\n".join(list_groq_models()))
    print("\n--- GEMINI MODELS ---")
    print("\n".join(list_gemini_models()))
    print("\n--- MISTRAL MODELS ---")
    print("\n".join(list_mistral_models()))
    print("\n--- OPENROUTER MODELS (Top 20) ---")
    print("\n".join(list_openrouter_models()))
