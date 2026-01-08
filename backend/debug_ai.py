"""
Debug script to test AI analysis with full output
"""
import json
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

from app.services.ai_service import AIService

# Test text
test_text = """
The IPDS (Intelligent Personal Data System) is a secure cloud-based platform developed during an industrial internship. 
The system ensures data confidentiality, integrity, and usability through robust security measures, including user 
authentication, role-based access control (RBAC), encryption, and real-time risk detection. IPDS leverages AI and OCR 
technologies for document analysis, summarization, and intrusion prevention, while employing modern tools such as FastAPI, 
Flutter, MongoDB, and RESTful APIs. The platform is modular, scalable, and designed with a security-first approach, 
incorporating continuous monitoring, regular updates, and comprehensive data management practices.
"""

print("="*60)
print("TESTING AI ANALYSIS")
print("="*60)

result = AIService.analyze_document(test_text)

print("\n✓ Analysis complete!")
print("\nFull Result:")
print(json.dumps(result, indent=2, ensure_ascii=False))

print("\n" + "="*60)
print("KEY CHECK:")
print("="*60)
print(f"Summary exists: {bool(result.get('summary'))}")
print(f"Summary length: {len(result.get('summary', ''))} characters")
print(f"Key points count: {len(result.get('key_points', []))}")
print(f"Key points: {result.get('key_points', [])}")
print(f"Content preview length: {len(result.get('content_preview', ''))}")
