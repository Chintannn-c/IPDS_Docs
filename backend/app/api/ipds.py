from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query
from app.services.auth_service import get_current_user, is_device_safe, is_file_safe
from app.db.database import Database
from pydantic import BaseModel
from typing import List
from app.websocket_manager import manager
from jose import jwt, JWTError
from app.core.config import settings
from datetime import datetime, timedelta

router = APIRouter()

class DeviceStatus(BaseModel):
    device_id: str
    device_name: str
    is_safe: bool
    is_trusted: bool
    is_blocked: bool
    last_login: str | None = None
    ip_address: str | None = None

class FileStatus(BaseModel):
    file_id: str
    filename: str
    is_safe: bool
    is_uploaded: bool
    size: int | None = None

class DashboardLogEntry(BaseModel):
    title: str
    source: str
    timestamp: datetime
    type: str

class IPDSDashboardResponse(BaseModel):
    devices: List[DeviceStatus]
    files: List[FileStatus]
    logs: List[DashboardLogEntry]

@router.get("/dashboard", response_model=IPDSDashboardResponse)
async def get_ipds_dashboard(current_user: dict = Depends(get_current_user)):
    """
    Get IPDS dashboard data for the current user.
    Returns trusted/untrusted devices, safe/flagged files, and recent logs.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")

    # 1. Process Devices
    trusted_devices = current_user.get("trusted_devices", [])
    
    device_statuses = []
    for device in trusted_devices:
        if not isinstance(device, dict):
            continue
            
        device_statuses.append(DeviceStatus(
            device_id=device.get("device_id", "unknown"),
            device_name=device.get("name", "Unknown Device"),
            is_safe=is_device_safe(device),
            is_trusted=device.get("is_trusted", False),
            is_blocked=device.get("is_blocked", False),
            last_login=device.get("last_login"),
            ip_address=device.get("ip_address")
        ))

    # 2. Process Files
    user_files_cursor = db.files.find({"user_id": current_user["_id"]})
    user_files = list(user_files_cursor)
    
    file_statuses = []
    for file in user_files:
        if not isinstance(file, dict):
            continue
            
        file_statuses.append(FileStatus(
            file_id=str(file.get("_id")),
            filename=file.get("filename", "Unknown File"),
            is_safe=is_file_safe(file),
            is_uploaded=True,
            size=file.get("size")
        ))

    # 3. Process Logs (Recent 20)
    # 3. Process Logs (Recent 20 from both Logs and Auth Activity)
    logs = []
    
    # Fetch General Logs
    logs_cursor = db.logs.find({"user_id": current_user["_id"]}).sort("timestamp", -1)
    for log in logs_cursor:
        logs.append(DashboardLogEntry(
            title=log.get("title", "Unknown Event"),
            source=log.get("source", "Unknown Source"),
            timestamp=log.get("timestamp", datetime.utcnow()),
            type=log.get("type", "info")
        ))
        
    # Fetch Auth Activity
    auth_cursor = db.auth_activity.find({"user_id": str(current_user["_id"])}).sort("timestamp", -1)
    for auth in auth_cursor:
        logs.append(DashboardLogEntry(
            title=auth.get("title", "Auth Event"),
            source=f"Auth Device: {auth.get('device_name', 'Unknown')}",
            timestamp=auth.get("timestamp", datetime.utcnow()),
            type="info" if auth.get("type") in ["login", "logout"] else "warning"
        ))
        
    # Merge and Sort
    logs.sort(key=lambda x: x.timestamp, reverse=True)

    return IPDSDashboardResponse(
        devices=device_statuses,
        files=file_statuses,
        logs=logs
    )

class RiskFactor(BaseModel):
    name: str
    score: int  # 0-30 individual factor score
    max_score: int = 30
    icon: str
    color: str
    description: str

class RiskResponse(BaseModel):
    risk_score: int
    risk_level: str  # LOW, MEDIUM, HIGH, CRITICAL
    threats: List[str]
    prevented_attacks: int  # New field for IPDS
    history: List[dict]  # {date: str, score: int}
    risk_factors: List[RiskFactor] = []  # Individual factor breakdown

@router.get("/risk", response_model=RiskResponse)
async def get_risk_assessment(current_user: dict = Depends(get_current_user)):
    """
    Calculate and return the user's risk profile with prevention stats.
    """
    db = Database.get_db()
    
    # 1. Get Current Score
    risk_score = current_user.get("risk_score", 0)
    
    # Determine level
    if risk_score < 20:
        level = "LOW"
    elif risk_score < 50:
        level = "MEDIUM"
    elif risk_score < 80:
        level = "HIGH"
    else:
        level = "CRITICAL"
        
    # 2. Risk History (Real Data Aggregation)
    history = []
    today = datetime.utcnow().date()
    
    # Initialize last 7 days with 0 (or baseline)
    history_map = {
        (today - timedelta(days=i)).strftime("%Y-%m-%d"): 0 
        for i in range(7)
    }
    
    if db is not None:
        # Calculate risk score for each of the last 7 days based on actual events
        for i in range(7):
            date = today - timedelta(days=i)
            date_str = date.strftime("%Y-%m-%d")
            day_start = datetime.combine(date, datetime.min.time())
            day_end = datetime.combine(date, datetime.max.time())
            
            daily_risk = 0
            
            # Count failed login attempts for this day (5 points each, max 30)
            failed_logins = db.auth_activity.count_documents({
                "user_email": current_user.get("email"),
                "type": "failed_login",
                "timestamp": {"$gte": day_start, "$lte": day_end}
            })
            daily_risk += min(failed_logins * 5, 30)
            
            # Count blocked device attempts for this day (15 points each, max 30)
            blocked_attempts = db.auth_activity.count_documents({
                "user_email": current_user.get("email"),
                "type": {"$in": ["blocked_device", "blocked_login"]},
                "timestamp": {"$gte": day_start, "$lte": day_end}
            })
            daily_risk += min(blocked_attempts * 15, 30)
            
            # Add device trust issues (at snapshot time)
            if i == 0:  # Only for today, use current device state
                trusted_devices = current_user.get("trusted_devices", [])
                blocked_count = len([d for d in trusted_devices if isinstance(d, dict) and d.get("is_blocked", False)])
                untrusted_count = len([d for d in trusted_devices if isinstance(d, dict) and not d.get("is_trusted", False)])
                daily_risk += min(blocked_count * 15 + untrusted_count * 5, 30)
            
            # Cap daily risk at reasonable max (150 is theoretical max)
            history_map[date_str] = min(daily_risk, 150)
                
    # Convert to list sorted by date
    history = [
        {"date": date, "score": score} 
        for date, score in sorted(history_map.items())
    ]

    # 3. Dynamic Threats & Recommendations
    threats = []
    
    # Check blocked devices
    trusted_devices = current_user.get("trusted_devices", [])
    blocked_devices = [d for d in trusted_devices if isinstance(d, dict) and d.get("is_blocked")]
    if blocked_devices:
        threats.append(f"{len(blocked_devices)} blocked devices detected")
        
    # Check failed logins
    if db is not None:
        recent_failed = db.auth_activity.count_documents({
            "user_email": current_user.get("email"),
            "type": "failed_login",
            "timestamp": {"$gte": datetime.utcnow() - timedelta(hours=24)}
        })
        if recent_failed > 3:
            threats.append(f"{recent_failed} failed login attempts in last 24h")

    if risk_score > 50:
         threats.append("High cumulative risk score detected")

    # 4. CALCULATE RISK FACTORS
    risk_factors = []
    
    # Factor 1: Login Activity (max 30 points)
    login_score = 0
    if db is not None:
        failed_logins_24h = db.auth_activity.count_documents({
            "user_email": current_user.get("email"),
            "type": "failed_login",
            "timestamp": {"$gte": datetime.utcnow() - timedelta(hours=24)}
        })
        # Each failed login adds 5 points, max 30
        login_score = min(failed_logins_24h * 5, 30)
    
    login_desc = "No suspicious login activity" if login_score < 10 else f"{failed_logins_24h} failed attempts detected"
    risk_factors.append(RiskFactor(
        name="Login Activity",
        score=login_score,
        icon="login",
        color="blue",
        description=login_desc
    ))
    
    # Factor 2: Device Trust (max 30 points)
    device_score = 0
    trusted_devices = current_user.get("trusted_devices", [])
    total_devices = len(trusted_devices)
    untrusted_count = len([d for d in trusted_devices if isinstance(d, dict) and not d.get("is_trusted", False)])
    blocked_count = len([d for d in trusted_devices if isinstance(d, dict) and d.get("is_blocked", False)])
    
    # Blocked devices add 15 points each, untrusted add 5
    device_score = min(blocked_count * 15 + untrusted_count * 5, 30)
    
    device_desc = f"{blocked_count} blocked, {untrusted_count} untrusted devices" if device_score > 0 else "All devices trusted"
    risk_factors.append(RiskFactor(
        name="Device Trust",
        score=device_score,
        icon="devices",
        color="purple",
        description=device_desc
    ))
    
    # Factor 3: File Activity (max 30 points)
    file_score = 0
    dangerous_files = 0
    risky_files = 0
    if db is not None:
        # Query with multiple owner field formats for compatibility
        user_id = current_user["_id"]
        user_id_str = str(user_id)
        
        owner_query = {
            "$or": [
                {"owner_id": user_id},
                {"owner_id": user_id_str},
                {"user_id": user_id},
                {"user_id": user_id_str}
            ]
        }
        
        # Check for dangerous files with safety_score < 50
        dangerous_query = {**owner_query, "safety_score": {"$lt": 50}}
        dangerous_files = db.files.count_documents(dangerous_query)
        
        # Check for risky files with safety_score 50-69 (CAUTION)
        risky_query = {
            "$and": [
                owner_query,
                {"safety_score": {"$gte": 50, "$lt": 70}}
            ]
        }
        risky_files = db.files.count_documents(risky_query)
        
        # Debug print
        print(f"[IPDS Risk] User {user_id_str}: {dangerous_files} dangerous, {risky_files} risky files")
        
        # Dangerous = 10 pts each, Risky = 5 pts each
        file_score = min(dangerous_files * 10 + risky_files * 5, 30)
    
    flagged_total = dangerous_files + risky_files
    if dangerous_files > 0:
        file_desc = f"{dangerous_files} dangerous, {risky_files} risky files"
    elif risky_files > 0:
        file_desc = f"{risky_files} risky files detected"
    else:
        file_desc = "No suspicious files"
    
    risk_factors.append(RiskFactor(
        name="File Activity",
        score=file_score,
        icon="folder",
        color="teal",
        description=file_desc
    ))
    
    # Factor 4: Network/IP Risk (max 30 points)
    network_score = 0
    if db is not None:
        # Check if user's IPs have been flagged
        user_ips = set()
        for d in trusted_devices:
            if isinstance(d, dict) and d.get("ip_address"):
                user_ips.add(d.get("ip_address"))
        
        blocked_ip_count = 0
        for ip in user_ips:
            if db.blocked_entities.find_one({"entity_type": "ip", "entity_value": ip}):
                blocked_ip_count += 1
        
        network_score = min(blocked_ip_count * 15, 30)
    
    network_desc = f"{blocked_ip_count} blocked IPs associated" if network_score > 0 else "Network activity normal"
    risk_factors.append(RiskFactor(
        name="Network",
        score=network_score,
        icon="wifi",
        color="indigo",
        description=network_desc
    ))
    
    # Factor 5: MFA Status (max 30 points)
    mfa_score = 0 if current_user.get("mfa_enabled") else 15  # No MFA = 15 points risk
    
    mfa_desc = "2FA enabled" if mfa_score == 0 else "2FA not enabled - recommended"
    risk_factors.append(RiskFactor(
        name="Authentication",
        score=mfa_score,
        icon="security",
        color="orange",
        description=mfa_desc
    ))
    
    # CALCULATE TOTAL RISK SCORE FROM ALL FACTORS
    risk_score = sum(factor.score for factor in risk_factors)
    
    # Update risk level based on calculated score
    if risk_score < 30:
        level = "LOW"
    elif risk_score < 70:
        level = "MEDIUM"
    else:
        level = "CRITICAL"
    
    # 5. Prevented attacks count
    prevented_attacks = 0
    if db is not None:
        prevented_attacks = db.blocked_entities.count_documents({"entity_type": "ip"})

    return RiskResponse(
        risk_score=risk_score,
        risk_level=level,
        threats=threats,
        prevented_attacks=prevented_attacks,
        history=history,
        risk_factors=risk_factors
    )


class UserActivityEvent(BaseModel):
    event_type: str  # 'login', 'logout', 'file_upload', 'device_login', 'security_alert'
    title: str
    device_name: str | None = None
    device_fingerprint: str | None = None
    ip_address: str | None = None
    filename: str | None = None
    file_size: int | None = None
    timestamp: datetime
    icon: str  # Frontend will use this for display
    severity: str | None = None  # 'low', 'medium', 'high', 'critical'


class SecurityAlert(BaseModel):
    alert_type: str
    title: str
    description: str
    severity: str  # 'low', 'medium', 'high', 'critical'
    timestamp: datetime
    is_resolved: bool = False


class UserActivityResponse(BaseModel):
    latest_login: UserActivityEvent | None = None
    latest_file_upload: UserActivityEvent | None = None
    last_logout: UserActivityEvent | None = None
    last_device_login: UserActivityEvent | None = None  # Device-specific login
    recent_actions: list[UserActivityEvent] = []  # Last 10 actions
    security_alerts: list[SecurityAlert] = []  # Active security alerts
    

@router.get("/user-activity", response_model=UserActivityResponse)
async def get_user_activity(current_user: dict = Depends(get_current_user)):
    """
    Get the user's comprehensive IPDS activity events:
    - Latest login
    - Latest file upload
    - Last logout
    - Last device login (with fingerprint)
    - Recent actions (last 10)
    - Security alerts
    
    Each user only sees their own activity - completely isolated.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    user_id = current_user["_id"]
    user_email = current_user.get("email")
    
    # 1. Find latest login
    latest_login = None
    login_record = db.auth_activity.find_one(
        {"user_email": user_email, "type": "login"},
        sort=[("timestamp", -1)]
    )
    if login_record:
        latest_login = UserActivityEvent(
            event_type="login",
            title="Logged in",
            device_name=login_record.get("device_name", "Unknown Device"),
            ip_address=login_record.get("ip_address", "Unknown IP"),
            timestamp=login_record.get("timestamp", datetime.utcnow()),
            icon="login"
        )
    
    # 2. Find last logout
    last_logout = None
    logout_record = db.auth_activity.find_one(
        {"user_email": user_email, "type": "logout"},
        sort=[("timestamp", -1)]
    )
    if logout_record:
        last_logout = UserActivityEvent(
            event_type="logout",
            title="Logged out",
            device_name=logout_record.get("device_name", "Unknown Device"),
            ip_address=logout_record.get("ip_address", "Unknown IP"),
            timestamp=logout_record.get("timestamp", datetime.utcnow()),
            icon="logout"
        )
    
    # 3. Find latest file upload with size
    latest_file_upload = None
    file_record = db.files.find_one(
        {"user_id": user_id},
        sort=[("uploaded_at", -1)]
    )
    if file_record:
        latest_file_upload = UserActivityEvent(
            event_type="file_upload",
            title="File uploaded",
            filename=file_record.get("filename", "Unknown File"),
            file_size=file_record.get("size"),
            timestamp=file_record.get("uploaded_at", datetime.utcnow()),
            icon="upload"
        )
    
    # 4. Find last device login (with fingerprint info)
    last_device_login = None
    trusted_devices = current_user.get("trusted_devices", [])
    if trusted_devices:
        # Find most recently active device
        sorted_devices = sorted(
            [d for d in trusted_devices if isinstance(d, dict) and d.get("last_login")],
            key=lambda x: x.get("last_login", ""),
            reverse=True
        )
        if sorted_devices:
            device = sorted_devices[0]
            last_device_login = UserActivityEvent(
                event_type="device_login",
                title=f"Login from {device.get('name', 'Device')}",
                device_name=device.get("name", "Unknown Device"),
                device_fingerprint=device.get("fingerprint", device.get("device_id"))[:16] if device.get("fingerprint") or device.get("device_id") else None,
                ip_address=device.get("ip_address"),
                timestamp=datetime.fromisoformat(device.get("last_login")) if device.get("last_login") else datetime.utcnow(),
                icon="devices"
            )
    
    # 5. Build recent actions feed (last 10 activities)
    recent_actions = []
    
    # Get auth activities
    auth_activities = list(db.auth_activity.find(
        {"user_email": user_email}
    ).sort("timestamp", -1).limit(5))
    
    for activity in auth_activities:
        event_type = activity.get("type", "unknown")
        icon = "login" if event_type == "login" else "logout" if event_type == "logout" else "security"
        recent_actions.append(UserActivityEvent(
            event_type=event_type,
            title=activity.get("title", event_type.capitalize()),
            device_name=activity.get("device_name"),
            ip_address=activity.get("ip_address"),
            timestamp=activity.get("timestamp", datetime.utcnow()),
            icon=icon
        ))
    
    # Get file activities
    file_activities = list(db.files.find(
        {"user_id": user_id}
    ).sort("uploaded_at", -1).limit(5))
    
    for file in file_activities:
        recent_actions.append(UserActivityEvent(
            event_type="file_upload",
            title="Uploaded file",
            filename=file.get("filename"),
            file_size=file.get("size"),
            timestamp=file.get("uploaded_at", datetime.utcnow()),
            icon="upload"
        ))
    
    # Sort by timestamp and limit to 10
    recent_actions.sort(key=lambda x: x.timestamp, reverse=True)
    recent_actions = recent_actions[:10]
    
    # 6. Build security alerts
    security_alerts = []
    
    # Check for blocked devices
    blocked_devices = [d for d in trusted_devices if isinstance(d, dict) and d.get("is_blocked")]
    if blocked_devices:
        security_alerts.append(SecurityAlert(
            alert_type="blocked_device",
            title="Blocked Devices Detected",
            description=f"{len(blocked_devices)} device(s) have been blocked for security reasons",
            severity="high",
            timestamp=datetime.utcnow(),
            is_resolved=False
        ))
    
    # Check for high risk score
    risk_score = current_user.get("risk_score", 0)
    if risk_score >= 80:
        security_alerts.append(SecurityAlert(
            alert_type="high_risk",
            title="Critical Risk Level",
            description=f"Your account risk score is {risk_score}/100. Immediate action recommended.",
            severity="critical",
            timestamp=datetime.utcnow(),
            is_resolved=False
        ))
    elif risk_score >= 50:
        security_alerts.append(SecurityAlert(
            alert_type="elevated_risk",
            title="Elevated Risk Level",
            description=f"Your account risk score is {risk_score}/100. Review recent activity.",
            severity="medium",
            timestamp=datetime.utcnow(),
            is_resolved=False
        ))
    
    # Check for recent blocked login attempts
    recent_blocked = db.auth_activity.count_documents({
        "user_email": user_email,
        "type": "blocked_device",
        "timestamp": {"$gte": datetime.utcnow() - timedelta(hours=24)}
    }) if hasattr(db, 'auth_activity') else 0
    
    
    if recent_blocked > 0:
        security_alerts.append(SecurityAlert(
            alert_type="blocked_attempts",
            title="Blocked Login Attempts",
            description=f"{recent_blocked} blocked login attempt(s) in the last 24 hours",
            severity="medium" if recent_blocked < 5 else "high",
            timestamp=datetime.utcnow(),
            is_resolved=False
        ))
        
    
    # Check for recent failed login attempts (Wrong Password)
    recent_failed_count = db.auth_activity.count_documents({
        "user_email": user_email,
        "type": "failed_login",
        "timestamp": {"$gte": datetime.utcnow() - timedelta(hours=24)}
    }) if hasattr(db, 'auth_activity') else 0
    
    if recent_failed_count > 0:
        # Get the LATEST failed login to use its real timestamp for deduplication
        latest_failed_event = db.auth_activity.find_one(
            {
                "user_email": user_email,
                "type": "failed_login",
                "timestamp": {"$gte": datetime.utcnow() - timedelta(hours=24)}
            },
            sort=[("timestamp", -1)]
        )
        
        # Use the actual event time if available, fallback to now only if necessary
        alert_time = latest_failed_event["timestamp"] if latest_failed_event else datetime.utcnow()

        security_alerts.append(SecurityAlert(
            alert_type="failed_login",
            title="Unauthorized Access Attempts",
            description=f"{recent_failed_count} failed login attempt(s) (wrong password) detected",
            severity="medium" if recent_failed_count < 3 else "high",
            timestamp=alert_time,
            is_resolved=False
        ))
    
    return UserActivityResponse(
        latest_login=latest_login,
        latest_file_upload=latest_file_upload,
        last_logout=last_logout,
        last_device_login=last_device_login,
        recent_actions=recent_actions,
        security_alerts=security_alerts
    )

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = Query(...)):
    try:
        # Validate Token
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
            user_id = payload.get("user_id")
            if user_id is None:
                print("WebSocket Auth Error: Missing user_id in token")
                await websocket.close(code=1008)
                return
        except JWTError as e:
            print(f"WebSocket Auth Error: Invalid Token - {e}")
            await websocket.close(code=1008)
            return

        await manager.connect(websocket, user_id)
        try:
            while True:
                data = await websocket.receive_text()
                # Handle client messages if needed
        except WebSocketDisconnect:
            manager.disconnect(websocket, user_id)
            
    except Exception as e:
        print(f"WebSocket Error: {e}")
        try:
            await websocket.close(code=1011)
        except:
            pass

@router.post("/reset")
async def reset_system(current_user: dict = Depends(get_current_user)):
    """
    Emergency System Reset:
    - Clears all risk scores
    - Removes all blocked entities
    - Clears risk state
    - Resets user risk profiles
    - Clears login activity history
    """
    # Verify admin or high privileges if needed (skipping for now based on user request)
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
        
    user_id = current_user["_id"]
    user_email = current_user.get("email")

    # 1. Reset Risk Score to 0 and clear failed attempts (User Level)
    db.users.update_one(
        {"_id": user_id},
        {"$set": {"risk_score": 0, "failed_login_attempts": 0}} 
    )

    # 2. Reset IP Reputation (System Level)
    db.risk_state.delete_many({})

    # 3. Clear Blocked Entities
    db.blocked_entities.delete_many({})
    
    # 4. Clear User Risk State
    db.user_risk.delete_many({})
    
    # 5. Clear negative auth activity (failed logins, blocked attempts, etc.)
    # This resets the Login Activity risk factor to 0
    db.auth_activity.delete_many({
        "$or": [
            {"user_email": user_email},
            {"user_id": str(user_id)}
        ],
        "type": {"$in": ["failed_login", "blocked_device", "fingerprint_mismatch", "biometric_login_failed"]}
    })

    # 6. Add a Resolution Log
    log_entry = {
        "user_id": user_id,
        "title": "System Reset Performed",
        "source": "User Action",
        "timestamp": datetime.utcnow(),
        "type": "success",
        "details": "Full system risk reset: User score, IP reputation, blocks, and login activity cleared.",
        "risk_score": 0
    }
    db.logs.insert_one(log_entry)

    # 7. Insert clean login to seed history
    success_event = {
        "user_email": user_email,
        "type": "login",
        "title": "Successful Login (Reset)",
        "device_name": "System Reset",
        "ip_address": "127.0.0.1",
        "timestamp": datetime.utcnow()
    }
    db.auth_activity.insert_one(success_event)
    
    return {
        "success": True,
        "message": "IPDS fully normalized - all activity cleared"
    }

@router.get("/live")
async def get_live_metrics(current_user: dict = Depends(get_current_user)):
    """
    Fetch live IPDS metrics for all users and active IPs.
    Returns:
    [
      {
        "id": "user1",
        "ip": "192.168.0.1",
        "risk_score": 45,
        "failed_attempts": 3,
        "threat_level": "high",
        "is_locked": true,
        "ip_blocked": true,
        "anomaly_count": 2
      },
      ...
    ]
    """
    try:
        db = Database.get_db()
        if db is None:
            raise HTTPException(status_code=500, detail="Database connection failed")

        metrics_list = []
        
        # 1. Fetch Users with Risk Data
        users = list(db.users.find({}, {"_id": 1, "email": 1, "risk_score": 1, "mfa_enabled": 1, "is_locked": 1}))
        
        for user in users:
            uid = str(user["_id"])
            
            # Get latest activity for IP
            last_activity = db.auth_activity.find_one(
                {"user_email": user.get("email")},
                sort=[("timestamp", -1)]
            )
            last_ip = last_activity.get("ip_address", "unknown") if last_activity else "unknown"

            # Check if this specific IP is blocked
            ip_blocked = False
            if last_ip != "unknown":
                ip_blocked = db.blocked_entities.find_one({"entity_value": last_ip, "entity_type": "ip"}) is not None

            # Count recent anomalies/logs
            anomaly_count = db.security_events.count_documents({
                "user_id": uid, 
                "severity": {"$in": ["medium", "high", "critical"]}
            })

            # Determine threat level
            score = user.get("risk_score", 0)
            threat_level = "low"
            if score >= 50: threat_level = "high"
            elif score >= 25: threat_level = "medium"

            metrics_list.append({
                "id": user.get("email", uid), # Use email as ID if available for readability
                "ip": last_ip,
                "risk_score": score,
                "failed_attempts": 0, # TODO: Track properly in user doc if needed
                "threat_level": threat_level,
                "is_locked": user.get("locked", False), # Assuming 'locked' field exists logic
                "ip_blocked": ip_blocked,
                "anomaly_count": anomaly_count
            })

        # 2. Fetch Anonymous Blocked IPs (that might not map to users)
        blocked_ips = list(db.blocked_entities.find({"entity_type": "ip"}))
        for block in blocked_ips:
            ip = block["entity_value"]
            # Check if we already covered this IP in the user list
            if any(m["ip"] == ip for m in metrics_list):
                continue
                
            metrics_list.append({
                "id": "Anonymous/Unknown",
                "ip": ip,
                "risk_score": 100, # Blocked = Max Risk
                "failed_attempts": block.get("block_count", 0),
                "threat_level": "high",
                "is_locked": True,
                "ip_blocked": True,
                "anomaly_count": 1
            })
            
        # Sort by risk score descending
        metrics_list.sort(key=lambda x: x["risk_score"], reverse=True)
        
        return metrics_list

    except Exception as e:
        print(f"Error fetching live metrics: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Failed to fetch live metrics")


@router.delete("/devices/{device_id}")
async def delete_device(device_id: str, current_user: dict = Depends(get_current_user)):
    """
    Remove a device from the user's trusted devices list.
    This effectively "forgets" the device but does not block it.
    If the device connects again, it will be treated as a new device.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")

    result = db.users.update_one(
        {"_id": current_user["_id"]},
        {"$pull": {"trusted_devices": {"device_id": device_id}}}
    )

    if result.modified_count == 0:
        # Check if it was because device wasn't found or random error
        # Actually, if it wasn't found in the list, modified_count is 0, which is fine to return success
        # But if we want to be strict:
        pass

    return {"success": True, "message": "Device removed successfully"}
