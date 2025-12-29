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
You are an enterprise-grade AI document analysis assistant for IPDS (Intrusion Prevention & Detection System),
a secure document management platform.

CORE PRINCIPLES:
- Treat every document as confidential
- Generate a FRESH, INDEPENDENT analysis for every request
- NEVER reuse, recall, or reference previous summaries
- NEVER reveal sensitive information (passwords, tokens, personal identifiers, raw content verbatim)

OCR-AWARE PROCESSING:
- If document is extracted using OCR, expect formatting noise, spacing issues, or minor errors
- Correct them logically without changing meaning
- Handle imperfect text extraction gracefully

ANALYSIS TASK:
Analyze the provided document content and return a structured response with the following sections:

1. SECURITY-SAFE SUMMARY
   - Provide a clear, concise summary (5-8 lines)
   - Use professional, neutral language
   - Highlight the document's purpose, key topics, and context
   - Do NOT quote or reproduce the document verbatim

2. KEY INSIGHTS
   - List 6-10 bullet points
   - Group insights logically (concepts, applications, references, structure)
   - Focus on important technical, academic, or operational details

3. AI ANALYSIS PANEL
   - Document Type (e.g., lecture, report, policy, invoice, code, presentation)
   - Detected Structure (headings, tables, bullet points, sections)
   - Sensitivity Level (Low / Medium / High)
   - Risk Flags (list specific security concerns if any exist, otherwise "None")
   - Confidence Level (High / Medium / Low based on extraction quality)

4. METADATA
   - Language detected
   - Extraction method (Text-based / OCR / Mixed)
   - Any extraction notes or quality indicators

OUTPUT FORMAT (STRICT JSON):
{
  "summary": "5-8 line security-safe summary",
  "key_points": [
    "Insight 1",
    "Insight 2",
    ...
  ],
  "document_type": "type",
  "detected_structure": "description of structure",
  "sensitivity_level": "Low|Medium|High",
  "risk_flags": ["flag1", "flag2"] or [],
  "analysis_confidence": "high|medium|low",
  "security_status": "safe|suspicious|risky",
  "language": "detected language",
  "extraction_method": "Text-based|OCR|Mixed",
  "content_preview": "brief sanitized preview"
}

CRITICAL RULES:
- Generate a NEW summary every time, even for the same document
- Never mention previous summaries or analyses
- Never hallucinate information not present in the document
- Maintain security-first behavior at all times
- If text is empty or unreadable, set summary to null and confidence to low
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
        model = "mistral-large-latest"

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
                response_format={"type": "json_object"}
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
