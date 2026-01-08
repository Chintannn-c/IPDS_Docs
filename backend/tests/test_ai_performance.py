"""
Performance benchmark tests for IPDS AI system optimizations.
Run with: pytest tests/test_ai_performance.py -v -s
"""
import pytest
import time
from app.services.ai_service import AIService
from unittest.mock import patch
import os

# Sample test documents
SAMPLE_SHORT_TEXT = """
This is a technical documentation about machine learning algorithms.
It covers neural networks, decision trees, and ensemble methods.
The document provides implementation examples and best practices.
"""

SAMPLE_MEDIUM_TEXT = """
Executive Summary

This quarterly report provides a comprehensive overview of our security operations 
and threat detection systems. During Q4 2025, we successfully mitigated 127 security
incidents and improved our response time by 34%.

Key Achievements:
- Implemented advanced threat detection using AI
- Reduced false positive rate from 12% to 4%
- Deployed new intrusion prevention system across 3 data centers
- Completed security audits for all critical systems

Security Metrics:
- Average response time: 4.2 minutes (down from 6.5 minutes)
- Detection accuracy: 96.3% (up from 91.2%)
- Zero-day vulnerabilities patched: 15
- User security training completion: 98%

Financial Impact:
The security improvements resulted in estimated cost savings of $2.3M through
reduced incident response times and prevention of potential breaches.

Next Quarter Goals:
1. Implement automated threat response for low-severity incidents
2. Expand AI-powered anomaly detection to network traffic
3. Complete ISO 27001 certification process
4. Deploy multi-factor authentication enterprise-wide
""" * 3  # Repeat to create longer text

@pytest.mark.skipif(not os.getenv("MISTRAL_API_KEY"), reason="Requires MISTRAL_API_KEY")
class TestAIPerformance:
    
    def test_short_document_analysis_speed(self):
        """Test analysis speed for short documents."""
        start = time.time()
        result = AIService.analyze_document(SAMPLE_SHORT_TEXT)
        elapsed = time.time() - start
        
        print(f"\n[PERF] Short doc analysis: {elapsed:.2f}s")
        
        # Should complete in under 5 seconds with new optimizations
        assert elapsed < 5.0, f"Analysis took {elapsed:.2f}s, expected < 5s"
        assert result is not None
        assert "summary" in result
        assert "key_points" in result
    
    def test_medium_document_analysis_speed(self):
        """Test analysis speed for medium-sized documents."""
        start = time.time()
        result = AIService.analyze_document(SAMPLE_MEDIUM_TEXT)
        elapsed = time.time() - start
        
        print(f"\n[PERF] Medium doc analysis: {elapsed:.2f}s")
        
        # Should complete in under 8 seconds with optimizations
        assert elapsed < 8.0, f"Analysis took {elapsed:.2f}s, expected < 8s"
        assert result is not None
        assert len(result.get("key_points", [])) >= 3
    
    def test_json_parsing_reliability(self):
        """Test that JSON parsing is reliable and fast."""
        successes = 0
        total_time = 0
        iterations = 3
        
        for i in range(iterations):
            start = time.time()
            try:
                result = AIService.analyze_document(SAMPLE_SHORT_TEXT)
                if result and "summary" in result:
                    successes += 1
                total_time += time.time() - start
            except Exception as e:
                print(f"[PERF] Iteration {i+1} failed: {e}")
        
        success_rate = (successes / iterations) * 100
        avg_time = total_time / iterations
        
        print(f"\n[PERF] JSON parse success rate: {success_rate:.1f}%")
        print(f"[PERF] Average time: {avg_time:.2f}s")
        
        # Should have >90% success rate with improved parsing
        assert success_rate >= 90, f"Success rate {success_rate}% < 90%"
    
    def test_security_validation(self):
        """Test that security validation works correctly."""
        # Document with potential security risks
        risky_text = """
        API Configuration:
        
        AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
        AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
        
        Database connection string:
        mongodb://admin:password123@localhost:27017/production
        
        Personal Information:
        John Doe - SSN: 123-45-6789
        Email: john.doe@company.com
        Phone: (555) 123-4567
        """
        
        result = AIService.analyze_document(risky_text)
        
        print(f"\n[PERF] Security flags detected: {result.get('risk_flags', [])}")
        
        # Should detect security issues
        assert result is not None
        risk_flags = result.get("risk_flags", [])
        
        # Should detect at least one of: leaked_credentials, pii, config_leak
        has_security_detection = any(
            flag in risk_flags 
            for flag in ["leaked_credentials", "pii", "config_leak"]
        )
        assert has_security_detection, f"Failed to detect security risks: {risk_flags}"
        
        # Validate risk flags are from valid set
        from app.services.ai_service import VALID_RISK_FLAGS
        for flag in risk_flags:
            assert flag in VALID_RISK_FLAGS, f"Invalid risk flag: {flag}"
    
    def test_note_summarization_speed(self):
        """Test note summarization speed."""
        note_text = """
        Meeting Notes - Product Planning Session
        Date: January 8, 2026
        
        Attendees: Sarah (PM), Mike (Eng), Lisa (Design)
        
        Agenda:
        1. Q1 Roadmap Review
        2. New Feature Proposals
        3. Technical Debt Discussion
        
        Key Decisions:
        - Prioritize mobile app performance improvements
        - Delay social features until Q2
        - Allocate 20% of sprint capacity to tech debt
        - Hire 2 additional backend engineers
        
        Action Items:
        - Sarah: Draft updated roadmap by Friday
        - Mike: Provide tech debt assessment
        - Lisa: Create mockups for dashboard redesign
        
        Next meeting scheduled for January 15, 2026
        """
        
        start = time.time()
        result = AIService.summarize_note_structured(note_text)
        elapsed = time.time() - start
        
        print(f"\n[PERF] Note summarization: {elapsed:.2f}s")
        
        # Note summarization should be fast (<4s)
        assert elapsed < 4.0, f"Summarization took {elapsed:.2f}s, expected < 4s"
        assert result is not None
        assert "summary_paragraph" in result
        assert "bullet_points" in result
        assert "keywords" in result
        assert len(result["bullet_points"]) >= 3

if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
