import json
import os
import re
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from mistralai import Mistral
import google.generativeai as genai
from groq import Groq
from huggingface_hub import InferenceClient
from openai import OpenAI
from app.core.config import settings

# Valid security risk categories
VALID_RISK_FLAGS = {
    "leaked_credentials", "malware_code", "crypto_keys", "pii",
    "config_leak", "suspicious_commands", "phishing", 
    "configuration_error", "analysis_error"  # System errors
}

def _validate_analysis_result(result: dict) -> dict:
    """Validate and normalize AI analysis result for consistency and accuracy."""
    # Ensure risk_flags use valid categories only
    if "risk_flags" in result:
        valid_flags = [flag for flag in result["risk_flags"] if flag in VALID_RISK_FLAGS]
        result["risk_flags"] = valid_flags
    
    # Normalize confidence levels
    if "analysis_confidence" in result:
        confidence = str(result["analysis_confidence"]).lower()
        if confidence not in ["high", "medium", "low"]:
            result["analysis_confidence"] = "medium"
    
    # Normalize security status
    if "security_status" in result:
        status = str(result["security_status"]).lower()
        if status not in ["safe", "suspicious", "risky"]:
            result["security_status"] = "safe"
    
    return result

class AIService:
    # Model definitions (Absolute Best-in-Class Stack)
    MODELS = {
        "groq": "llama-3.3-70b-versatile",
        "gemini": "gemini-3.1-pro-preview",
        "mistral": "mistral-large-latest",
        "openrouter": "openai/gpt-5.5-pro", # The ultimate model found in current list
        "huggingface": "mistralai/Mistral-7B-Instruct-v0.2"
    }

    @staticmethod
    def _get_client(provider: str):
        """Initialize and return the client for the specified provider."""
        try:
            if provider == "groq":
                api_key = os.getenv("GROQ_API_KEY")
                return Groq(api_key=api_key) if api_key else None
            elif provider == "gemini":
                api_key = os.getenv("GEMINI_API_KEY")
                if api_key:
                    genai.configure(api_key=api_key)
                    return genai.GenerativeModel(AIService.MODELS["gemini"])
                return None
            elif provider == "mistral":
                api_key = os.getenv("MISTRAL_API_KEY")
                return Mistral(api_key=api_key) if api_key else None
            elif provider == "openrouter":
                api_key = os.getenv("OPENROUTER_API_KEY")
                return OpenAI(
                    base_url="https://openrouter.ai/api/v1",
                    api_key=api_key,
                ) if api_key else None
            elif provider == "huggingface":
                api_key = os.getenv("HUGGING_FACE_API_KEY")
                return InferenceClient(token=api_key) if api_key else None
        except Exception as e:
            print(f"ERROR initializing {provider} client: {e}")
            return None
        return None

    @staticmethod
    def _call_provider(provider: str, system_prompt: str, user_prompt: str) -> str:
        """Execute the AI call to a specific provider."""
        client = AIService._get_client(provider)
        if not client:
            raise ValueError(f"Provider {provider} not configured or missing API key.")

        model = AIService.MODELS.get(provider)
        
        start_time = time.time()
        print(f"🤖 [AI] Attempting call with {provider.upper()} ({model})...")

        if provider == "groq":
            response = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.2
            )
            content = response.choices[0].message.content
        
        elif provider == "gemini":
            # Gemini handles system prompt differently
            full_prompt = f"{system_prompt}\n\nUSER INPUT:\n{user_prompt}"
            response = client.generate_content(
                full_prompt,
                generation_config=genai.GenerationConfig(
                    response_mime_type="application/json",
                    temperature=0.2
                )
            )
            content = response.text
        
        elif provider == "mistral":
            response = client.chat.complete(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.2
            )
            content = response.choices[0].message.content
            
        elif provider == "openrouter":
            response = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.2
            )
            content = response.choices[0].message.content

        elif provider == "huggingface":
            # HF doesn't always support json_object in simpler ways, so we append instruction
            hf_prompt = f"<s>[INST] {system_prompt}\n\n{user_prompt} [/INST]"
            response = client.text_generation(
                hf_prompt,
                max_new_tokens=2048,
                temperature=0.2,
                model=model
            )
            content = response

        duration = time.time() - start_time
        print(f"✅ [AI] {provider.upper()} completed in {duration:.2f}s")
        return content

    @staticmethod
    def _orchestrate_ai(system_prompt: str, user_prompt: str) -> dict:
        """Proactive orchestration: Tries providers in order of preference (Failover)."""
        # Order: Groq (Fastest) -> Gemini (Reliable) -> Mistral (Stable) -> OpenRouter -> HF
        providers = ["groq", "gemini", "mistral", "openrouter", "huggingface"]
        
        last_error = None
        for provider in providers:
            try:
                content = AIService._call_provider(provider, system_prompt, user_prompt)
                
                # Optimized JSON parsing
                try:
                    # Clean up common markdown wrapping
                    if "```json" in content:
                        content = content.split("```json")[1].split("```")[0].strip()
                    elif "```" in content:
                        content = content.split("```")[1].split("```")[0].strip()
                    
                    result = json.loads(content)
                    result["used_model"] = f"{provider}:{AIService.MODELS[provider]}"
                    return _validate_analysis_result(result)
                except json.JSONDecodeError:
                    # Retry once with regex cleanup
                    match = re.search(r'\{.*\}', content, re.DOTALL)
                    if match:
                        result = json.loads(match.group(0))
                        result["used_model"] = f"{provider}:{AIService.MODELS[provider]}"
                        return _validate_analysis_result(result)
                    raise ValueError(f"Provider {provider} returned invalid JSON.")
                    
            except Exception as e:
                print(f"⚠️ [AI] {provider.upper()} failed: {e}")
                last_error = e
                continue # Try next provider

        print(f"🚨 [AI] ALL PROVIDERS FAILED. Last error: {last_error}")
        return {
            "summary": "AI Analysis Unavailable",
            "key_points": ["System exhausted all available AI models", "Check API keys and internet connection"],
            "risk_flags": ["analysis_error"],
            "content_preview": "Security analysis failed to initialize.",
            "analysis_confidence": "low",
            "security_status": "safe",
            "error": str(last_error)
        }

    @staticmethod
    def analyze_document(text: str) -> dict:
        """
        Analyzes document text using proactive multi-model orchestration.
        """
        system_prompt = """
You are an intelligent document summarization AI for IPDS.
Your task is to generate a summary whose length and depth are dynamically proportional to the document size.

ADAPTIVE RULES:
1. Estimate document size and adjust summary depth.
2. Structure: Small (<500 words) -> 3-5 sentences; Medium (500-2k) -> 1-2 paragraphs; Large (>2k) -> Detailed.
3. Identify security risks: leaked_credentials, malware_code, crypto_keys, pii, config_leak, suspicious_commands, phishing.

RETURN STRICT JSON ONLY:
{
  "estimated_document_size": "small | medium | large",
  "summary": "The adaptive summary",
  "key_points": ["Point 1", "Point 2", "Point 3"],
  "document_type": "type",
  "risk_flags": ["exact_flag_name"] or [],
  "analysis_confidence": "high|medium|low",
  "security_status": "safe|suspicious|risky",
  "content_preview": "sanitized snippet"
}
"""
        return AIService._orchestrate_ai(system_prompt, f"DOCUMENT CONTENT:\n{text}")

    @staticmethod
    def analyze_document_chunked(text: str, chunk_size: int = 15000) -> dict:
        """
        Analyzes large documents by chunking and merging with failover support.
        """
        if len(text) <= chunk_size:
            return AIService.analyze_document(text)

        chunks = [text[i:i + chunk_size] for i in range(0, len(text), chunk_size)][:10]
        
        def analyze_chunk(idx, chunk):
            return AIService.analyze_document(chunk)

        chunk_results = []
        with ThreadPoolExecutor(max_workers=3) as executor:
            futures = {executor.submit(analyze_chunk, i, c): i for i, c in enumerate(chunks)}
            for future in as_completed(futures):
                chunk_results.append(future.result())

        # Merge Logic
        combined_summaries = "\n\n".join([f"Part {i+1}: {res.get('summary', '')}" for i, res in enumerate(chunk_results)])
        merge_prompt = f"Consolidate these summaries and key points into a cohesive report.\n\nSUMMARIES:\n{combined_summaries}"
        
        merge_system_prompt = "You are a senior analyst merging document reports. Return JSON with 'summary' and 'key_points'."
        
        merged = AIService._orchestrate_ai(merge_system_prompt, merge_prompt)
        
        # Aggregate other fields
        merged["risk_flags"] = list(set([flag for res in chunk_results for flag in res.get("risk_flags", [])]))
        merged["content_preview"] = chunk_results[0].get("content_preview", "")
        return merged

    @staticmethod
    def summarize_note_structured(text: str) -> dict:
        """
        Structured note summarization with failover support.
        """
        system_prompt = """
Summarize the note. Return JSON:
{
  "summary_paragraph": "Clear summary...",
  "bullet_points": ["Point 1", "Point 2"],
  "keywords": ["key1", "key2"]
}
"""
        return AIService._orchestrate_ai(system_prompt, f"Note content:\n{text}")

