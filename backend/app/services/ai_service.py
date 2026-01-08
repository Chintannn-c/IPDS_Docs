import json
import os
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from mistralai import Mistral
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
    @staticmethod
    def analyze_document(text: str) -> dict:
        """
        Analyzes document text using Mistral AI with enhanced security rules.
        """
        api_key = os.getenv("MISTRAL_API_KEY")
        if not api_key:
            return {
                "summary": None,
                "key_points": [],
                "risk_flags": ["configuration_error"],
                "content_preview": "System AI analysis unavailable: Missing API key.",
                "analysis_confidence": "low",
                "security_status": "safe"
            }

        client = Mistral(api_key=api_key)
        # Use faster model for standard analysis (3-4x speed improvement)
        model = settings.AI_MODEL_STANDARD

        system_prompt = """
You are an intelligent document summarization AI for IPDS.

Your task is to generate a summary whose length and depth are dynamically proportional
to the size, complexity, and information density of the provided document content.

ADAPTIVE RULES (CRITICAL):
1. Do NOT use a fixed word or line limit.
2. First estimate the document size using text length and topic density.
3. Adjust summary length automatically:
   - Very small content → very short summary
   - Medium content → moderate summary
   - Large content → detailed, multi-paragraph summary
4. Preserve all key ideas, sections, and important details.
5. Never add information that does not exist in the document.
6. Handle OCR noise logically without inventing missing text.
7. Maintain factual accuracy over creativity.

SUMMARY DEPTH GUIDELINES:
- < 500 words input → 3–5 sentence summary
- 500–2,000 words → 1–2 short paragraphs
- 2,000–8,000 words → multi-paragraph structured summary
- > 8,000 words → comprehensive section-wise summary

STRUCTURE RULES:
- For large documents, organize the summary by major sections or themes.
- For small documents, provide a compact and direct summary.
- Do not repeat information unnecessarily.

RETURN STRICT JSON:
{
  "estimated_document_size": "small | medium | large | very_large",
  "summary": "Adaptive-length summary based on document size",
  "key_points": ["Key insight 1", "Key insight 2", "Key insight 3"],
  "document_type": "lecture|report|policy|invoice|code|presentation|other",
  "detected_structure": "description of structure",
  "sensitivity_level": "Low|Medium|High",
  "risk_flags": ["leaked_credentials", "malware_code", "crypto_keys", "pii", "config_leak", "suspicious_commands", "phishing"] or [],
  "analysis_confidence": "high|medium|low",
  "security_status": "safe|suspicious|risky",
  "language": "detected language",
  "extraction_method": "Text-based|OCR|Mixed",
  "content_preview": "sanitized preview",
  "coverage_note": "Brief note on how much of the document is covered (e.g., high-level, detailed, comprehensive)"
}

SECURITY CATEGORIES (use exact strings):
- leaked_credentials: passwords, API keys, tokens, secrets
- malware_code: exploit code, malicious scripts
- crypto_keys: hardcoded encryption keys
- pii: personal identifiable information
- config_leak: infrastructure/config exposure
- suspicious_commands: harmful CLI instructions
- phishing: social engineering indicators

CONSTRAINTS:
- No markdown in summary
- No explanations
- No fixed word counts
- No hallucinations
- Output must be valid JSON only
"""

        try:
            print(f"DEBUG: Sending {len(text)} characters to System AI...")
            response = client.chat.complete(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f"DOCUMENT CONTENT:\n{text}"}
                ],
                response_format={"type": "json_object"},
                temperature=settings.AI_TEMPERATURE,  # More deterministic
                top_p=settings.AI_TOP_P,              # Focused outputs
                max_tokens=settings.AI_MAX_TOKENS     # Limit for speed
            )
            
            content = response.choices[0].message.content
            print(f"DEBUG: Raw Response: {content[:200]}...")  # Log first 200 chars only

            # Optimized JSON parsing - direct parse first
            try:
                result = json.loads(content)
                # Validate and normalize security flags
                return _validate_analysis_result(result)
            except json.JSONDecodeError:
                # Fallback: strip markdown code blocks
                if "```json" in content:
                    content = content.split("```json")[1].split("```")[0].strip()
                elif "```" in content:
                    content = content.split("```")[1].split("```")[0].strip()
                try:
                    result = json.loads(content)
                    return _validate_analysis_result(result)
                except:
                    # Last resort: regex extraction
                    match = re.search(r'\{.*\}', content, re.DOTALL)
                    if match:
                        result = json.loads(match.group(0))
                        return _validate_analysis_result(result)
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
        Uses parallel processing for faster analysis.
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

        # Parallel AI processing for faster analysis
        
        def analyze_chunk(chunk_index, chunk_text):
            """Process a single chunk (thread-safe)."""
            try:
                print(f"DEBUG: Processing chunk {chunk_index+1}/{len(chunks)}...")
                result = AIService.analyze_document(chunk_text)
                return chunk_index, result
            except Exception as e:
                print(f"ERROR: Chunk {chunk_index+1} analysis failed: {e}")
                return chunk_index, {
                    "summary": "",
                    "key_points": [],
                    "risk_flags": [],
                    "analysis_confidence": "low"
                }
        
        # Process up to 3 chunks concurrently for faster analysis
        max_workers = min(3, len(chunks))
        chunk_results_dict = {}
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {executor.submit(analyze_chunk, i, chunk): i for i, chunk in enumerate(chunks)}
            for future in as_completed(futures):
                chunk_index, result = future.result()
                chunk_results_dict[chunk_index] = result
        
        # Reconstruct results in correct order
        chunk_results = [chunk_results_dict[i] for i in range(len(chunks))]

        # Merge Results
        combined_risk_flags = list(set([flag for res in chunk_results for flag in res.get("risk_flags", [])]))
        
        # Combine summaries for AI merging
        combined_summaries = "\n\n".join([f"Part {i+1}: {res.get('summary', '')}" for i, res in enumerate(chunk_results)])
        
        # Combine all key points from chunks
        all_key_points = []
        for res in chunk_results:
            all_key_points.extend(res.get("key_points", []))
        
        # Get content preview from first chunk
        content_preview = chunk_results[0].get("content_preview", "") if chunk_results else ""
        
        # Merge summaries using AI
        print("DEBUG: Merging chunk summaries...")
        merge_prompt = f"""
    Below are summaries and key points from different parts of a large document. 
    Create a single, cohesive summary and consolidate the key points into 6-10 unique insights.
    Remove duplicates and maintain the most important information.

    SUMMARIES:
    {combined_summaries}
    
    KEY POINTS FROM ALL PARTS:
    {chr(10).join([f"- {point}" for point in all_key_points[:30]])}
    
    Return JSON with 'summary' (adaptive length) and 'key_points' (6-10 unique consolidated points).
    """

        try:
            api_key = os.getenv("MISTRAL_API_KEY")
            client = Mistral(api_key=api_key)
            # Use advanced model for complex merging task
            response = client.chat.complete(
                model=settings.AI_MODEL_ADVANCED,
                messages=[
                    {"role": "system", "content": "You are a senior analyst merging document reports. Return JSON with 'summary' and 'key_points'."},
                    {"role": "user", "content": merge_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.4  # Slightly higher for creative merging
            )
            merged_data = json.loads(response.choices[0].message.content)
            
            return {
                "summary": merged_data.get("summary", "Summary merge failed."),
                "key_points": merged_data.get("key_points", all_key_points[:10]),  # Fallback to combined points
                "risk_flags": combined_risk_flags,
                "content_preview": content_preview,
                "analysis_confidence": "medium",
                "security_status": chunk_results[0].get("security_status", "safe")
            }
        except Exception as e:
            print(f"ERROR: Failed to merge summaries: {e}")
            # Fallback: Use first chunk summary + combined key points
            return {
                "summary": chunk_results[0].get("summary", "") + "\n\n(Note: Full merge unavailable, showing primary analysis)",
                "key_points": all_key_points[:10],  # At least show combined key points
                "risk_flags": combined_risk_flags,
                "content_preview": content_preview,
                "analysis_confidence": "low",
                "security_status": "safe"
            }

    @staticmethod
    def summarize_note_structured(text: str) -> dict:
        """
        Generates a structured summary for notes with paragraph, bullets, and keywords.
        One-time summarization that keeps original intact.
        """
        api_key = os.getenv("MISTRAL_API_KEY")
        if not api_key:
            return {
                "summary_paragraph": "AI service unavailable",
                "bullet_points": [],
                "keywords": []
            }

        client = Mistral(api_key=api_key)
        # Use faster model for notes (simpler task)
        model = settings.AI_MODEL_STANDARD

        system_prompt = """You are an intelligent AI assistant designed to summarize plain text notes clearly and concisely. Your task is to generate a one-time summary for a given note while keeping the original text completely intact and unaltered.

First, provide a short paragraph summarizing the note in clear, readable language, capturing the main ideas and overall context.

Then, create 5 to 10 bullet points highlighting the most important information, actionable items, or key insights from the note.

Additionally, identify and list 3-7 important keywords that represent the main concepts or topics of the note.

Ensure that the summary is accurate, coherent, and professional, while preserving the meaning of the original text.

Return your response in the following JSON format:
{
  "summary_paragraph": "A concise paragraph summarizing the note...",
  "bullet_points": [
    "Key point 1",
    "Key point 2",
    "Key point 3"
  ],
  "keywords": ["keyword1", "keyword2", "keyword3"]
}

CRITICAL: Return ONLY valid JSON. No markdown, no code fences, just raw JSON."""

        try:
            response = client.chat.complete(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f"Note to summarize:\n\n{text}"}
                ],
                response_format={"type": "json_object"},
                temperature=settings.AI_TEMPERATURE,
                top_p=settings.AI_TOP_P
            )
            
            content = response.choices[0].message.content
            
            # Parse JSON response
            try:
                if "```json" in content:
                    content = content.split("```json")[1].split("```")[0].strip()
                elif "```" in content:
                    content = content.split("```")[1].split("```")[0].strip()
                
                result = json.loads(content)
                
                # Validate structure
                return {
                    "summary_paragraph": result.get("summary_paragraph", ""),
                    "bullet_points": result.get("bullet_points", []),
                    "keywords": result.get("keywords", [])
                }
            except json.JSONDecodeError:
                match = re.search(r'\{.*\}', content, re.DOTALL)
                if match:
                    result = json.loads(match.group(0))
                    return {
                        "summary_paragraph": result.get("summary_paragraph", ""),
                        "bullet_points": result.get("bullet_points", []),
                        "keywords": result.get("keywords", [])
                    }
                raise
            
        except Exception as e:
            print(f"ERROR: Note Summarization Failed: {e}")
            return {
                "summary_paragraph": "Failed to generate summary",
                "bullet_points": [],
                "keywords": []
            }
