from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query
from app.services.auth_service import get_current_user, is_device_safe, is_file_safe
from app.db.database import Database
from pydantic import BaseModel
from typing import List
from app.websocket_manager import manager
from jose import jwt, JWTError
from app.core.config import settings
from datetime import datetime

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

class IDSDashboardResponse(BaseModel):
    devices: List[DeviceStatus]
    files: List[FileStatus]
    logs: List[DashboardLogEntry]

@router.get("/dashboard", response_model=IDSDashboardResponse)
async def get_ids_dashboard(current_user: dict = Depends(get_current_user)):
    """
    Get IDS dashboard data for the current user.
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
    # Note: db.logs contains title, source, type, timestamp
    logs_cursor = db.logs.find({"user_id": current_user["_id"]}).sort("timestamp", -1).limit(20)
    logs = []
    for log in logs_cursor:
        logs.append(DashboardLogEntry(
            title=log.get("title", "Unknown Event"),
            source=log.get("source", "Unknown Source"),
            timestamp=log.get("timestamp", datetime.utcnow()),
            type=log.get("type", "info")
        ))

class RiskResponse(BaseModel):
    risk_score: int
    risk_level: str # LOW, MEDIUM, HIGH, CRITICAL
    threats: List[str]
    history: List[dict] # {date: str, score: int}

@router.get("/risk", response_model=RiskResponse)
async def get_risk_assessment(current_user: dict = Depends(get_current_user)):
    """
    Calculate and return the user's risk profile.
    """
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
        
    # Generate threats list based on data
    threats = []
    trusted_devices = current_user.get("trusted_devices", [])
    blocked_devices = [d for d in trusted_devices if d.get("is_blocked")]
    
    if blocked_devices:
        threats.append(f"{len(blocked_devices)} blocked devices detected")
        
    if risk_score > 50:
        threats.append("High number of failed login attempts")
        
    # Mock history for now (or fetch from logs aggregation)
    # In a real app, we'd aggregate logs by day
    from datetime import datetime, timedelta
    history = []
    for i in range(7):
        date = (datetime.utcnow() - timedelta(days=6-i)).strftime("%Y-%m-%d")
        # Mock score variation
        score = max(0, min(100, risk_score + (i * 2 - 5))) 
        history.append({"date": date, "score": score})

    return RiskResponse(
        risk_score=risk_score,
        risk_level=level,
        threats=threats,
        history=history
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
                # Keep connection alive, maybe handle incoming messages if needed
                data = await websocket.receive_text()
                # For now, we only push data, but we could handle client acks
                # print(f"Received from client: {data}")
        except WebSocketDisconnect:
            manager.disconnect(websocket, user_id)
            
    except Exception as e:
        print(f"WebSocket Error: {e}")
        try:
            await websocket.close(code=1011)
        except:
            pass # Already closed
