import os
from mistralai import Mistral
from app.core.config import settings
import json
import re

class AIService:
    @staticmethod
    def analyze_document(text: str) -> dict:
        """
        Analyzes document text using Mistral AI with enhanced security rules.
        """
        api_key = os.getenv("MISTRAL_API_KEY")
        if not api_key:
            return {
                "summary": null,
                "key_points": [],
                "risk_flags": ["configuration_error"],
                "content_preview": "System AI analysis unavailable: Missing API key.",
                "analysis_confidence": "low",
                "security_status": "safe"
            }

        client = Mistral(api_key=api_key)
        model = "mistral-large-latest"

        system_prompt = """
You are an AI component integrated into IPDS (Intrusion Prevention & Detection System),
a secure document storage and analysis platform.

SYSTEM CONSTRAINTS (MANDATORY):
- NEVER reveal document passwords, secrets, API keys, tokens, credentials, or private data.
- NEVER reproduce full document content verbatim.
- NEVER hallucinate text not present in extracted content.
- If content cannot be reliably extracted, state that clearly.
- Treat every document as sensitive enterprise data.

DOCUMENT PROCESSING RULES:
1. Attempt to analyze text extracted from the document.
2. If extracted text is EMPTY or UNREADABLE:
   - Assume the document is scanned, encrypted, or structurally complex.
   - Mark as "low" confidence and continue analysis.
3. If extraction fails completely:
   - DO NOT terminate or throw an error.
   - Provide metadata-based analysis only.

SECURITY-FIRST BEHAVIOR:
- Do not expose raw extracted text.
- Only provide abstracted insights.
- If suspicious indicators found: FLAG them without revealing exact content.
- If extraction is partial: Clearly state analysis limitations.

YOUR TASKS:
1. Analyze the document text provided.
2. Detect security risks (scripts, payloads, credentials, malware indicators).
3. Generate a concise summary (MAX 8 lines) if text confidence is sufficient.
4. Generate a list of at least 8-12 detailed key points covering the most important aspects.
5. Assign confidence: high | medium | low

OUTPUT FORMAT (STRICT JSON ONLY):
{
  "summary": "string or null",
  "key_points": ["string"],
  "risk_flags": ["string"],
  "content_preview": "string",
  "analysis_confidence": "high | medium | low",
  "security_status": "safe | suspicious | risky"
}

IMPORTANT:
- Never fail due to extraction issues.
- If text is empty, set summary to null and confidence to low.
- Accuracy and security override completeness.
"""

        try:
            print(f"DEBUG: Sending {len(text)} characters to System AI...")
            response = client.chat.complete(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f"DOCUMENT CONTENT:\n----------------\n{text}\n----------------"}
                ],
                response_format={"type": "json_object"}
            )
            
            content = response.choices[0].message.content
            print(f"DEBUG: Raw Response: {content}")

            # Robust JSON extraction
            try:
                if "```json" in content:
                    content = content.split("```json")[1].split("```")[0].strip()
                elif "```" in content:
                    content = content.split("```")[1].split("```")[0].strip()
                
                return json.loads(content)
            except json.JSONDecodeError:
                match = re.search(r'\{.*\}', content, re.DOTALL)
                if match:
                    return json.loads(match.group(0))
                raise
            
        except Exception as e:
            print(f"ERROR: System AI Analysis Failed: {e}")
            return {
                "summary": None,
                "key_points": ["Analysis failed - review backend logs"],
                "risk_flags": ["analysis_error"],
                "content_preview": "Unable to process document safely.",
                "analysis_confidence": "low",
                "security_status": "safe"
            }

    @staticmethod
    def analyze_document_chunked(text: str, chunk_size: int = 15000) -> dict:
        """
        Analyzes a large document by chunking it and merging results.
        """
        if len(text) <= chunk_size:
            return AIService.analyze_document(text)

        # Split into chunks
        chunks = [text[i:i + chunk_size] for i in range(0, len(text), chunk_size)]
        print(f"DEBUG: Large document detected ({len(text)} chars). Splitting into {len(chunks)} chunks...")

        # Limit to first 10 chunks
        chunks = chunks[:10]
        if len(chunks) == 10:
             print("DEBUG: Document is too large, limiting analysis to first 150,000 characters.")

        chunk_results = []
        for i, chunk in enumerate(chunks):
            print(f"DEBUG: Processing chunk {i+1}/{len(chunks)}...")
            result = AIService.analyze_document(chunk)
            chunk_results.append(result)

        # Merge Results
        combined_risk_flags = list(set([flag for res in chunk_results for flag in res.get("risk_flags", [])]))
        combined_summaries = "\n\n".join([f"Part {i+1}: {res.get('summary', '')}" for i, res in enumerate(chunk_results)])
        
        # Merge summaries using AI
        print("DEBUG: Merging chunk summaries...")
        merge_prompt = f"""
        Below are summaries from different parts of a large document. 
        Create a single, cohesive, enterprise-grade summary (concise) and a final set of unique key points.
        Maintain security standards (no secrets/PII).

        SUMMARIES:
        {combined_summaries}
        """

        try:
            api_key = os.getenv("MISTRAL_API_KEY")
            client = Mistral(api_key=api_key)
            response = client.chat.complete(
                model="mistral-large-latest",
                messages=[
                    {"role": "system", "content": "You are a senior security analyst merging document reports. Return JSON with 'summary' and 'key_points'."},
                    {"role": "user", "content": merge_prompt}
                ],
                response_format={"type": "json_object"}
            )
            merged_data = json.loads(response.choices[0].message.content)
            
            return {
                "summary": merged_data.get("summary", "Summary merge failed."),
                "key_points": merged_data.get("key_points", []),
                "risk_flags": combined_risk_flags,
                "content_preview": chunk_results[0].get("content_preview", ""),
                "analysis_confidence": "medium",
                "security_status": chunk_results[0].get("security_status", "safe")
            }
        except Exception as e:
            print(f"ERROR: System AI Failed to merge summaries: {e}")
            return {
                "summary": chunk_results[0].get("summary", "") + "... (Full summary merge failed)",
                "key_points": chunk_results[0].get("key_points", []),
                "risk_flags": combined_risk_flags,
                "content_preview": chunk_results[0].get("content_preview", ""),
                "analysis_confidence": "low",
                "security_status": "safe"
            }
