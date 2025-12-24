"""
IPDS Core Security Module
Contains rate limiting, encryption, and utility functions.
"""
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import hashlib
import os
import json
from functools import wraps

from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64

# ============================================
# ENCRYPTION UTILITIES
# ============================================

class AuditLogEncryption:
    """
    Handles encryption/decryption of sensitive audit log data.
    Uses Fernet (AES-128-CBC) with PBKDF2 key derivation.
    """
    
    def __init__(self, secret_key: str = None):
        if secret_key is None:
            secret_key = os.environ.get("ENCRYPTION_KEY", "default-secret-key-change-in-production")
        
        # Derive a proper key from the secret
        salt = b'ipds_audit_salt_v1'  # Fixed salt for consistency
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(secret_key.encode()))
        self._fernet = Fernet(key)
    
    def encrypt(self, data: Dict[str, Any]) -> bytes:
        """Encrypt a dictionary to bytes."""
        json_data = json.dumps(data, default=str)
        return self._fernet.encrypt(json_data.encode())
    
    def decrypt(self, encrypted_data: bytes) -> Dict[str, Any]:
        """Decrypt bytes back to dictionary."""
        decrypted = self._fernet.decrypt(encrypted_data)
        return json.loads(decrypted.decode())
    
    @staticmethod
    def hash_data(data: str) -> str:
        """Create SHA-256 hash for integrity verification."""
        return hashlib.sha256(data.encode()).hexdigest()


# ============================================
# RATE LIMITER
# ============================================

class InMemoryRateLimiter:
    """
    Simple in-memory rate limiter for development.
    For production, use Redis-based implementation.
    """
    
    def __init__(self):
        self._requests: Dict[str, list] = {}
        self._blocked: Dict[str, datetime] = {}
    
    def is_blocked(self, key: str) -> bool:
        """Check if a key is currently blocked."""
        if key in self._blocked:
            if datetime.utcnow() < self._blocked[key]:
                return True
            else:
                del self._blocked[key]
        return False
    
    def check_rate_limit(
        self, 
        key: str, 
        max_requests: int, 
        window_seconds: int,
        block_seconds: int = 300
    ) -> tuple[bool, Optional[int]]:
        """
        Check if request should be allowed.
        
        Returns:
            (allowed: bool, retry_after: Optional[int])
        """
        if self.is_blocked(key):
            remaining = (self._blocked[key] - datetime.utcnow()).total_seconds()
            return False, int(remaining)
        
        now = datetime.utcnow()
        window_start = now - timedelta(seconds=window_seconds)
        
        # Clean old requests
        if key in self._requests:
            self._requests[key] = [
                ts for ts in self._requests[key] 
                if ts > window_start
            ]
        else:
            self._requests[key] = []
        
        # Check limit
        if len(self._requests[key]) >= max_requests:
            self._blocked[key] = now + timedelta(seconds=block_seconds)
            return False, block_seconds
        
        # Add current request
        self._requests[key].append(now)
        return True, None
    
    def reset(self, key: str):
        """Reset rate limit for a key."""
        if key in self._requests:
            del self._requests[key]
        if key in self._blocked:
            del self._blocked[key]


# ============================================
# DEVICE FINGERPRINT
# ============================================

class DeviceFingerprint:
    """
    Handles device fingerprinting for identifying unique devices.
    """
    
    @staticmethod
    def generate_fingerprint(
        user_agent: str,
        accept_language: str,
        platform: str,
        screen_info: str = None,
        timezone: str = None,
        ip_address: str = None
    ) -> str:
        """
        Generate a device fingerprint hash from available data.
        """
        components = [
            user_agent or "",
            accept_language or "",
            platform or "",
            screen_info or "",
            timezone or ""
        ]
        
        fingerprint_string = "|".join(components)
        return hashlib.sha256(fingerprint_string.encode()).hexdigest()[:32]
    
    @staticmethod
    def extract_from_headers(headers: dict) -> dict:
        """
        Extract device information from request headers.
        """
        return {
            "user_agent": headers.get("user-agent", ""),
            "accept_language": headers.get("accept-language", ""),
            "platform": headers.get("x-device-platform", "unknown"),
            "device_name": headers.get("x-device-name", "Unknown Device"),
            "device_id": headers.get("x-device-id", ""),
            "screen_info": headers.get("x-screen-info", ""),
            "timezone": headers.get("x-timezone", "")
        }
    
    @staticmethod
    def calculate_trust_score(device_data: dict, history: list) -> int:
        """
        Calculate trust score for a device (0-100).
        
        Factors:
        - Login count (more logins = more trust)
        - Age of first login
        - Consistent location
        - No suspicious activity
        """
        score = 50  # Base score
        
        # More logins = more trust (max +30)
        login_count = device_data.get("login_count", 0)
        score += min(login_count * 3, 30)
        
        # Older devices are more trusted (max +20)
        first_seen = device_data.get("first_seen")
        if first_seen:
            days_old = (datetime.utcnow() - first_seen).days
            score += min(days_old * 2, 20)
        
        # Check for suspicious history
        for event in history:
            if event.get("type") == "failed_login":
                score -= 5
            if event.get("type") == "suspicious_activity":
                score -= 15
        
        return max(0, min(100, score))


# ============================================
# GEO CHECK (Simplified)
# ============================================

class GeoCheck:
    """
    Geolocation and VPN/Proxy detection.
    
    Note: For production, use MaxMind GeoIP2 or ipinfo.io API
    """
    
    # Known VPN/Proxy IP ranges (simplified - use proper database in production)
    VPN_INDICATORS = [
        "vpn", "proxy", "tor", "anonymous"
    ]
    
    @staticmethod
    async def check_ip(ip_address: str) -> dict:
        """
        Check IP address for location and VPN/proxy status.
        
        Returns:
            {
                "country": str,
                "city": str,
                "is_vpn": bool,
                "is_proxy": bool,
                "is_tor": bool,
                "is_datacenter": bool,
                "risk_score": int
            }
        """
        # For demo purposes, return mock data
        # In production, integrate with ip-api.com, ipinfo.io, or MaxMind
        
        is_localhost = ip_address in ["127.0.0.1", "localhost", "::1"]
        
        return {
            "country": "Local" if is_localhost else "Unknown",
            "city": "Local" if is_localhost else "Unknown",
            "is_vpn": False,
            "is_proxy": False,
            "is_tor": False,
            "is_datacenter": False,
            "risk_score": 0 if is_localhost else 10
        }
    
    @staticmethod
    def is_suspicious_location_change(
        current_country: str, 
        last_country: str,
        time_diff_hours: float
    ) -> bool:
        """
        Check if location change is physically impossible (impossible travel).
        """
        if current_country == last_country:
            return False
        
        # If country changed in less than 2 hours, it's suspicious
        if time_diff_hours < 2:
            return True
        
        return False


# Global instances
rate_limiter = InMemoryRateLimiter()
audit_encryption = AuditLogEncryption()
