"""
Device Detection and Session Utilities (Core Only)
"""
from typing import Dict
import secrets


def parse_user_agent(ua_string: str) -> Dict[str, str]:
    """
    Basic User-Agent parsing without external dependencies
    Returns simple OS and browser detection
    """
    if not ua_string:
        return {"os": "Unknown", "browser_or_app": "Unknown"}
    
    ua_lower = ua_string.lower()
    
    # Detect OS
    if "android" in ua_lower:
        os = "Android"
    elif "iphone" in ua_lower or "ipad" in ua_lower:
        os = "iOS"
    elif "windows" in ua_lower:
        os = "Windows"
    elif "mac" in ua_lower:
        os = "macOS"
    elif "linux" in ua_lower:
        os = "Linux"
    else:
        os = "Unknown"
    
    # Detect Browser/App
    if "chrome" in ua_lower and "edg" not in ua_lower:
        browser = "Chrome"
    elif "edg" in ua_lower or "edge" in ua_lower:
        browser = "Edge"
    elif "firefox" in ua_lower:
        browser = "Firefox"
    elif "safari" in ua_lower and "chrome" not in ua_lower:
        browser = "Safari"
    elif "flutter" in ua_lower or "dart" in ua_lower:
        browser = "Application"
    else:
        browser = "Unknown"
    
    return {
        "os": os,
        "browser_or_app": browser
    }


def get_location_from_ip(ip_address: str) -> str:
    """
    Simplified location - just return IP for now (no external API calls)
    Can be enhanced later if needed
    """
    if not ip_address or ip_address in ["127.0.0.1", "localhost", "::1"]:
        return "Local"
    return f"IP: {ip_address}"


def generate_session_id() -> str:
    """Generate unique session ID"""
    return secrets.token_urlsafe(32)

