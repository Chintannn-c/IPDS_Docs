# app/websocket_manager.py
from fastapi import WebSocket, WebSocketDisconnect, Query, APIRouter, HTTPException
from typing import Dict, List
import jwt

# Import settings to use the same secret as auth
from app.core.config import settings
from app.services.auth_service import validate_device_access
from app.db.database import Database

router = APIRouter()

# ------------------------------
# JWT Configuration (use same as auth)
# ------------------------------
JWT_SECRET = settings.SECRET_KEY
JWT_ALGORITHM = settings.ALGORITHM

# ------------------------------
# Connection Manager
# ------------------------------
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)

    def disconnect(self, websocket: WebSocket, user_id: str):
        if user_id in self.active_connections:
            if websocket in self.active_connections[user_id]:
                self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def disconnect_user(self, user_id: str):
        """Disconnect all active connections for a specific user."""
        if user_id in self.active_connections:
            connections = self.active_connections[user_id][:]  # Copy list to avoid modification issues
            for connection in connections:
                try:
                    await connection.close(code=4000, reason="Logged out")
                except:
                    pass
            if user_id in self.active_connections:
                del self.active_connections[user_id]
            print(f"[WS] Disconnected all sessions for user {user_id}")

    async def send_personal_message(self, message: dict, user_id: str):
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_json(message)
                except:
                    pass

    async def broadcast(self, message: dict):
        for connections in self.active_connections.values():
            for connection in connections:
                try:
                    await connection.send_json(message)
                except:
                    pass
    
    async def force_logout_device(self, user_id: str, event_type: str, reason: str, device_name: str = None, device_fingerprint: str = None):
        """
        Send force logout event to a user's connected devices.
        event_type: 'force_logout', 'device_blocked', 'device_removed', 'session_invalid'
        """
        from datetime import datetime
        
        message = {
            "type": event_type,
            "data": {
                "title": self._get_event_title(event_type),
                "message": reason,
                "device_name": device_name,
                "device_fingerprint": device_fingerprint,
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "action": "logout_required"
            }
        }
        
        # Enhanced logging for debugging
        active_conns = len(self.active_connections.get(user_id, []))
        print(f"[WS] 🚨 Sending {event_type} to user {user_id}")
        print(f"[WS] Target Fingerprint: {device_fingerprint}")
        print(f"[WS] Active Connections: {active_conns}")
        
        await self.send_personal_message(message, user_id)
    
    def _get_event_title(self, event_type: str) -> str:
        titles = {
            "force_logout": "🚪 Session Ended",
            "device_blocked": "🚫 Device Blocked",
            "device_removed": "📱 Device Removed",
            "session_invalid": "⚠️ Session Invalid",
            "login_attempt": "⚠️ Login Attempt Detected"
        }
        return titles.get(event_type, "⚠️ Security Alert")
    
    async def create_and_broadcast_notification(
        self,
        user_id: str,
        title: str,
        message: str,
        category: str = "info",
        priority: str = "medium",
        data: dict = None,
        notification_type: str = "notification"
    ):
        """
        Create a persistent notification in the database and broadcast it via WebSocket.
        This ensures all notifications are available in notification history.
        """
        from app.api.notifications import create_notification_for_user
        from datetime import datetime
        
        db = Database.get_db()
        if db is not None:
            try:
                # Create persistent notification in database
                notification_doc = await create_notification_for_user(
                    db=db,
                    user_id=user_id,
                    title=title,
                    message=message,
                    category=category,
                    priority=priority,
                    data=data
                )
                
                # Broadcast via WebSocket
                ws_message = {
                    "type": notification_type,
                    "data": {
                        "id": str(notification_doc["_id"]),
                        "title": title,
                        "message": message,
                        "category": category,
                        "priority": priority,
                        "timestamp": notification_doc["created_at"].isoformat() + "Z",
                        **(data or {})
                    }
                }
                await self.send_personal_message(ws_message, user_id)
                
                print(f"[WS] Created and broadcast notification to user {user_id}: {title}")
            except Exception as e:
                print(f"[WS] Failed to create/broadcast notification: {e}")
                # Still send WebSocket even if DB fails
                ws_message = {
                    "type": notification_type,
                    "data": {
                        "title": title,
                        "message": message,
                        "category": category,
                        "priority": priority,
                        "timestamp": datetime.utcnow().isoformat() + "Z",
                        **(data or {})
                    }
                }
                await self.send_personal_message(ws_message, user_id)


manager = ConnectionManager()

# ------------------------------
# Decode JWT properly
# ------------------------------
def decode_token_get_user_id(token: str) -> str:
    try:
        decoded = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return decoded.get("user_id")
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

# ------------------------------
# WebSocket Endpoint
# FULL PATH: /ws/ipds/ws
# ------------------------------
@router.websocket("/ipds/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = Query(...)):
    # Validate token
    # Validate token and Check Device Access
    try:
        # Decode manually to get full payload for session_id
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
            raise HTTPException(status_code=401, detail="Invalid token")

        user_id = payload.get("user_id")
        session_id = payload.get("session_id")
        
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token payload")
            
        # Fetch user to validate device/session
        db = Database.get_db()
        user = db.users.find_one({"_id": user_id})
        if not user:
             raise HTTPException(status_code=401, detail="User not found")
             
        # CENTRALIZED VALIDATION
        # We don't have device_id/fingerprint in WS headers easily unless passed in Query
        # But we DO have session_id which is critical.
        # If the client passed device_fingerprint in query (recommended), use it.
        # (Assuming trusted frontend sends ?device_fingerprint=...)
        ws_fingerprint = dict(websocket.query_params).get("device_fingerprint")
        
        validate_device_access(
            user=user,
            session_id=session_id,
            device_fingerprint=ws_fingerprint
        )
            
    except HTTPException as e:
        print(f"[WS] Connection Rejected: {e.detail}")
        await websocket.close(code=4003) # Forbidden
        return
    except Exception as e:
        print(f"[WS] Connection Error: {e}")
        await websocket.close(code=1008)
        return

    # Register connection
    await manager.connect(websocket, user_id)

    # Send initial message
    await manager.send_personal_message({"msg": "Connected to IPDS WebSocket"}, user_id)

    # Keep listening
    try:
        while True:
            data = await websocket.receive_text()
            await manager.send_personal_message({"msg": f"Server received: {data}"}, user_id)

    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
        print(f"User {user_id} disconnected from WebSocket")
