"""
IPDS Risk Engine v2.0
Advanced risk scoring with multiple factors and adaptive thresholds.
"""
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from enum import Enum
import math

from app.db.database import Database


class RiskLevel(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class ThreatCategory(Enum):
    BRUTE_FORCE = "brute_force"
    CREDENTIAL_STUFFING = "credential_stuffing"
    SUSPICIOUS_LOCATION = "suspicious_location"
    UNUSUAL_TIME = "unusual_time"
    NEW_DEVICE = "new_device"
    VPN_PROXY = "vpn_proxy"
    RAPID_REQUESTS = "rapid_requests"
    MALICIOUS_FILE = "malicious_file"
    SESSION_ANOMALY = "session_anomaly"


class RiskFactor:
    """Represents a single risk factor with weight and description."""
    
    def __init__(
        self, 
        category: ThreatCategory, 
        score: int, 
        description: str,
        evidence: Dict[str, Any] = None
    ):
        self.category = category
        self.score = score
        self.description = description
        self.evidence = evidence or {}
        self.timestamp = datetime.utcnow()
    
    def to_dict(self) -> dict:
        return {
            "category": self.category.value,
            "score": self.score,
            "description": self.description,
            "evidence": self.evidence,
            "timestamp": self.timestamp.isoformat()
        }


class RiskEngineV2:
    """
    Advanced Risk Scoring Engine
    
    Calculates risk scores based on multiple factors:
    - Login behavior (failed attempts, timing)
    - Device trust level
    - Geolocation (VPN, proxy, unusual location)
    - Request patterns (rate, endpoints)
    - File upload behavior
    - Historical patterns
    """
    
    # Risk thresholds
    THRESHOLD_MEDIUM = 25
    THRESHOLD_HIGH = 50
    THRESHOLD_CRITICAL = 75
    
    # Time windows
    FAILED_LOGIN_WINDOW = timedelta(hours=1)
    RAPID_REQUEST_WINDOW = timedelta(minutes=5)
    
    # Score weights
    WEIGHTS = {
        ThreatCategory.BRUTE_FORCE: 25,
        ThreatCategory.CREDENTIAL_STUFFING: 30,
        ThreatCategory.SUSPICIOUS_LOCATION: 20,
        ThreatCategory.UNUSUAL_TIME: 10,
        ThreatCategory.NEW_DEVICE: 15,
        ThreatCategory.VPN_PROXY: 20,
        ThreatCategory.RAPID_REQUESTS: 15,
        ThreatCategory.MALICIOUS_FILE: 40,
        ThreatCategory.SESSION_ANOMALY: 25,
    }
    
    def __init__(self):
        self.db = Database.get_db()
    
    async def calculate_risk(
        self,
        ip_address: str,
        user_id: str = None,
        device_fingerprint: str = None,
        request_path: str = None,
        geo_data: dict = None,
        headers: dict = None
    ) -> Dict[str, Any]:
        """
        Calculate comprehensive risk score for a request.
        
        Returns:
            {
                "score": int (0-100),
                "level": RiskLevel,
                "factors": List[RiskFactor],
                "action": str ("allow", "challenge", "block"),
                "recommendations": List[str]
            }
        """
        factors: List[RiskFactor] = []
        
        # 1. Check failed login attempts
        if user_id or ip_address:
            brute_force_factor = await self._check_brute_force(ip_address, user_id)
            if brute_force_factor:
                factors.append(brute_force_factor)
        
        # 2. Check device trust
        if device_fingerprint and user_id:
            device_factor = await self._check_device_trust(user_id, device_fingerprint)
            if device_factor:
                factors.append(device_factor)
        
        # 3. Check geolocation risks
        if geo_data:
            geo_factors = self._check_geo_risks(geo_data, user_id)
            factors.extend(geo_factors)
        
        # 4. Check time-based risks
        time_factor = self._check_unusual_time()
        if time_factor:
            factors.append(time_factor)
        
        # 5. Check request patterns
        if ip_address:
            request_factor = await self._check_request_patterns(ip_address, user_id)
            if request_factor:
                factors.append(request_factor)
        
        # Calculate total score
        total_score = sum(f.score for f in factors)
        total_score = min(100, total_score)  # Cap at 100
        
        # Determine risk level
        level = self._determine_level(total_score)
        
        # Determine action
        action = self._determine_action(total_score, factors)
        
        # Generate recommendations
        recommendations = self._generate_recommendations(factors)
        
        return {
            "score": total_score,
            "level": level.value,
            "factors": [f.to_dict() for f in factors],
            "action": action,
            "recommendations": recommendations,
            "timestamp": datetime.utcnow().isoformat()
        }
    
    async def _check_brute_force(
        self, 
        ip_address: str, 
        user_id: str = None
    ) -> Optional[RiskFactor]:
        """Check for brute force attack patterns."""
        if self.db is None:
            return None
        
        window_start = datetime.utcnow() - self.FAILED_LOGIN_WINDOW
        
        # Count failed logins from this IP
        query = {
            "ip_address": ip_address,
            "type": "login",
            "title": {"$regex": "Failed", "$options": "i"},
            "timestamp": {"$gte": window_start}
        }
        
        failed_count = self.db.auth_activity.count_documents(query)
        
        if failed_count >= 10:
            return RiskFactor(
                category=ThreatCategory.BRUTE_FORCE,
                score=self.WEIGHTS[ThreatCategory.BRUTE_FORCE] + (failed_count * 2),
                description=f"High number of failed login attempts: {failed_count} in the last hour",
                evidence={"failed_attempts": failed_count, "ip": ip_address}
            )
        elif failed_count >= 5:
            return RiskFactor(
                category=ThreatCategory.BRUTE_FORCE,
                score=self.WEIGHTS[ThreatCategory.BRUTE_FORCE],
                description=f"Multiple failed login attempts: {failed_count} in the last hour",
                evidence={"failed_attempts": failed_count, "ip": ip_address}
            )
        
        return None
    
    async def _check_device_trust(
        self, 
        user_id: str, 
        device_fingerprint: str
    ) -> Optional[RiskFactor]:
        """Check if device is new or untrusted."""
        if self.db is None:
            return None
        
        device = self.db.device_fingerprints.find_one({
            "user_id": user_id,
            "fingerprint_hash": device_fingerprint
        })
        
        if device is None:
            return RiskFactor(
                category=ThreatCategory.NEW_DEVICE,
                score=self.WEIGHTS[ThreatCategory.NEW_DEVICE],
                description="Login from a new, unrecognized device",
                evidence={"fingerprint": device_fingerprint[:8] + "..."}
            )
        
        trust_score = device.get("trust_score", 50)
        if trust_score < 30:
            return RiskFactor(
                category=ThreatCategory.NEW_DEVICE,
                score=int(self.WEIGHTS[ThreatCategory.NEW_DEVICE] * (1 - trust_score/100)),
                description=f"Device has low trust score: {trust_score}",
                evidence={"trust_score": trust_score}
            )
        
        return None
    
    def _check_geo_risks(
        self, 
        geo_data: dict, 
        user_id: str = None
    ) -> List[RiskFactor]:
        """Check geolocation-based risks."""
        factors = []
        
        # VPN/Proxy detection
        if geo_data.get("is_vpn") or geo_data.get("is_proxy"):
            factors.append(RiskFactor(
                category=ThreatCategory.VPN_PROXY,
                score=self.WEIGHTS[ThreatCategory.VPN_PROXY],
                description="Connection through VPN or proxy detected",
                evidence={"is_vpn": geo_data.get("is_vpn"), "is_proxy": geo_data.get("is_proxy")}
            ))
        
        # Tor detection (higher risk)
        if geo_data.get("is_tor"):
            factors.append(RiskFactor(
                category=ThreatCategory.VPN_PROXY,
                score=self.WEIGHTS[ThreatCategory.VPN_PROXY] + 10,
                description="Connection through Tor network detected",
                evidence={"is_tor": True}
            ))
        
        # Datacenter IP (often bots)
        if geo_data.get("is_datacenter"):
            factors.append(RiskFactor(
                category=ThreatCategory.VPN_PROXY,
                score=15,
                description="Request from datacenter IP (potential bot)",
                evidence={"is_datacenter": True}
            ))
        
        return factors
    
    def _check_unusual_time(self) -> Optional[RiskFactor]:
        """Check if access is at unusual time (configurable)."""
        current_hour = datetime.utcnow().hour
        
        # Consider 1 AM - 5 AM as unusual (adjust based on user timezone)
        if 1 <= current_hour <= 5:
            return RiskFactor(
                category=ThreatCategory.UNUSUAL_TIME,
                score=self.WEIGHTS[ThreatCategory.UNUSUAL_TIME],
                description="Access during unusual hours (1 AM - 5 AM UTC)",
                evidence={"hour": current_hour}
            )
        
        return None
    
    async def _check_request_patterns(
        self, 
        ip_address: str, 
        user_id: str = None
    ) -> Optional[RiskFactor]:
        """Check for suspicious request patterns."""
        if self.db is None:
            return None
        
        window_start = datetime.utcnow() - self.RAPID_REQUEST_WINDOW
        
        # Count recent requests
        query = {
            "ip": ip_address,
            "timestamp": {"$gte": window_start}
        }
        
        request_count = self.db.events.count_documents(query)
        
        # More than 100 requests in 5 minutes is suspicious
        if request_count > 100:
            return RiskFactor(
                category=ThreatCategory.RAPID_REQUESTS,
                score=self.WEIGHTS[ThreatCategory.RAPID_REQUESTS] + 10,
                description=f"Very high request rate: {request_count} requests in 5 minutes",
                evidence={"request_count": request_count}
            )
        elif request_count > 50:
            return RiskFactor(
                category=ThreatCategory.RAPID_REQUESTS,
                score=self.WEIGHTS[ThreatCategory.RAPID_REQUESTS],
                description=f"High request rate: {request_count} requests in 5 minutes",
                evidence={"request_count": request_count}
            )
        
        return None
    
    def _determine_level(self, score: int) -> RiskLevel:
        """Determine risk level from score."""
        if score >= self.THRESHOLD_CRITICAL:
            return RiskLevel.CRITICAL
        elif score >= self.THRESHOLD_HIGH:
            return RiskLevel.HIGH
        elif score >= self.THRESHOLD_MEDIUM:
            return RiskLevel.MEDIUM
        return RiskLevel.LOW
    
    def _determine_action(
        self, 
        score: int, 
        factors: List[RiskFactor]
    ) -> str:
        """Determine action based on risk assessment."""
        if score >= self.THRESHOLD_CRITICAL:
            return "block"
        elif score >= self.THRESHOLD_HIGH:
            # Check if any critical factor
            critical_categories = [
                ThreatCategory.BRUTE_FORCE,
                ThreatCategory.MALICIOUS_FILE
            ]
            for factor in factors:
                if factor.category in critical_categories:
                    return "block"
            return "challenge"  # Require MFA
        elif score >= self.THRESHOLD_MEDIUM:
            return "challenge"
        return "allow"
    
    def _generate_recommendations(
        self, 
        factors: List[RiskFactor]
    ) -> List[str]:
        """Generate security recommendations based on risk factors."""
        recommendations = []
        
        categories = {f.category for f in factors}
        
        if ThreatCategory.BRUTE_FORCE in categories:
            recommendations.append("Consider enabling account lockout after failed attempts")
            recommendations.append("Enable two-factor authentication")
        
        if ThreatCategory.NEW_DEVICE in categories:
            recommendations.append("Verify this device before allowing full access")
        
        if ThreatCategory.VPN_PROXY in categories:
            recommendations.append("Verify user identity through additional authentication")
        
        if ThreatCategory.UNUSUAL_TIME in categories:
            recommendations.append("Confirm this access was intentional")
        
        if ThreatCategory.RAPID_REQUESTS in categories:
            recommendations.append("Consider implementing rate limiting")
        
        return recommendations
    
    @staticmethod
    def calculate_file_risk(safety_score: int, file_metadata: dict) -> dict:
        """
        Calculate risk for uploaded files.
        
        Args:
            safety_score: Score from file scanner (0-100, 100 = safe)
            file_metadata: File information
            
        Returns:
            Risk assessment for the file
        """
        risk_score = 100 - safety_score
        
        factors = []
        
        if risk_score >= 70:
            factors.append({
                "category": ThreatCategory.MALICIOUS_FILE.value,
                "score": 40,
                "description": "File contains highly suspicious patterns"
            })
        elif risk_score >= 40:
            factors.append({
                "category": ThreatCategory.MALICIOUS_FILE.value,
                "score": 20,
                "description": "File contains potentially suspicious patterns"
            })
        
        # Check file extension
        filename = file_metadata.get("filename", "")
        dangerous_extensions = [".exe", ".bat", ".cmd", ".ps1", ".vbs", ".js"]
        if any(filename.lower().endswith(ext) for ext in dangerous_extensions):
            factors.append({
                "category": ThreatCategory.MALICIOUS_FILE.value,
                "score": 30,
                "description": f"Potentially dangerous file type: {filename.split('.')[-1]}"
            })
        
        return {
            "risk_score": risk_score,
            "factors": factors,
            "action": "block" if risk_score >= 70 else ("scan" if risk_score >= 40 else "allow")
        }


# Singleton instance
risk_engine = RiskEngineV2()
