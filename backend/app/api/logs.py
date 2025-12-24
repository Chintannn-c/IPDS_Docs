from fastapi import APIRouter, Depends, HTTPException
from ..db.database import db
from datetime import datetime, timezone
from typing import List, Optional
from pydantic import BaseModel

router = APIRouter()

class LogEntry(BaseModel):
    title: str
    source: str
    timestamp: datetime
    type: str # 'warning', 'error', 'info'

class AuthActivityEntry(BaseModel):
    title: str
    user_email: Optional[str] = None
    user_name: Optional[str] = None
    device_name: str
    ip_address: str
    timestamp: datetime
    type: str  # 'login', 'logout', 'failed_login', 'new_device', 'blocked_device'

from app.services.auth_service import get_current_user

@router.get("/logs", response_model=List[LogEntry])
async def get_logs(limit: int = 10000, current_user: dict = Depends(get_current_user)):
    """Fetch recent security logs for the current user."""
    if db.db is None:
        raise HTTPException(status_code=503, detail="Database not connected")
    
    # Filter by user_id
    query = {"user_id": current_user["_id"]}
    
    logs_cursor = db.db.logs.find(query).sort("timestamp", -1).limit(limit)
    logs = []
    for log in logs_cursor:
        # Ensure timestamp is aware
        ts = log.get("timestamp", datetime.now(timezone.utc))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
            
        logs.append(LogEntry(
            title=log.get("title", "Unknown Event"),
            source=log.get("source", "Unknown Source"),
            timestamp=ts,
            type=log.get("type", "info")
        ))
    return logs

@router.get("/auth-activity", response_model=List[AuthActivityEntry])
async def get_auth_activity(limit: int = 10000, current_user: dict = Depends(get_current_user)):
    """Fetch recent login/logout activity for the current user."""
    if db.db is None:
        raise HTTPException(status_code=503, detail="Database not connected")
    
    # Filter by user_id or email
    query = {
        "$or": [
            {"user_id": current_user["_id"]},
            {"user_email": current_user.get("email")}
        ]
    }
    
    activity_cursor = db.db.auth_activity.find(query).sort("timestamp", -1).limit(limit)
    activities = []
    for activity in activity_cursor:
        # Ensure timestamp is aware
        ts = activity.get("timestamp", datetime.now(timezone.utc))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
            
        activities.append(AuthActivityEntry(
            title=activity.get("title", "Unknown Event"),
            user_email=activity.get("user_email"),
            user_name=activity.get("user_name"),
            device_name=activity.get("device_name", "Unknown Device"),
            ip_address=activity.get("ip_address", "Unknown IP"),
            timestamp=ts,
            type=activity.get("type", "info")
        ))
    return activities


class IPDSActivityEntry(BaseModel):
    """Unified activity entry for IPDS dashboard combining auth and file events."""
    action: str
    severity: str  # 'success', 'info', 'warning', 'error', 'danger'
    timestamp: datetime
    device_name: Optional[str] = None
    ip_address: Optional[str] = None
    filename: Optional[str] = None
    metadata: Optional[dict] = None


@router.get("/ipds-combined", response_model=List[IPDSActivityEntry])
async def get_ipds_combined_activity(limit: int = 10000, current_user: dict = Depends(get_current_user)):
    """
    Fetch combined IPDS activity from both auth_activity and activity_logs.
    This includes login events, blocked logins, file uploads, and blocked file uploads.
    """
    if db.db is None:
        raise HTTPException(status_code=503, detail="Database not connected")
    
    combined = []
    user_id = str(current_user["_id"])
    user_email = current_user.get("email")
    
    # 1. Fetch from auth_activity (login events)
    auth_query = {
        "$or": [
            {"user_id": user_id},
            {"user_email": user_email}
        ]
    }
    auth_cursor = db.db.auth_activity.find(auth_query).sort("timestamp", -1).limit(limit)
    
    for activity in auth_cursor:
        ts = activity.get("timestamp", datetime.now(timezone.utc))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        
        # Map activity type to severity
        activity_type = activity.get("type", "info")
        if activity_type in ["login", "biometric_login", "device_bound"]:
            severity = "success"
        elif activity_type in ["failed_login", "fingerprint_mismatch"]:
            severity = "warning"
        elif activity_type in ["blocked_device", "blocked_login", "brute_force_attempt"]:
            severity = "danger"
        elif activity_type == "logout":
            severity = "info"
        else:
            severity = "info"
        
        combined.append(IPDSActivityEntry(
            action=activity.get("title", "Unknown Event"),
            severity=severity,
            timestamp=ts,
            device_name=activity.get("device_name"),
            ip_address=activity.get("ip_address")
        ))
    
    # 2. Fetch from activity_logs (file events including blocked uploads)
    activity_query = {"user_id": user_id}
    activity_cursor = db.db.activity_logs.find(activity_query).sort("timestamp", -1).limit(limit)
    
    for log in activity_cursor:
        ts = log.get("timestamp", datetime.now(timezone.utc))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        
        # Map status to severity
        status = log.get("status", "INFO")
        if status == "SUCCESS":
            severity = "success"
        elif status == "WARNING":
            severity = "warning"
        elif status in ["ERROR", "DANGER"]:
            severity = "danger"
        else:
            severity = "info"
        
        # Extract target info if available
        target = log.get("target", {})
        filename = target.get("name") if isinstance(target, dict) else None
        
        combined.append(IPDSActivityEntry(
            action=log.get("action", "Unknown Event"),
            severity=severity,
            timestamp=ts,
            filename=filename,
            metadata=log.get("metadata")
        ))
    
    # Sort combined by timestamp (newest first) and limit
    combined.sort(key=lambda x: x.timestamp, reverse=True)
    return combined[:limit]

def create_log(title: str, source: str, type: str = "info", user_id: str = None):
    """Helper to insert a log entry."""
    try:
        if db.db is not None:
            log_data = {
                "title": title,
                "source": source,
                "timestamp": datetime.now(timezone.utc),
                "type": type
            }
            if user_id:
                log_data["user_id"] = user_id
                
            db.db.logs.insert_one(log_data)
            
            # Send to WebSocket (Targeted, NOT Broadcast)
            if user_id:
                from app.websocket_manager import manager
                import asyncio
                
                asyncio.create_task(manager.send_personal_message({
                    "type": "log",
                    "data": {
                        "title": title,
                        "source": source,
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "type": type
                    }
                }, user_id))
    except Exception as e:
        print(f"Error in create_log: {e}")

def create_auth_activity(
    title: str,
    device_name: str,
    ip_address: str,
    activity_type: str,
    user_email: str = None,
    user_name: str = None,
    user_id: str = None  # Added user_id
):
    """Helper to insert an auth activity entry (login/logout events)."""
    
    # Try to resolve user_id if not provided
    if not user_id and user_email and db.db is not None:
        user = db.db.users.find_one({"email": user_email}, {"_id": 1})
        if user:
            user_id = str(user["_id"])

    if db.db is not None:
        entry = {
            "title": title,
            "user_email": user_email,
            "user_name": user_name,
            "device_name": device_name,
            "ip_address": ip_address,
            "timestamp": datetime.now(timezone.utc),
            "type": activity_type,
            "user_id": user_id  # Store user_id for better querying
        }
        db.db.auth_activity.insert_one(entry)
        
        # Broadcast to WebSocket as "auth_activity" type (Legacy)
        from app.websocket_manager import manager
        import asyncio
        from app.services.live_monitor import LiveMonitor
        from app.models.schemas import LogActor, LogTarget
        
        try:
            # Legacy broadcast - targeted to user
            if user_id:
                asyncio.create_task(manager.send_personal_message({
                    "type": "auth_activity",
                    "data": {
                        "title": title,
                        "user_email": user_email,
                        "user_name": user_name,
                        "device_name": device_name,
                        "ip_address": ip_address,
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "type": activity_type
                    }
                }, user_id))

            # New IPDS Live Monitor Broadcast
            # Map types to User-Friendly Actions
            ipds_action = title # Default to title
            
            if activity_type == "login":
                ipds_action = "Login Successful"
                ipds_status = "SUCCESS"
            elif activity_type == "failed_login":
                ipds_action = "Failed Login"
                ipds_status = "WARNING"
            elif activity_type == "logout":
                ipds_action = "User Logout"
                ipds_status = "INFO"
            elif activity_type == "device_bound":
                ipds_action = "Login using Biometric"
                ipds_status = "INFO"
            elif activity_type == "biometric_login":
                ipds_action = "Login using Biometric"
                ipds_status = "SUCCESS"
            elif "blocked" in activity_type or activity_type == "brute_force_attempt":
                ipds_action = "Brute Force Detected" if activity_type == "brute_force_attempt" else "Blocked Access"
                ipds_status = "ERROR"
            else:
                 ipds_status = "INFO"
                
            actor = LogActor(
                user_id=user_id or "unknown",
                name=user_name or "Unknown User",
                role="user",
                ip_address=ip_address
            )
            
            target = LogTarget(
                type="SYSTEM",
                name="Auth System"
            )

            asyncio.create_task(LiveMonitor.log_activity(
                actor=actor,
                action=ipds_action,
                status=ipds_status,
                target=target,
                metadata={"device": device_name, "raw_type": activity_type}
            ))
        except Exception as e:
            # Prevent login crash if logging fails
            print(f"ERROR in create_auth_activity async tasks: {e}")
