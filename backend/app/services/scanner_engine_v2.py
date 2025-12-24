"""
Enhanced File Scanner v2.0
Advanced malware detection and file safety scoring.
"""
import re
import hashlib
import mimetypes
from typing import Dict, Any, List, Tuple
from enum import Enum


class ThreatLevel(Enum):
    SAFE = "safe"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class ScannerEngineV2:
    """
    Enhanced file scanning engine with multiple detection methods:
    - Pattern matching for malicious code
    - File type validation
    - Signature-based detection
    - Entropy analysis (for packed/encrypted malware)
    - Known malware hash checking
    """
    
    # Suspicious patterns with severity weights
    SUSPICIOUS_PATTERNS: List[Tuple[str, int, str]] = [
        # Code execution (High Risk)
        (r"eval\s*\(", 35, "Code execution: eval()"),
        (r"exec\s*\(", 35, "Code execution: exec()"),
        (r"os\.system\s*\(", 40, "System command execution"),
        (r"subprocess\.", 25, "Subprocess execution"),
        (r"shell\s*=\s*True", 30, "Shell command execution"),
        
        # Web attacks (Medium-High Risk)
        (r"<script[^>]*>", 30, "Embedded JavaScript (XSS risk)"),
        (r"javascript:", 25, "JavaScript protocol"),
        (r"on\w+\s*=", 20, "Event handler (XSS risk)"),
        (r"document\.cookie", 30, "Cookie access attempt"),
        (r"document\.write", 20, "Document manipulation"),
        
        # SQL Injection patterns
        (r"(?:'|\")\s*(?:OR|AND)\s*(?:'|\")\s*=\s*(?:'|\")", 35, "SQL injection pattern"),
        (r"UNION\s+SELECT", 35, "SQL UNION injection"),
        (r"DROP\s+TABLE", 50, "SQL DROP TABLE command"),
        (r"--\s*$", 15, "SQL comment injection"),
        
        # Windows specific (High Risk)
        (r"cmd\.exe", 45, "Windows command prompt"),
        (r"powershell", 40, "PowerShell execution"),
        (r"\.bat\s*$", 30, "Batch file reference"),
        (r"\.ps1\s*$", 35, "PowerShell script reference"),
        (r"regsvr32", 40, "DLL registration"),
        (r"mshta", 45, "HTML Application host"),
        
        # Network operations (Medium Risk)
        (r"socket\.", 20, "Network socket usage"),
        (r"urllib", 15, "URL library usage"),
        (r"requests\.", 10, "HTTP requests library"),
        (r"ftplib", 20, "FTP operations"),
        
        # File operations (Medium Risk)
        (r"shutil\.rmtree", 35, "Recursive file deletion"),
        (r"os\.remove", 20, "File deletion"),
        (r"open\s*\([^)]*['\"]w['\"]", 15, "File write operation"),
        
        # Encoding/Obfuscation (Suspicious)
        (r"base64\.b64decode", 20, "Base64 decoding (potential obfuscation)"),
        (r"\\x[0-9a-fA-F]{2}", 15, "Hex-encoded content"),
        (r"chr\s*\(\s*\d+\s*\)", 20, "Character code conversion"),
        
        # Explicit malware keywords (Critical)
        (r"\bvirus\b", 100, "Explicit virus keyword"),
        (r"\bmalware\b", 100, "Explicit malware keyword"),
        (r"\btrojan\b", 100, "Explicit trojan keyword"),
        (r"\brootkit\b", 100, "Explicit rootkit keyword"),
        (r"\bkeylogger\b", 100, "Explicit keylogger keyword"),
        (r"\bransomware\b", 100, "Explicit ransomware keyword"),
        (r"\bbackdoor\b", 80, "Backdoor reference"),
        (r"\bexploit\b", 60, "Exploit reference"),
    ]
    
    # Dangerous file extensions
    DANGEROUS_EXTENSIONS = {
        # Executables
        ".exe": 80, ".com": 80, ".bat": 70, ".cmd": 70,
        ".msi": 60, ".scr": 80, ".pif": 80,
        
        # Scripts
        ".ps1": 70, ".vbs": 70, ".vbe": 70, ".js": 40,
        ".jse": 70, ".wsf": 70, ".wsh": 70,
        
        # Office macros
        ".docm": 50, ".xlsm": 50, ".pptm": 50,
        
        # Archives (can hide malware)
        ".iso": 40, ".img": 40,
        
        # Others
        ".dll": 60, ".sys": 70, ".drv": 70,
        ".hta": 80, ".cpl": 70, ".msc": 60,
    }
    
    # Known malware hashes (simplified - use VirusTotal API in production)
    KNOWN_MALWARE_HASHES = {
        # Example hashes - in production, use a proper malware database
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855": "Empty file hash (suspicious if executable)",
    }
    
    @classmethod
    def scan_file(
        cls, 
        content: bytes, 
        filename: str = None,
        mime_type: str = None
    ) -> Dict[str, Any]:
        """
        Comprehensive file scan.
        
        Returns:
            {
                "safety_score": int (0-100, 100 = safe),
                "threat_level": ThreatLevel,
                "findings": List[dict],
                "file_info": dict,
                "recommendation": str
            }
        """
        findings = []
        total_penalty = 0
        
        # 1. File hash check
        file_hash = hashlib.sha256(content).hexdigest()
        if file_hash in cls.KNOWN_MALWARE_HASHES:
            findings.append({
                "type": "known_malware",
                "severity": "critical",
                "description": cls.KNOWN_MALWARE_HASHES[file_hash],
                "penalty": 100
            })
            total_penalty += 100
        
        # 2. Extension check
        if filename:
            ext = "." + filename.split(".")[-1].lower() if "." in filename else ""
            if ext in cls.DANGEROUS_EXTENSIONS:
                penalty = cls.DANGEROUS_EXTENSIONS[ext]
                findings.append({
                    "type": "dangerous_extension",
                    "severity": "high" if penalty >= 60 else "medium",
                    "description": f"Potentially dangerous file type: {ext}",
                    "penalty": penalty
                })
                total_penalty += penalty
        
        # 3. MIME type validation
        if mime_type and filename:
            expected_type = mimetypes.guess_type(filename)[0]
            if expected_type and mime_type != expected_type:
                findings.append({
                    "type": "mime_mismatch",
                    "severity": "medium",
                    "description": f"File extension doesn't match content type",
                    "penalty": 25
                })
                total_penalty += 25
        
        # 4. Content pattern analysis
        try:
            content_str = content.decode('utf-8', errors='ignore').lower()
            
            for pattern, penalty, description in cls.SUSPICIOUS_PATTERNS:
                matches = re.findall(pattern, content_str, re.IGNORECASE)
                if matches:
                    # Limit penalty escalation
                    adjusted_penalty = min(penalty * len(matches), penalty * 3)
                    findings.append({
                        "type": "suspicious_pattern",
                        "severity": cls._severity_from_penalty(penalty),
                        "description": description,
                        "match_count": len(matches),
                        "penalty": adjusted_penalty
                    })
                    total_penalty += adjusted_penalty
        except Exception:
            pass
        
        # 5. Entropy analysis (high entropy = possibly encrypted/packed)
        entropy = cls._calculate_entropy(content)
        if entropy > 7.5:  # Very high entropy
            findings.append({
                "type": "high_entropy",
                "severity": "medium",
                "description": f"High entropy ({entropy:.2f}) - possibly encrypted or packed",
                "penalty": 20
            })
            total_penalty += 20
        
        # 6. Calculate final score
        safety_score = max(0, 100 - total_penalty)
        threat_level = cls._determine_threat_level(safety_score)
        
        # 7. Generate recommendation
        recommendation = cls._generate_recommendation(safety_score, findings)
        
        return {
            "safety_score": safety_score,
            "threat_level": threat_level.value,
            "findings": findings,
            "findings_count": len(findings),
            "file_info": {
                "size": len(content),
                "hash_sha256": file_hash,
                "entropy": round(entropy, 2),
                "filename": filename,
                "mime_type": mime_type
            },
            "recommendation": recommendation
        }
    
    @classmethod
    def quick_scan(cls, content: bytes) -> int:
        """
        Quick scan returning only the safety score.
        Faster but less detailed.
        """
        result = cls.scan_file(content)
        return result["safety_score"]
    
    @staticmethod
    def _calculate_entropy(data: bytes) -> float:
        """Calculate Shannon entropy of the data."""
        import math
        
        if not data:
            return 0.0
        
        # Count byte frequencies
        freq = [0] * 256
        for byte in data:
            freq[byte] += 1
        
        # Calculate entropy
        length = len(data)
        entropy = 0.0
        for count in freq:
            if count > 0:
                probability = count / length
                entropy -= probability * math.log2(probability)
        
        return entropy
    
    @staticmethod
    def _severity_from_penalty(penalty: int) -> str:
        """Convert penalty to severity level."""
        if penalty >= 80:
            return "critical"
        elif penalty >= 50:
            return "high"
        elif penalty >= 30:
            return "medium"
        return "low"
    
    @staticmethod
    def _determine_threat_level(safety_score: int) -> ThreatLevel:
        """Determine threat level from safety score."""
        if safety_score >= 90:
            return ThreatLevel.SAFE
        elif safety_score >= 70:
            return ThreatLevel.LOW
        elif safety_score >= 50:
            return ThreatLevel.MEDIUM
        elif safety_score >= 30:
            return ThreatLevel.HIGH
        return ThreatLevel.CRITICAL
    
    @staticmethod
    def _generate_recommendation(safety_score: int, findings: list) -> str:
        """Generate human-readable recommendation."""
        if safety_score >= 90:
            return "File appears safe. No action required."
        elif safety_score >= 70:
            return "File has minor concerns. Review findings before use."
        elif safety_score >= 50:
            return "File has moderate risk. Manual review recommended."
        elif safety_score >= 30:
            return "File has significant risks. Quarantine recommended."
        return "File is highly suspicious. Block and investigate."


# Singleton instance
scanner = ScannerEngineV2()
