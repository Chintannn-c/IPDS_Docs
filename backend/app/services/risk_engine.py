class RiskEngine:
    @staticmethod
    def calculate_risk(ip: str, user_id: str = None) -> int:
        # Simplified logic
        risk_score = 0
        
        # Check if IP is in blocked list (simulated)
        # if ip in blocked_ips: risk_score += 50
        
        # Check recent failed logins for this IP/User
        # failed_count = db.events.count(...)
        # risk_score += failed_count * 10
        
        return min(risk_score, 100)

    @staticmethod
    def evaluate_action(risk_score: int):
        if risk_score > 70:
            return "BLOCK"
        elif risk_score > 40:
            return "VERIFY_OTP"
        return "ALLOW"
