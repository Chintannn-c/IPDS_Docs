"""
Quick manual verification script for AI optimizations.
Run with: python verify_optimizations.py
"""
import sys
import os
import time

# Add backend to path
sys.path.insert(0, os.path.dirname(__file__))

from app.services.ai_service import AIService
from app.core.config import settings

def main():
    print("="*60)
    print("IPDS AI System Optimization Verification")
    print("="*60)
    
    # Check configuration
    print("\n1. Configuration Check:")
    print(f"   ✓ Standard Model: {settings.AI_MODEL_STANDARD}")
    print(f"   ✓ Advanced Model: {settings.AI_MODEL_ADVANCED}")
    print(f"   ✓ Temperature: {settings.AI_TEMPERATURE}")
    print(f"   ✓ Max Tokens: {settings.AI_MAX_TOKENS}")
    print(f"   ✓ OCR Parallel Pages: {settings.OCR_PARALLEL_PAGES}")
    
    # Test document
    test_doc = """
    Technical Report: Cloud Security Best Practices
    
    Executive Summary:
    This document outlines enterprise cloud security standards including
    encryption, access control, and network segmentation. Key recommendations
    include implementing zero-trust architecture, multi-factor authentication,
    and continuous monitoring of cloud resources.
    
    Security Controls:
    - Data encryption at rest and in transit (AES-256)
    - Role-based access control (RBAC)
    - Network micro-segmentation
    - Automated vulnerability scanning
    - Incident response automation
    
    Compliance:
    The framework aligns with ISO 27001, SOC 2, and GDPR requirements.
    """
    
    print("\n2. Speed Test:")
    print("   Testing document analysis...")
    
    api_key_set = bool(os.getenv("MISTRAL_API_KEY"))
    if not api_key_set:
        print("   ⚠ MISTRAL_API_KEY not set - skipping AI test")
        print("   Set MISTRAL_API_KEY environment variable to test AI analysis")
    else:
        try:
            start = time.time()
            result = AIService.analyze_document(test_doc)
            elapsed = time.time() - start
            
            print(f"   ✓ Analysis completed in {elapsed:.2f}s")
            print(f"   ✓ Summary generated: {len(result.get('summary', '')) > 0}")
            print(f"   ✓ Key points: {len(result.get('key_points', []))}")
            print(f"   ✓ Confidence: {result.get('analysis_confidence', 'unknown')}")
            
            if elapsed < 8:
                print(f"   ✓ PASS: Speed within target (<8s)")
            else:
                print(f"   ⚠ SLOW: Took {elapsed:.2f}s (target: <8s)")
            
        except Exception as e:
            print(f"   ✗ Error: {e}")
    
    print("\n3. Security Validation Test:")
    risky_doc = """
    Configuration File:
    
    AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
    AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCY
    
    User Info:
    SSN: 123-45-6789
    Email: admin@company.com
    """
    
    if api_key_set:
        try:
            result = AIService.analyze_document(risky_doc)
            risk_flags = result.get('risk_flags', [])
            
            print(f"   ✓ Risk flags detected: {risk_flags}")
            
            # Check for expected security categories
            from app.services.ai_service import VALID_RISK_FLAGS
            has_credentials = any('credential' in flag or 'pii' in flag or 'config' in flag for flag in risk_flags)
            
            if has_credentials:
                print("   ✓ PASS: Security detection working")
            else:
                print("   ⚠ WARNING: Expected security flags not detected")
                
        except Exception as e:
            print(f"   ✗ Error: {e}")
    
    print("\n" + "="*60)
    print("Verification Complete!")
    print("="*60)
    
    if not api_key_set:
        print("\nNOTE: Set MISTRAL_API_KEY to run full AI tests")
    
if __name__ == "__main__":
    main()
