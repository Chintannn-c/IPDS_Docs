import re

class ScannerEngine:
    @staticmethod
    def scan_file(content: bytes) -> int:
        """
        Scans file content for suspicious patterns.
        Returns a safety score from 0 (High Risk) to 100 (Safe).
        """
        score = 100
        content_str = ""
        
        try:
            # Try to decode as text for keyword searching
            content_str = content.decode('utf-8', errors='ignore').lower()
        except Exception:
            pass
            
        # Suspicious keywords/patterns
        suspicious_patterns = [
            (r"eval\(", 30),      # High risk
            (r"exec\(", 30),      # High risk
            (r"os\.system", 40),  # High risk
            (r"subprocess", 20),  # Medium risk
            (r"<script>", 20),    # XSS risk
            (r"javascript:", 20), # XSS risk
            (r"cmd\.exe", 50),    # High risk
            (r"powershell", 40),  # High risk
            (r"virus", 100),      # Explicit keyword (for demo)
            (r"malware", 100),    # Explicit keyword (for demo)
            (r"trojan", 100),     # Explicit keyword (for demo)
        ]
        
        for pattern, penalty in suspicious_patterns:
            if re.search(pattern, content_str):
                score -= penalty
                
        return max(0, score)
