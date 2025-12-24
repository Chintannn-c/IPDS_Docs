"""
Enhanced IPDS Middleware v2.0
Production-grade Intrusion Prevention & Detection System.

This version implements:
- Rate limiting per IP and endpoint
- Device fingerprinting
- Geolocation checks
- Advanced risk scoring (via risk_engine)
- Encrypted audit logging
- Real-time WebSocket broadcasts
- Auto-normalization on successful login
- Async Background Processing for Performance
"""
from fastapi import Request
from fastapi.responses import JSONResponse, Response
from starlette.middleware.base import BaseHTTPMiddleware
from datetime import datetime, timedelta
from typing import Optional
import uuid
import traceback
import json
import asyncio  # Added for background tasks

from app.db.database import Database
from app.services.risk_engine_v2 import risk_engine
from app.core.security import (
    rate_limiter,
    audit_encryption,
    DeviceFingerprint,
    GeoCheck
)


class IPDSMiddlewareV2(BaseHTTPMiddleware):
    """
    Enhanced Intrusion Prevention & Detection System Middleware.
    Optimized for performance with non-blocking background tasks.
    """

    # Public paths that don't require full security checks
    PUBLIC_PATHS = [
        "/docs", "/redoc", "/openapi.json",
        "/auth/login", "/auth/register"
    ]

    # Paths to exclude from logging (to reduce noise)
    IGNORED_PATHS = [
        "/ipds/dashboard", "/ipds/ws", "/ws",
        "/logs/logs", "/favicon.ico", "/health"
    ]

    # Rate limit configurations (requests, window_seconds, block_seconds)
    RATE_LIMITS = {
        "/auth/login": (5, 60, 900),      # 5 requests per minute, block 15 min
        "/auth/register": (3, 300, 1800), # 3 per 5 min, block 30 min
        "/files/upload": (10, 60, 300),   # 10 per minute, block 5 min
        "default": (100, 60, 300)         # 100 per minute, block 5 min
    }

    # thresholds for auto-normalization
    _NORMALIZE_CLEAN_REQUESTS_THRESHOLD = 5
    _NORMALIZE_TIME_MINUTES = 10

    async def dispatch(self, request: Request, call_next):
        # Skip OPTIONS requests (CORS preflight) - Fast exit
        if request.method == "OPTIONS":
            return await call_next(request)

        request_path = request.url.path

        # OPTIMIZATION: Check ignored paths early to skip unnecessary logic if possible
        # (Though we still need security checks for some ignored paths if they are sensitive)

        # Get client info
        client_ip = self._get_client_ip(request)

        # Skip security checks for public paths
        if any(request_path.startswith(p) for p in self.PUBLIC_PATHS):
            # We still want to proceed, but for login path we'll handle normalization after response
            response = await call_next(request)
            
            # If this was a login endpoint, attempt to normalize after successful login
            if request_path.startswith("/auth/login") and response.status_code in (200, 201):
                # Run in background to not delay response
                asyncio.create_task(
                    self._handle_login_response_and_normalize(request, response, client_ip)
                )
            return response

        db = Database.get_db()

        # ========================================
        # 1. CHECK BLOCKED IPs (Prevention)
        # CRITICAL PATH: Must wait
        # ========================================
        try:
            if db is not None:
                # OPTIMIZATION: Use projection to fetch minimal fields
                blocked = db.blocked_entities.find_one(
                    {
                        "entity_type": "ip",
                        "entity_value": client_ip,
                        "$or": [
                            {"expires_at": {"$gt": datetime.utcnow()}},
                            {"is_permanent": True}
                        ]
                    },
                    {"reason": 1} # Only fetch reason
                )

                if blocked:
                    # Log in background
                    asyncio.create_task(self._log_blocked_request(db, client_ip, request, blocked))
                    
                    return JSONResponse(
                        status_code=403,
                        content={
                            "detail": "Access denied. Your IP has been blocked due to suspicious activity.",
                            "blocked_reason": blocked.get("reason", "Security policy"),
                            "contact": "support@example.com"
                        }
                    )
        except Exception:
            print("IPDS: Error checking blocked IPs:", traceback.format_exc())

        # ========================================
        # 2. RATE LIMITING
        # CRITICAL PATH: Must wait
        # ========================================
        try:
            rate_limit_config = self.RATE_LIMITS.get(
                request_path,
                self.RATE_LIMITS["default"]
            )

            rate_key = f"{client_ip}:{request_path}"
            # Expected to return (allowed: bool, retry_after: int)
            allowed, retry_after = rate_limiter.check_rate_limit(
                rate_key,
                rate_limit_config[0],
                rate_limit_config[1],
                rate_limit_config[2]
            )

            if not allowed:
                # Log in background
                asyncio.create_task(self._log_rate_limit_exceeded(db, client_ip, request, retry_after))
                
                return JSONResponse(
                    status_code=429,
                    content={
                        "detail": "Too many requests. Please slow down.",
                        "retry_after": retry_after
                    },
                    headers={"Retry-After": str(retry_after)}
                )
        except Exception:
            print("IPDS: Error in rate limiting:", traceback.format_exc())

        # ========================================
        # 3. DEVICE FINGERPRINTING & GEO CHECK
        # Optimized: Parallel execution or lightweight
        # ========================================
        device_fingerprint = "unknown"
        geo_data = {"country": "unknown"}
        
        try:
            # Extract headers first (sync)
            device_info = DeviceFingerprint.extract_from_headers(dict(request.headers))
            
            # Prefer client-provided fingerprint
            client_fingerprint = request.headers.get("x-device-fingerprint")
            if client_fingerprint:
                device_fingerprint = client_fingerprint
            else:
                # Fingerprint generation is CPU bound but fast enough
                device_fingerprint = DeviceFingerprint.generate_fingerprint(
                    device_info.get("user_agent", ""),
                    device_info.get("accept_language", ""),
                    device_info.get("platform", ""),
                    device_info.get("screen_info"),
                    device_info.get("timezone")
                )
            
            # Geo check might be async IO - wait for it but handle failure gracefully
            # Optimally this should be cached or extremely fast
            geo_data = await GeoCheck.check_ip(client_ip)
            
        except Exception:
            print("IPDS: Context gathering error:", traceback.format_exc())

        # ========================================
        # 3.5 DEVICE VALIDATION (Block only blocked devices)
        # NOTE: Skip for auth endpoints - login handles its own device logic
        # ========================================
        try:
            # Skip device validation for login/register - they handle their own logic
            if not request_path.startswith("/auth/"):
                user_id = self._get_user_id_from_request(request)
                if user_id and user_id != "unknown" and db is not None:
                    user = db.users.find_one({"_id": user_id}, {
                        "blocked_devices": 1
                    })
                    
                    if user:
                        blocked_devices = user.get("blocked_devices", [])
                        
                        # Only check if device is blocked - don't reject for mismatch
                        if device_fingerprint in blocked_devices:
                            print(f"[IPDS] Blocked device attempt: {device_fingerprint[:20]}...")
                            
                            # Send force logout via WebSocket
                            asyncio.create_task(self._send_device_blocked_event(user_id))
                            
                            return JSONResponse(
                                status_code=403,
                                content={
                                    "detail": "This device is blocked from accessing your account.",
                                    "error_type": "device_blocked"
                                },
                                headers={"X-Error-Type": "device_blocked"}
                            )
        except Exception:
            print("IPDS: Device validation error:", traceback.format_exc())

        # ========================================
        # 4. RISK ASSESSMENT (Detection)
        # CRITICAL PATH: Must wait
        # ========================================
        try:
            risk_assessment = await risk_engine.calculate_risk(
                ip_address=client_ip,
                device_fingerprint=device_fingerprint,
                request_path=request_path,
                geo_data=geo_data,
                headers=dict(request.headers)
            )
        except Exception:
            # Fallback
            risk_assessment = {
                "score": 0,
                "action": "allow",
                "level": "low",
                "factors": [],
                "reason": "risk engine unavailable"
            }
            print("IPDS: risk_engine error:", traceback.format_exc())

        risk_score = risk_assessment.get("score", 0)
        risk_action = risk_assessment.get("action", "allow")

        # BACKGROUND: Auto-normalize based on per-IP state
        asyncio.create_task(self._auto_normalize_risk(db, client_ip, risk_assessment))

        # Handle high-risk requests
        if risk_action == "block":
            # BACKGROUND: Auto-block IP & Log
            asyncio.create_task(self._block_ip(db, client_ip, "High risk score detected", risk_assessment))
            asyncio.create_task(self._log_security_event(
                db, client_ip, request, device_fingerprint,
                geo_data, risk_assessment, "blocked"
            ))

            return JSONResponse(
                status_code=403,
                content={
                    "detail": "Access denied due to high risk activity.",
                    "risk_level": risk_assessment.get("level", "high")
                }
            )

        # Challenge (MFA)
        if risk_action == "challenge":
            response = await call_next(request)
            response.headers["X-IPDS-Challenge"] = "mfa_required"
            response.headers["X-Risk-Score"] = str(risk_score)
            return response

        # ========================================
        # 5. LOG EVENT (Detection)
        # BACKGROUND TASK
        # ========================================
        should_log = not any(
            request_path.startswith(p) for p in self.IGNORED_PATHS
        )

        if should_log and db is not None:
             # Capture request details needed for logging before response is sent/modified
             # (Request object might be consumed or context lost in background task if not careful,
             # but here we pass 'request' which is safe enough if we extract needed data inside helper
             # OR better: extract data here and pass dicts to background task to be 100% safe)
             
             # Extract safely for background
             req_headers = dict(request.headers)
             req_method = request.method
             req_path = request.url.path
             req_query = dict(request.query_params)
             
             # We need user_id for broadcast
             user_id = self._get_user_id_from_request(request)
             
             asyncio.create_task(self._log_and_broadcast(
                 db, client_ip, req_method, req_path, req_headers, req_query, 
                 device_fingerprint, geo_data, risk_assessment, "allowed", user_id
             ))

        # ========================================
        # 6. PROCESS REQUEST
        # ========================================
        response = await call_next(request)

        # Add security headers
        response.headers["X-Risk-Score"] = str(risk_score)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"

        return response

    # -----------------------------
    # Helpers
    # -----------------------------

    def _get_client_ip(self, request: Request) -> str:
        """Get real client IP, considering proxies."""
        try:
            forwarded_for = request.headers.get("x-forwarded-for")
            if forwarded_for:
                return forwarded_for.split(",")[0].strip()
            real_ip = request.headers.get("x-real-ip")
            if real_ip:
                return real_ip
            return request.client.host if request.client else "unknown"
        except Exception:
            return "unknown"
            
    async def _log_and_broadcast(self, db, ip, method, path, headers, query, fp, geo, risk, action, user_id):
        """Combined background task for logging and broadcasting."""
        try:
             await self._log_security_event_data(db, ip, method, path, headers, query, fp, geo, risk, action)
             await self._broadcast_event_data(risk, ip, method, path, user_id)
        except Exception as e:
            print(f"IPDS Background Error: {e}")

    async def _block_ip(self, db, ip_address: str, reason: str, risk_data: dict):
        """Add IP to blocked list."""
        try:
            existing = db.blocked_entities.find_one({"entity_type": "ip", "entity_value": ip_address})
            if existing:
                db.blocked_entities.update_one(
                    {"_id": existing["_id"]},
                    {
                        "$inc": {"block_count": 1},
                        "$set": {
                            "expires_at": datetime.utcnow() + timedelta(hours=24),
                            "last_blocked": datetime.utcnow()
                        }
                    }
                )
            else:
                db.blocked_entities.insert_one({
                    "entity_type": "ip",
                    "entity_value": ip_address,
                    "reason": reason,
                    "risk_data": risk_data,
                    "blocked_at": datetime.utcnow(),
                    "expires_at": datetime.utcnow() + timedelta(hours=1),
                    "block_count": 1,
                    "is_permanent": False
                })
        except Exception:
            print("IPDS: _block_ip error:", traceback.format_exc())

    async def _log_security_event(self, db, ip_address, request, device_fingerprint, geo_data, risk_assessment, action):
        """Legacy wrapper for direct calls - extracts data and calls data version."""
        try:
            await self._log_security_event_data(
                db, ip_address, request.method, request.url.path, 
                dict(request.headers), dict(request.query_params), 
                device_fingerprint, geo_data, risk_assessment, action
            )
        except Exception:
             pass

    async def _log_security_event_data(
        self,
        db,
        ip_address: str,
        method: str,
        path: str,
        headers: dict,
        query: dict,
        device_fingerprint: str,
        geo_data: dict,
        risk_assessment: dict,
        action: str
    ):
        """Log security event with encryption."""
        try:
            event_id = str(uuid.uuid4())
            sensitive_data = {
                "headers": headers,
                "query_params": query,
                "risk_factors": risk_assessment.get("factors", [])
            }
            encrypted_details = audit_encryption.encrypt(sensitive_data)
            event_data = f"{event_id}:{ip_address}:{path}:{datetime.utcnow().isoformat()}"
            integrity_hash = audit_encryption.hash_data(event_data)

            event = {
                "event_id": event_id,
                "timestamp": datetime.utcnow(),
                "event_type": "api_request",
                "severity": risk_assessment.get("level", "low"),
                "action": action,
                "ip_address": ip_address,
                "device_fingerprint": device_fingerprint,
                "geo_data": geo_data,
                "risk_score": risk_assessment.get("score", 0),
                "request_data": {
                    "method": method,
                    "path": path,
                    "user_agent": headers.get("user-agent", "")[:200]
                },
                "encrypted_details": encrypted_details,
                "integrity_hash": integrity_hash
            }
            db.security_events.insert_one(event)
        except Exception:
            print("IPDS: _log_security_event error:", traceback.format_exc())

    async def _log_blocked_request(self, db, ip_address, request, block_info):
        try:
            db.security_events.insert_one({
                "event_id": str(uuid.uuid4()),
                "timestamp": datetime.utcnow(),
                "event_type": "blocked_request",
                "severity": "high",
                "ip_address": ip_address,
                "request_data": {
                    "method": request.method,
                    "path": request.url.path
                },
                "block_reason": block_info.get("reason")
            })
        except Exception:
            print("IPDS: _log_blocked_request error:", traceback.format_exc())

    async def _log_rate_limit_exceeded(self, db, ip_address, request, retry_after):
        try:
            if db is not None:
                db.security_events.insert_one({
                    "event_id": str(uuid.uuid4()),
                    "timestamp": datetime.utcnow(),
                    "event_type": "rate_limit_exceeded",
                    "severity": "medium",
                    "ip_address": ip_address,
                    "request_data": {
                        "method": request.method,
                        "path": request.url.path
                    },
                    "retry_after": retry_after
                })
        except Exception:
            print("IPDS: _log_rate_limit_exceeded error:", traceback.format_exc())

    def _get_user_id_from_request(self, request: Request) -> str:
        """Extracts user_id from multiple possible locations safely."""
        try:
            # 1) From auth middleware (common pattern)
            if hasattr(request.state, "user_id"):
                return str(request.state.user_id)
            if hasattr(request.state, "user"):
                user_obj = request.state.user
                if isinstance(user_obj, dict) and "id" in user_obj:
                    return str(user_obj["id"])
                if hasattr(user_obj, "id"):
                    return str(user_obj.id)
            # 2) Headers
            if "x-user-id" in request.headers:
                return request.headers["x-user-id"]
            if "x-auth-user" in request.headers:
                return request.headers["x-auth-user"]
            # 3) Bearer
            auth = request.headers.get("authorization")
            if auth and auth.lower().startswith("bearer"):
                token = auth.split(" ")[1]
                try:
                    import jwt
                    decoded = jwt.decode(token, options={"verify_signature": False})
                    return str(decoded.get("sub") or decoded.get("user_id") or decoded.get("id") or token[:12])
                except Exception:
                    return token[:12]
        except Exception:
            pass
        return "unknown"

    async def _broadcast_event(self, request, risk_assessment, client_ip, user_id: str):
        """Legacy wrapper"""
        await self._broadcast_event_data(risk_assessment, client_ip, request.method, request.url.path, user_id)

    async def _broadcast_event_data(self, risk_assessment, client_ip, method, path, user_id: str):
        """Broadcast security event via WebSocket."""
        try:
            from app.websocket_manager import manager
            risk_score = risk_assessment.get("score", 0)
            risk_level = risk_assessment.get("level", "low")
            factors = risk_assessment.get("factors", [])

            notification = {
                "type": "notification",
                "data": {
                    "title": "Security Alert" if risk_score >= 25 else "Info",
                    "message": f"Request to {path} scored risk {risk_score}",
                    "severity": "danger" if risk_score >= 50 else ("warning" if risk_score >= 25 else "info"),
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                    "meta": {
                        "risk_score": risk_score,
                        "risk_level": risk_level,
                        "ip": client_ip,
                        "method": method,
                        "factors_count": len(factors)
                    }
                }
            }

            await manager.send_personal_message(notification, user_id)

            log_payload = {
                "type": "log",
                "data": {
                    "title": f"{method} {path}",
                    "source": client_ip,
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                    "type": "info" if risk_score < 25 else ("warning" if risk_score < 50 else "danger"),
                    "risk_score": risk_score,
                    "actor": {"user_id": user_id}
                }
            }
            await manager.send_personal_message(log_payload, user_id)

            if risk_assessment.get("action") == "challenge":
                await manager.send_personal_message({
                    "type": "notification",
                    "data": {
                        "title": "MFA Required",
                        "message": "Suspicious activity detected. Please complete multi-factor authentication.",
                        "severity": "warning",
                        "timestamp": datetime.utcnow().isoformat() + "Z",
                        "meta": {"reason": "mfa_challenge", "risk_score": risk_score}
                    }
                }, user_id)

            if risk_assessment.get("action") == "block":
                await manager.send_personal_message({
                    "type": "notification",
                    "data": {
                        "title": "Access Blocked",
                        "message": "Your access has been blocked due to high-risk activity.",
                        "severity": "danger",
                        "timestamp": datetime.utcnow().isoformat() + "Z",
                        "meta": {"risk_score": risk_score, "ip": client_ip}
                    }
                }, user_id)

        except Exception:
            print("IPDS: _broadcast_event error:", traceback.format_exc())

    async def _send_device_blocked_event(self, user_id: str):
        """Send device_blocked event via WebSocket."""
        try:
            from app.websocket_manager import manager
            await manager.force_logout_device(
                user_id=user_id,
                event_type="device_blocked",
                reason="This device has been blocked from accessing your account."
            )
        except Exception:
            print("IPDS: _send_device_blocked_event error:", traceback.format_exc())

    # -----------------------------
    # Auto-normalization helpers
    # -----------------------------
    async def _auto_normalize_risk(self, db, ip_address: str, risk_assessment: dict):
        try:
            if db is None:
                return

            now = datetime.utcnow()
            current_score = int(risk_assessment.get("score", 0))

            state = db.risk_state.find_one({"ip": ip_address})
            if not state:
                db.risk_state.insert_one({
                    "ip": ip_address,
                    "last_risk_score": current_score,
                    "last_updated": now,
                    "clean_request_count": 1 if current_score < 20 else 0
                })
                return

            if current_score >= 60:
                db.risk_state.update_one(
                    {"ip": ip_address},
                    {"$set": {"last_risk_score": current_score, "last_updated": now, "clean_request_count": 0}},
                    upsert=True
                )
                return

            if current_score < 20:
                new_count = state.get("clean_request_count", 0) + 1
                if new_count >= self._NORMALIZE_CLEAN_REQUESTS_THRESHOLD:
                    db.risk_state.update_one(
                        {"ip": ip_address},
                        {"$set": {"last_risk_score": 0, "clean_request_count": 0, "last_updated": now}}
                    )
                    return
                else:
                    db.risk_state.update_one(
                        {"ip": ip_address},
                        {"$set": {"clean_request_count": new_count, "last_updated": now}}
                    )
                    return

            last_updated = state.get("last_updated", now)
            if isinstance(last_updated, datetime):
                if (now - last_updated) >= timedelta(minutes=self._NORMALIZE_TIME_MINUTES):
                    db.risk_state.update_one(
                        {"ip": ip_address},
                        {"$set": {"last_risk_score": 0, "clean_request_count": 0, "last_updated": now}}
                    )
        except Exception:
            print("IPDS: _auto_normalize_risk error:", traceback.format_exc())

    async def _handle_login_response_and_normalize(self, request: Request, response: Response, client_ip: str):
        try:
            db = Database.get_db()
            body_bytes = b""
            try:
                if hasattr(response, "body") and response.body is not None:
                    body_bytes = response.body
                else:
                    body_iter = getattr(response, "body_iterator", None)
                    if body_iter is not None:
                        chunks = []
                        async for chunk in body_iter:
                            chunks.append(chunk)
                        body_bytes = b"".join(chunks)
                        response.body = body_bytes
                        async def new_iterator():
                            yield body_bytes
                        response.body_iterator = new_iterator()
            except Exception:
                pass

            if not body_bytes:
                return

            try:
                data = json.loads(body_bytes.decode("utf-8"))
            except Exception:
                data = {}

            token = None
            new_user_id = None
            
            # (Attempt to find user_id/token logic same as before)
            for key in ("access_token", "token", "accessToken", "jwt"):
                if key in data and isinstance(data[key], str):
                    token = data[key]
                    break
            
            for uid_key in ("user_id", "userId", "id", "user"):
                if uid_key in data:
                    maybe = data[uid_key]
                    if isinstance(maybe, dict) and "id" in maybe:
                        new_user_id = str(maybe["id"])
                        break
                    if isinstance(maybe, str) or isinstance(maybe, int):
                        new_user_id = str(maybe)
                        break

            if token and not new_user_id:
                try:
                    import jwt
                    decoded = jwt.decode(token, options={"verify_signature": False})
                    new_user_id = str(decoded.get("sub") or decoded.get("user_id") or decoded.get("id"))
                except Exception:
                    new_user_id = token[:12]

            if not new_user_id:
                return

            await self._auto_normalize_user(db, new_user_id, client_ip)
        except Exception:
            print("IPDS: _handle_login_response_and_normalize error:", traceback.format_exc())

    async def _auto_normalize_user(self, db, user_id: str, ip_address: str):
        try:
            if db is None:
                return
            now = datetime.utcnow()
            db.risk_state.update_one(
                {"ip": ip_address},
                {"$set": {"last_risk_score": 0, "clean_request_count": 0, "last_updated": now}},
                upsert=True
            )
            db.user_risk.update_many(
                {"user_id": user_id, "is_permanent": {"$ne": True}},
                {"$set": {"risk_score": 0, "risk_level": "low", "last_normalized": now}}
            )
            db.security_events.insert_one({
                "event_id": str(uuid.uuid4()),
                "timestamp": now,
                "event_type": "auto_normalization",
                "severity": "info",
                "user_id": user_id,
                "ip_address": ip_address,
                "details": f"Auto-normalized risk after successful login for user {user_id}"
            })
        except Exception:
             print("IPDS: _auto_normalize_user error:", traceback.format_exc())
