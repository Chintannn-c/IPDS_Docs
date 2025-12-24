from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from app.services.risk_engine import RiskEngine
from app.db.database import Database
from datetime import datetime

class IDSMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.method == "OPTIONS":
            return await call_next(request)

        client_ip = request.client.host
        
        # 1. Check Blocked IPs
        db = Database.get_db()
        if db is not None:
            blocked = db.blocked_ips.find_one({"ip": client_ip})
            if blocked:
                 # Check expiration
                 return JSONResponse(
                     status_code=403,
                     content={"detail": "IP Blocked due to suspicious activity"}
                 )

        # 2. Calculate Risk (Simplified)
        risk_score = RiskEngine.calculate_risk(client_ip)
        action = RiskEngine.evaluate_action(risk_score)
        
        if action == "BLOCK":
             # Add to blocked IPs
             if db is not None:
                 db.blocked_ips.insert_one({"ip": client_ip, "reason": "High Risk Score", "expires_at": datetime.utcnow()})
             return JSONResponse(
                 status_code=403,
                 content={"detail": "High Risk Detected"}
             )

        # 3. Log Event
        if db is not None:
            db.events.insert_one({
                "ip": client_ip,
                "path": request.url.path,
                "method": request.method,
                "timestamp": datetime.utcnow(),
                "risk_score": risk_score
            })

        response = await call_next(request)
        return response
