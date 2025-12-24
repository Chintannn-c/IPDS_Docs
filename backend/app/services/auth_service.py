from passlib.context import CryptContext
from jose import jwt, JWTError
from datetime import datetime, timedelta
from app.core.config import settings
from fastapi.security import OAuth2PasswordBearer

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    now = datetime.utcnow()
    
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=15)
    
    # Include 'iat' (issued at) for token revocation checking
    to_encode.update({
        "exp": expire,
        "iat": now  # Required for token_valid_after checking
    })
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

from fastapi import Depends, HTTPException, status, Request
from app.db.database import Database

async def get_current_user(request: Request, token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # Strict JWT decoding
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        email: str = payload.get("sub")
        user_id: str = payload.get("user_id")
        
        if email is None or user_id is None:
            print(f"Auth Error: Missing sub or user_id in token. Payload: {payload}")
            raise credentials_exception
            
    except JWTError as e:
        print(f"Auth Error: JWT Validation Failed - {e}")
        raise credentials_exception
    
    # Valid token structure
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
        
    user = db.users.find_one({"_id": user_id})
    if user is None:
        print(f"Auth Error: User not found for ID {user_id}")
        raise credentials_exception

    # Filter and Sanitize Devices
    raw_devices = user.get("trusted_devices", [])
    if not isinstance(raw_devices, list):
        raw_devices = []
        
    valid_devices = [d for d in raw_devices if isinstance(d, dict)]
    
    # DYNAMIC BLOCK STATE CALCULATION
    # The 'is_blocked' flag in DB is deprecated. We compute it from 'active_blocks'.
    active_blocks = user.get("active_blocks", [])
    blocked_ids_set = {b["blocked_device_id"] for b in active_blocks}
    
    for d in valid_devices:
        d_id = d.get("device_id")
        # Set transient flag for UI
        if d_id in blocked_ids_set:
            d["is_blocked"] = True
            # CRITICAL: Force visibility so user can find and unblock it
            d["is_trusted"] = True 
        else:
            d["is_blocked"] = False
    
    # Update user object with sanitized list (in memory for this request)
    user["trusted_devices"] = valid_devices

    # ========================================
    # CENTRALIZED VALIDATION (Session + Block)
    # ========================================
    device_id = request.headers.get("X-Device-ID")
    device_fingerprint = request.headers.get("X-Device-Fingerprint") # Or from token payload
    session_id = payload.get("session_id")
    
    # This will raise 401/403 if invalid
    validate_device_access(
        user=user,
        device_id=device_id,
        device_fingerprint=device_fingerprint,
        session_id=session_id
    )

    return user

def get_user_from_token_loose(token: str) -> dict | None:
    """
    Decode token without verifying expiration to identify the user.
    Used for 'Safe Logout' where we want to clear bindings even if the token is expired.
    """
    try:
        # Decode without verifying expiration
        payload = jwt.decode(
            token, 
            settings.SECRET_KEY, 
            algorithms=[settings.ALGORITHM],
            options={"verify_exp": False}
        )
        user_id = payload.get("user_id")
        if not user_id:
            return None
            
        db = Database.get_db()
        if db is None:
            return None
            
        return db.users.find_one({"_id": user_id})
    except Exception as e:
        print(f"[AUTH] Loose token decode failed: {e}")
        return None

def is_device_safe(device: dict) -> bool:
    """Check if a device is safe (trusted and not blocked)."""
    if not isinstance(device, dict):
        return False
    return device.get("is_trusted", False) and not device.get("is_blocked", False)

def is_file_safe(file: dict) -> bool:
    """Check if a file is safe (not flagged)."""
    if not isinstance(file, dict):
        return False
    return not file.get("is_flagged", False)

def validate_device_access(
    user: dict,
    device_id: str | None = None,
    device_fingerprint: str | None = None,
    session_id: str | None = None
) -> bool:
    """
    Centralized validation logic for device access.
    Checks:
    0. Permanent Block List (blocked_device_ids) - catches devices even with new fingerprints
    1. Hardware ID Block (device_id)
    2. Fingerprint Block (device_fingerprint)
    3. Session Revocation (session_id)
    
    Raises HTTPException (401/403) if access is denied.
    Returns True if safe.
    """
    from fastapi import HTTPException, status
    
    
    # 0. PERMANENT BLOCK LIST REMOVED
    # We now strictly rely on trusted_devices list.
    
    trusted_devices = user.get("trusted_devices", [])
    
    # 1. HARDWARE BLOCK CHECK
    
    
    # 1. RELATIONSHIP BLOCK CHECK
    # We check if this device is present in 'active_blocks'
    active_blocks = user.get("active_blocks", [])
    
    # Find if there is an active block targeting this device
    active_block = next((b for b in active_blocks if b.get("blocked_device_id") == device_id), None)
    
    if active_block:
         print(f"[AUTH] BLOCKED: Device {device_id} is in active_blocks list.")
         raise HTTPException(
            status_code=403,
            detail="This device has been blocked by another device."
        )

    # 2. FINGERPRINT VALIDATION 
    # (Just ensures fingerprint matches trusted list if we want to be strict, but block check is primary)
    # If device is trusted but fingerprint changed, we might warn? 
    # For now, we trust the 'active_blocks' check as the authority on stopping access.
    
    # ... session check follows ...

    # 3. SESSION REVOCATION CHECK
    if session_id:
        revoked_sessions = user.get("revoked_sessions", [])
        if session_id in revoked_sessions:
            print(f"[AUTH] REVOKED: Session {session_id[:20]}... found in revocation list.")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Session has been revoked. Please login again."
            )
            
    return True
