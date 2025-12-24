from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from app.services.risk_engine import RiskEngine
from app.db.database import Database
from datetime import datetime, timezone

class IPDSMiddleware(BaseHTTPMiddleware):
    """
    Intrusion Prevention & Detection System Middleware.
    Monitors requests, calculates risk scores, and blocks suspicious activity.
    """
    async def dispatch(self, request: Request, call_next):
        if request.method == "OPTIONS":
            return await call_next(request)

        client_ip = request.client.host
        
        # 1. Check Blocked IPs (Prevention)
        db = Database.get_db()
        if db is not None:
            blocked = db.blocked_ips.find_one({"ip": client_ip})
            if blocked:
                 # Check expiration
                 return JSONResponse(
                     status_code=403,
                     content={"detail": "IP Blocked due to suspicious activity"}
                 )

        # 2. Calculate Risk (Detection)
        risk_score = RiskEngine.calculate_risk(client_ip)
        action = RiskEngine.evaluate_action(risk_score)
        
        if action == "BLOCK":
             # Add to blocked IPs (Prevention)
             if db is not None:
                 db.blocked_ips.insert_one({"ip": client_ip, "reason": "High Risk Score", "expires_at": datetime.now(timezone.utc)})
             return JSONResponse(
                 status_code=403,
                 content={"detail": "High Risk Detected - Access Prevented"}
             )

        # 3. Log Event (Detection)
        # Filter out noisy internal endpoints to prevent clutter
        IGNORED_PATHS = ["/ipds/dashboard", "/logs/logs", "/ipds/ws", "/ws", "/favicon.ico"]
        should_log = not any(request.url.path.startswith(p) for p in IGNORED_PATHS)

        if db is not None and should_log:
            # Create log entry
            log_entry = {
                "ip": client_ip,
                "path": request.url.path,
                "method": request.method,
                "timestamp": datetime.now(timezone.utc),
                "risk_score": risk_score
            }
            db.events.insert_one(log_entry)

            # Retrieve manager and auth utilities locally to avoid circular imports
            from app.websocket_manager import manager
            from jose import jwt, JWTError
            from app.core.config import settings

            # Attempt to extract user_id from the Authorization header
            user_id = None
            auth_header = request.headers.get("Authorization")
            if auth_header and auth_header.startswith("Bearer "):
                token = auth_header.split(" ")[1]
                try:
                    payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
                    user_id = payload.get("user_id")
                except Exception:
                    pass

            # Only send updates if we can identify the user
            if user_id:
                # Send particular "risk" update to the specific user
                await manager.send_personal_message({
                    "type": "risk",
                    "data": {"score": risk_score}
                }, user_id)

                # Send particular "log" update to the specific user
                await manager.send_personal_message({
                    "type": "log",
                    "data": {
                        "title": f"Access {request.method} {request.url.path}",
                        "source": client_ip,
                        "timestamp": log_entry["timestamp"].isoformat(), # Reuse the timestamp from the log entry
                        "type": "info" if risk_score < 50 else "warning"
                    }
                }, user_id)

        response = await call_next(request)
        return response
