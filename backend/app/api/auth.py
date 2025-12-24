from fastapi import APIRouter, HTTPException, Depends, status, Request
from app.core.exceptions import DeviceBlockedException
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from app.models.schemas import UserCreate, Token, UserResponse, UserUpdate, PasswordChange, PasswordConfirmation, validate_strong_password
from app.models.notification_models import NotificationCategory, NotificationPriority
from app.services.auth_service import verify_password, get_password_hash, create_access_token, get_current_user, get_user_from_token_loose, validate_device_access
from app.db.database import Database
from app.websocket_manager import manager
from datetime import timedelta, datetime
from fastapi import UploadFile, File
from fastapi.responses import FileResponse
import os
import shutil
from app.core.config import settings
import uuid
from app.core.email_utils import generate_otp, send_otp_email, send_security_alert_email


router = APIRouter()

# Global state to prevent concurrent /me requests from the same user
# This mitigates redundant database aggregation calls when the client (Flutter)
# triggers profile fetches from multiple UI controllers simultaneously.
inflight_me_requests = set()

@router.post("/register", response_model=UserResponse)
async def register(user: UserCreate):
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")

    existing_user = db.users.find_one({"email": user.email})
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_password = get_password_hash(user.password)
    new_user = {
        "_id": str(uuid.uuid4()),
        "email": user.email,
        "name": user.name,
        "password_hash": hashed_password,
        "role": "user",
        "risk_score": 0,
        "trusted_devices": [],
        "storage_limit": 5368709120,  # 5 GB
    }
    db.users.insert_one(new_user)
    return UserResponse(id=new_user["_id"], email=new_user["email"], name=new_user["name"], role=new_user["role"], risk_score=new_user["risk_score"])

@router.post("/login")
async def login(request: Request, form_data: OAuth2PasswordRequestForm = Depends()):
    from .logs import create_auth_activity  # For auth activity logging
    from app.core.security import DeviceFingerprint  # For fingerprint generation
    from app.core.device_utils import (
        parse_user_agent,
        get_location_from_ip,
        generate_session_id
    )

    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")

    # Extract device info and generate fingerprint
    device_name = request.headers.get("X-Device-Name", "Unknown Device")
    client_ip = request.client.host if request.client else "unknown"
    device_id = request.headers.get("X-Device-ID")
    if device_id:
        device_id = device_id.strip()
    device_type = request.headers.get("X-Device-Type", "unknown")
    user_agent = request.headers.get("user-agent", "")
    
    # Prefer client-provided fingerprint (for biometric login compatibility)
    # Fall back to server-generated fingerprint if not provided
    client_fingerprint = request.headers.get("X-Device-Fingerprint")
    
    if client_fingerprint:
        device_fingerprint = client_fingerprint
    else:
        # Generate device fingerprint from headers (legacy fallback)
        device_info = DeviceFingerprint.extract_from_headers(dict(request.headers))
        device_fingerprint = DeviceFingerprint.generate_fingerprint(
            device_info["user_agent"],
            device_info["accept_language"],
            device_info["platform"],
            device_info.get("screen_info"),
            device_info.get("timezone")
        )
    
    # CORE: Parse OS and Browser from User-Agent (basic detection)
    device_details = parse_user_agent(user_agent)
    os_name = device_details.get("os", "Unknown")
    browser_or_app = device_details.get("browser_or_app", "Unknown")
    
    # CORE: Simple location (just IP for now)
    location = get_location_from_ip(client_ip)
    
    # CORE: Generate unique session ID
    session_id = generate_session_id()
    
    # ========================================
    # 1. VERIFY USER CREDENTIALS
    # ========================================
    user = db.users.find_one({"email": form_data.username})
    
    if not user or not verify_password(form_data.password, user["password_hash"]):
        # ========================================
        # BRUTE FORCE PROTECTION
        # ========================================
        # Get current failed attempts
        failed_attempts = user.get("failed_login_attempts", 0) + 1 if user else 0
        
        # Only if user exists, we track attempts (to avoid enumeration, though timing attacks are still possible)
        if user:
            
            # Update failed attempts
            db.users.update_one(
                {"_id": user["_id"]},
                {"$set": {
                    "failed_login_attempts": failed_attempts,
                    "last_failed_login": datetime.utcnow()
                }}
            )
            
            # Check limit (3 attempts for early warning, then every 3)
            if failed_attempts >= 3:
                # 1. Trigger IPDS Alert (Log as High Severity)
                create_auth_activity(
                    title="Brute Force Attempt Detected",
                    device_name=device_name,
                    ip_address=client_ip,
                    activity_type="brute_force_attempt",
                    user_email=user["email"],
                    user_name=user.get("name"),
                    user_id=str(user["_id"])
                )
                
                # 2. Send WebSocket Notification (if user is logged in elsewhere)
                # 2. Send WebSocket Notification (if user is logged in elsewhere)
                try:
                    await manager.send_personal_message({
                        "type": "notification",
                        "data": {
                            "title": "⚠️ Security Alert",
                            "message": f"{failed_attempts} failed login attempts detected from {device_name} ({client_ip}). Check your email.",
                            "severity": "danger",
                            "timestamp": datetime.utcnow().isoformat() + "Z"
                        }
                    }, str(user["_id"]))
                except Exception as ws_error:
                    print(f"[WARN] Failed to send WebSocket notification: {ws_error}")
                
                # 3. Send Email Alert at threshold and every 3 attempts after
                # Send at 3, 6, 9, 12... attempts
                if failed_attempts % 3 == 0:
                    try:
                        alert_msg = f"We detected {failed_attempts} failed login attempts on your account from {device_name} (IP: {client_ip})."
                        email_sent = send_security_alert_email(user["email"], alert_msg)
                        if email_sent:
                            print(f"[INFO] Brute force alert email sent to {user['email']} ({failed_attempts} attempts)")
                        else:
                            print(f"[ERROR] Failed to send brute force alert email to {user['email']}")
                    except Exception as email_error:
                        print(f"[ERROR] Exception sending brute force email: {email_error}")
            
            # Log the normal failed attempt too
            create_auth_activity(
                title=f"Failed Login Attempt ({failed_attempts})",
                device_name=device_name,
                ip_address=client_ip,
                activity_type="failed_login",
                user_email=user["email"]
            )
        else:
            # Log failed login for non-existent user
            create_auth_activity(
                title="Failed Login (Unknown User)",
                device_name=device_name,
                ip_address=client_ip,
                activity_type="failed_login",
                user_email=form_data.username
            )

        raise HTTPException(status_code=401, detail="Incorrect email or password")
    
    # ========================================
    # 2. MULTI-DEVICE SUPPORT (Enabled)
    # ========================================
    # We allow multiple devices. No strict lock check here.
    pass


    # ========================================
    # 3. DEVICE MANAGEMENT (existing logic)
    # ========================================
    # Ensure trusted_devices is a list
    trusted_devices = user.get("trusted_devices", [])
    if not isinstance(trusted_devices, list):
        trusted_devices = []

    print(f"[DEBUG] Checkpoint 2: Trusted Devices loaded: {len(trusted_devices)}")
    print(f"----- DEBUG: TRUSTED DEVICES DUMP -----")
    print(f"Incoming Device ID: {device_id}")
    for i, d in enumerate(trusted_devices):
        print(f"  [{i}] ID: {d.get('device_id')} | FP: {d.get('fingerprint')[:10]}... | Blocked: {d.get('is_blocked')}")
    print(f"---------------------------------------")
    
    print(f"----- FINGERPRINT DEBUG -----")
    print(f"RECEIVED: {device_fingerprint}")
    print(f"STORED:   {[d.get('fingerprint') for d in trusted_devices]}")
    print(f"-----------------------------")
    
    # CRITICAL: Hardware-Level Block & Centralized Validation
    # Use the shared logic to check hardware block before proceeding
    validate_device_access(
        user=user,
        device_id=device_id,
        device_fingerprint=client_fingerprint  # Check fingerprint if provided at login start
    )

    # ========================================
    # GLOBAL BLOCK CHECK (FAILSAFE)
    # ========================================
    # Explicitly iterate ALL devices to check for Hardware Block.
    # This catches cases where device_id match exists but wasn't caught by validate_device_access
    # or if there are duplicate entries where one is blocked.
    if device_id:
        for d in trusted_devices:
            if d.get("device_id") == device_id and d.get("is_blocked"):
                print(f"[AUTH] BLOCKED: Hardware ID {device_id} (Global Failsafe)")
                
                # Notify User of Blocked Attempt
                await manager.create_and_broadcast_notification(
                    user_id=str(user["_id"]),
                    title="Security Alert: Blocked Device",
                    message=f"A blocked device ({d.get('name', 'Unknown')}) attempted to log in.",
                    category=NotificationCategory.SECURITY.value,
                    priority=NotificationPriority.CRITICAL.value,
                    data={
                        "device_name": d.get("name", "Unknown"),
                        "device_id": device_id,
                        "ip_address": client_ip,
                        "time": datetime.utcnow().isoformat()
                    },
                    notification_type="blocked_login_attempt"
                )
                
                raise HTTPException(
                    status_code=403,
                    detail="This device hardware is blocked from accessing the account."
                )
    
    is_new_device = False
    
    
    # CRITICAL FIX: Match by fingerprint ONLY (exact match)
    # Each unique fingerprint = separate device entry
    # This prevents Device A from overwriting Device B
    device_index = -1
    for index, d in enumerate(trusted_devices):
        if not isinstance(d, dict):
            continue
        
        # Match ONLY by fingerprint (must be exact match)
        if device_fingerprint and d.get("fingerprint") == device_fingerprint:
            device_index = index
            print(f"[DEBUG] Found existing device at index {index} (fingerprint match)")
            break
            
    # CRITICAL FIX: Deduplication
    # If not found by fingerprint, check by Hardware ID to prevent duplicates
    # This handles cases where fingerprint changed (app reinstall) but device is same
    if device_index == -1 and device_id:
        for index, d in enumerate(trusted_devices):
             if not isinstance(d, dict): continue
             if d.get("device_id") == device_id:
                 device_index = index
                 print(f"[DEBUG] Found existing device at index {index} (Hardware ID match: {device_id})")
                 # We will update this entry with new fingerprint later
                 break
    
    if device_index != -1:
        device = trusted_devices[device_index]
        is_blocked = device.get("is_blocked", False)
        print(f"[DEBUG] Device Match Found: Index {device_index}, Blocked={is_blocked}")
        
        if is_blocked:
            print(f"[DEBUG] BLOCKED DEVICE DETECTED. Rejecting login.")
            
            # Notify User of Blocked Attempt
            await manager.create_and_broadcast_notification(
                user_id=str(user["_id"]),
                title="Security Alert: Blocked Device",
                message=f"A blocked device ({device.get('name', 'Unknown')}) attempted to log in.",
                category=NotificationCategory.SECURITY.value,
                priority=NotificationPriority.CRITICAL.value,
                data={
                    "device_name": device.get("name", "Unknown"),
                    "device_fingerprint": device_fingerprint,
                    "ip_address": client_ip,
                    "time": datetime.utcnow().isoformat()
                },
                notification_type="blocked_login_attempt"
            )
            
            create_auth_activity(
                title="Blocked Device Access Attempt",
                device_name=device_name,
                ip_address=client_ip,
                activity_type="blocked_device",
                user_email=user["email"],
                user_name=user.get("name"),
                user_id=str(user["_id"])
            )
            raise DeviceBlockedException(
                detail="Device Blocked",
                device_id=device_id,
                device_name=device_name
            )
        
        # Update existing device - sync both device_id and fingerprint + SESSION
        device["last_active"] = datetime.utcnow()
        device["last_login"] = datetime.utcnow().isoformat()
        device["name"] = device_name
        device["ip_address"] = client_ip
        device["fingerprint"] = device_fingerprint  # Store/update fingerprint
        
        # CORE: Update session and enhanced fields on re-login
        device["session_id"] = session_id  # New session each login
        device["account_id"] = str(user["_id"])
        device["os"] = os_name
        device["browser_or_app"] = browser_or_app
        device["location"] = location
        device["is_current_device"] = True  # This device is now current
        device["is_active"] = True
        # CRITICAL: Preserve Block Status
        # If the device somehow got here but was blocked (race condition or logic gap),
        # we MUST NOT overwrite is_blocked to False by omission.
        current_blocked_status = device.get("is_blocked", False)
        device["is_blocked"] = current_blocked_status
        
        # Only trust if not blocked
        device["is_trusted"] = not current_blocked_status
        
        # DOUBLE CHECK: Re-verify block status just in case
        if device.get("is_blocked", False):
             raise HTTPException(status_code=403, detail="Device is blocked")
        
        if device_id:
            device["device_id"] = device_id  # Sync device_id
        trusted_devices[device_index] = device
        print(f"[DEBUG] Updated existing device at index {device_index} with new session {session_id[:8]}...")
        
    else:
        # 3. Check Trusted/Blocked Status (Logic moved from permanent block list)
        
        # Check if this device is explicitly blocked in trusted_devices (Hardware Block)
        # We don't have the full trusted list easily accessible here without fetching user again? 
        # Actually we have 'user' object.
        trusted_devices = user.get("trusted_devices", [])
        
        # Check for Hardware Block
        hardware_blocked = next(
            (d for d in trusted_devices if d.get("device_id") == device_id and d.get("is_blocked")), 
            None
        )
        
        if hardware_blocked:
             print(f"[LOGIN] BLOCKED: Hardware ID {device_id} is explicitly blocked.")
             raise HTTPException(
                status_code=403,
                detail="This device is blocked from accessing the account."
            )

        # Check for Fingerprint Block
        # If fingerprint changed, we might not match. That's the trade-off of removing permanent block list.
        # But if the fingerprint is known and blocked:
        fingerprint_blocked = next(
            (d for d in trusted_devices if d.get("fingerprint") == client_fingerprint and d.get("is_blocked")),
            None
        )
        if fingerprint_blocked:
             print(f"[LOGIN] BLOCKED: Fingerprint {client_fingerprint} is blocked.")
             raise HTTPException(
                status_code=403,
                detail="This device is blocked from accessing the account."
            )
        
        is_new_device = True
        from app.models.schemas import TrustedDevice
        
        # Create using Pydantic model for validation/defaults with ENHANCED fields
        new_device_obj = TrustedDevice(
            device_id=device_id or device_fingerprint[:16],
            name=device_name,
            type=device_type,
            
            # Session & Account
            session_id=session_id,
            account_id=str(user["_id"]),
            
            # Enhanced Detection
            os=os_name,
            browser_or_app=browser_or_app,
            location=location,
            
            # Status Flags
            is_current_device=True,  # This is the device logging in
            is_trusted=True,
            is_blocked=False,
            is_active=True,
            
            # Tracking
            last_active=datetime.utcnow(),
            created_at=datetime.utcnow(),
            ip_address=client_ip,
            fingerprint=device_fingerprint
        )
        
        new_device_dict = new_device_obj.dict()
        new_device_dict["first_login"] = datetime.utcnow().isoformat()
        new_device_dict["last_login"] = datetime.utcnow().isoformat()
        trusted_devices.append(new_device_dict)
        print(f"[DEBUG] Added new device. Total devices now: {len(trusted_devices)}")
    
    # ========================================
    # 4. MULTI-DEVICE MANAGEMENT
    # ========================================
    # Check if this specific device is BLOCKED
    if device_index != -1:
        existing_device = trusted_devices[device_index]
        if existing_device.get("is_blocked", False):
             print(f"[LOGIN] Blocked: Device {device_fingerprint[:8]}... is manually blocked.")
             create_auth_activity(
                title="Login Blocked (Manual Check)",
                device_name=device_name,
                ip_address=client_ip,
                activity_type="blocked_login_manual",
                user_email=user["email"]
            )
             raise HTTPException(
                status_code=403,
                detail="You are blocked and cannot login until unblocked.",
                headers={"X-Error-Type": "device_blocked"}
            )

    # Generate new session token
    import secrets
    session_token = secrets.token_urlsafe(32)
    
    # 5. Notify about new login with persistent notification  
    await manager.create_and_broadcast_notification(
        user_id=str(user["_id"]),
        title="New Device Login",
        message=f"New login from {device_name}",
        category=NotificationCategory.SECURITY.value,
        priority=NotificationPriority.HIGH.value,
        data={
            "device_name": device_name,
            "device_fingerprint": device_fingerprint,
            "time": datetime.utcnow().isoformat()
        },
        notification_type="new_device_login"  # Keep the type for compatibility
    )

    # Bind this device (Multi-device friendly - just update session info)
    # We NO LONGER set active_device=1 or clear others.
    print(f"[DEBUG] Saving trusted_devices: {[d.get('fingerprint') for d in trusted_devices]}")
    db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {
            "is_logged_in": True,
            "session_token": session_token,
            "last_login": datetime.utcnow(),
            "failed_login_attempts": 0,
            "trusted_devices": trusted_devices,
            # Rule 5: Store active device info
            "active_device": {
                "device_id": device_id,
                "name": device_name,
                "fingerprint": device_fingerprint,
                "login_time": datetime.utcnow().isoformat(),
                "ip_address": client_ip
            }
        },
         "$unset": {
             # Clean up legacy fields if any, but KEEP active_device
            "bound_devices": "",
            "active_fingerprint": "" 
        }}
    )
    
    # Hygiene: Atomic trim of revoked_sessions to keep only last 50
    # This acts as a garbage collector for old revoked tokens
    db.users.update_one(
        {"_id": user["_id"]},
        {"$push": {"revoked_sessions": {"$each": [], "$slice": -50}}}
    )
    
    print(f"[LOGIN] Device {device_fingerprint[:20]}... bound to {user['email']}")
    
    create_auth_activity(
        title="Device Bound & Login Success",
        device_name=device_name,
        ip_address=client_ip,
        activity_type="device_bound",
        user_email=user["email"],
        user_name=user.get("name"),
        user_id=str(user["_id"])
    )
            
    # Log successful login
    create_auth_activity(
        title="Successful Login",
        device_name=device_name,
        ip_address=client_ip,
        activity_type="login",
        user_email=user["email"],
        user_name=user.get("name"),
        user_id=str(user["_id"])
    )
    
    # ========================================
    # 5. MFA CHECK
    # ========================================
    if user.get("mfa_enabled"):
        # MFA is enabled - send OTP to email
        from app.core.email_utils import generate_otp, send_otp_email
        
        otp_code = generate_otp(settings.MFA_OTP_LENGTH)
        otp_expires = datetime.utcnow() + timedelta(minutes=settings.MFA_OTP_EXPIRE_MINUTES)
        
        # Store OTP for login verification
        db.users.update_one(
            {"_id": user["_id"]},
            {"$set": {
                "mfa_login_otp": otp_code,
                "mfa_login_otp_expires": otp_expires.isoformat()
            }}
        )
        
        # Send OTP via email
        if not send_otp_email(user["email"], otp_code, purpose="login"):
            raise HTTPException(status_code=500, detail="Failed to send verification email. Please try again later.")
        
        return {
            "mfa_required": True,
            "email": user["email"],
            "message": "Verification code sent to your email",
            "expires_in_minutes": settings.MFA_OTP_EXPIRE_MINUTES,
            "is_new_device": is_new_device,
            "debug_otp": otp_code
        }
    
    # No MFA - generate token directly with session_id
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={
            "sub": user["email"], 
            "user_id": user["_id"],
            "session_id": session_id  # Add session ID for revocation tracking
        }, 
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer", "is_new_device": is_new_device}

@router.get("/devices", response_model=list[dict])
async def get_devices(current_user: dict = Depends(get_current_user)):
    return current_user.get("trusted_devices", [])

@router.get("/debug/devices")
async def debug_devices(current_user: dict = Depends(get_current_user)):
    """Debug endpoint to show raw device data from database"""
    trusted_devices = current_user.get("trusted_devices", [])
    return {
        "user_id": str(current_user["_id"]),
        "user_email": current_user.get("email"),
        "device_count": len(trusted_devices),
        "devices": trusted_devices,
        "device_names": [d.get("name", "Unknown") for d in trusted_devices],
        "device_fingerprints": [d.get("fingerprint", "N/A")[:20] + "..." for d in trusted_devices]
    }

@router.get("/debug/devices-raw")
async def debug_devices_raw(current_user: dict = Depends(get_current_user)):
    """Debug endpoint to see raw device data from DB"""
    db = Database.get_db()
    # Fetch fresh from DB to avoid any middleware mods
    raw_user = db.users.find_one({"_id": current_user["_id"]})
    return {
        "trusted_devices": raw_user.get("trusted_devices"),
        "revoked_sessions": raw_user.get("revoked_sessions"),
        "is_logged_in": raw_user.get("is_logged_in")
    }

from pydantic import BaseModel

class DeviceAction(BaseModel):
    device_id: str

@router.get("/devices", response_model=list[dict])
async def get_devices(current_user: dict = Depends(get_current_user)):
    """Fetch the list of trusted devices for the current user."""
    return current_user.get("trusted_devices", [])

@router.post("/devices/toggle-trust")
async def toggle_device_trust(action: DeviceAction, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    trusted_devices = current_user.get("trusted_devices", [])
    device_id = action.device_id
    
    device_index = next((index for (index, d) in enumerate(trusted_devices) if d["device_id"] == device_id), -1)
    
    print(f"DEBUG: Request Device ID: {device_id}")
    # print(f"DEBUG: Stored Device IDs: {[d.get('device_id') for d in trusted_devices]}")

    # Atomic Update: Find specific device and toggle its trust status
    # 1. Get current status to determine target boolean (we still need a read, but the write will be atomic on the specific field)
    # Optimization: Use arrayFilters to handle potential duplicates if any, or just positional $ for first match.
    # Given we want to toggle, we first find the device.
    
    target_device = next((d for d in trusted_devices if d.get("device_id") == device_id), None)
    if not target_device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    new_trust_state = not target_device.get("is_trusted", False)
    
    # Atomic Set: Only modify the 'is_trusted' field of the matching device(s)
    # Using arrayFilters allows us to update ALL duplicates if they exist, keeping them in sync.
    result = db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {"trusted_devices.$[elem].is_trusted": new_trust_state}},
        array_filters=[{"elem.device_id": device_id}]
    )
    
    if result.modified_count == 0:
        print(f"[WARN] Toggle trust failed for device {device_id}")
        
    target_device["is_trusted"] = new_trust_state
    return target_device

@router.post("/devices/toggle-block")
async def toggle_device_block(action: DeviceAction, request: Request, current_user: dict = Depends(get_current_user)):
    print(f"✅ HIT ENDPOINT: /devices/toggle-block with ID: {action.device_id}")
    db = Database.get_db()
    
    # 1. Identify BLOCKER (Current Device)
    blocker_device_id = request.headers.get("X-Device-ID")
    if not blocker_device_id:
        # Fallback if header missing (though it should be there), usually 400, but proceed as "admin" action?
        blocker_device_id = "unknown_admin" 

    target_device_id = action.device_id
    
    if blocker_device_id == target_device_id:
        raise HTTPException(status_code=400, detail="You cannot block your current device.")
    
    user_id = current_user["_id"]
    
    # 2. Check Request Type (Are we Blocking or Unblocking?)
    # We check if an active block already exists
    existing_block = db.users.find_one(
        {
            "_id": user_id, 
            "active_blocks": {
                "$elemMatch": {
                    "blocked_device_id": target_device_id
                    # We can enforce "blocker_device_id" match if we want ownership, 
                    # but usually "Unblock" works regardless of who blocked it for user convenience.
                }
            }
        }
    )
    
    is_currently_blocked = existing_block is not None
    should_block = not is_currently_blocked
    
    print(f"[DEBUG] Relationship Block: Current={is_currently_blocked} -> New={should_block} (Target: {target_device_id})")

    if should_block:
        # --- EXECUTE BLOCK ---
        block_record = {
            "blocker_device_id": blocker_device_id,
            "blocked_device_id": target_device_id,
            "blocked_at": datetime.utcnow().isoformat(),
            "reason": "User toggled block",
            "status": "active"
        }
        
        # Add to active_blocks
        db.users.update_one(
            {"_id": user_id},
            {"$push": {"active_blocks": block_record}}
        )
        
        # Revoke Sessions for Target
        trusted_devices = current_user.get("trusted_devices", [])
        sessions_to_revoke = [d["session_id"] for d in trusted_devices if d.get("device_id") == target_device_id and d.get("session_id")]
        
        if sessions_to_revoke:
            db.users.update_one(
                {"_id": user_id},
                {"$addToSet": {"revoked_sessions": {"$each": sessions_to_revoke}}}
            )

        # Send WebSocket Logout
        # Find device details for nice message
        target_device_details = next((d for d in trusted_devices if d.get("device_id") == target_device_id), {})
        if target_device_details:
             await manager.force_logout_device(
                user_id=str(user_id),
                event_type="device_blocked",
                reason="Access restricted by another device",
                device_name=target_device_details.get("name"),
                device_fingerprint=target_device_details.get("fingerprint")
            )

    else:
        # --- EXECUTE UNBLOCK ---
        # Remvoe from active_blocks
        db.users.update_one(
            {"_id": user_id},
            {"$pull": {"active_blocks": {"blocked_device_id": target_device_id}}}
        )
        print(f"[UNBLOCK] Removed {target_device_id} from active_blocks")
        
    # 3. Return Updated Device Object for Frontend
    # Frontend expects "is_blocked" flag. We construct it artificially.
    # Re-fetch user to get latest state (or just modify in memory)
    updated_user = db.users.find_one({"_id": user_id})
    all_blocks = updated_user.get("active_blocks", [])
    
    # Check if target is blocked in valid list
    is_now_blocked = any(b["blocked_device_id"] == target_device_id for b in all_blocks)
    
    # Return a device-like object
    # Find the device info
    trusted = updated_user.get("trusted_devices", [])
    device_info = next((d for d in trusted if d.get("device_id") == target_device_id), {})
    
    if not device_info:
        # Return minimal stub if we can't find it (shouldn't happen if UI called it)
        return {"device_id": target_device_id, "is_blocked": is_now_blocked, "is_trusted": True}
        
    device_info["is_blocked"] = is_now_blocked
    return device_info

@router.post("/devices/remove")
async def remove_device(action: DeviceAction, request: Request, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    trusted_devices = current_user.get("trusted_devices", [])
    device_id = action.device_id
    
    # Atomic Remove: 
    # 1. Find device details first (for session revocation and logging)
    # 2. Atomic $pull to remove from list
    # 3. Atomic $addToSet to revoke session
    
    target_device = next((d for d in trusted_devices if d.get("device_id") == device_id), None)
    if not target_device:
        raise HTTPException(status_code=404, detail="Device not found")
        
    removed_device = target_device # Keep ref for logging
    sessions_to_revoke = []
    
    # Check for all duplicates to revoke their sessions too
    for d in trusted_devices:
        if d.get("device_id") == device_id and d.get("session_id"):
            sessions_to_revoke.append(d.get("session_id"))

    # Atomic Update Operation
    # Just remove from trusted_devices
    update_op = {
        "$pull": {
            "trusted_devices": {"device_id": device_id}
        }
    }
    
    if sessions_to_revoke:
        update_op["$addToSet"] = {"revoked_sessions": {"$each": sessions_to_revoke}}
        print(f"[DEVICE_REMOVE] Revoking sessions: {sessions_to_revoke}")
    
    result = db.users.update_one(
        {"_id": current_user["_id"]},
        update_op
    )
    
    # Trigger force logout for the specific device
    await manager.force_logout_device(
        user_id=str(current_user["_id"]),
        event_type="force_logout",
        reason="Your device was removed from trusted devices",
        device_name=removed_device.get("name"),
        device_fingerprint=removed_device.get("fingerprint")
    )

    # Check if we removed the CURRENT device
    # Pass 'force_logout': True in response if so, for instant frontend reaction
    current_fingerprint = dict(request.headers).get("x-device-fingerprint") or \
                          dict(request.query_params).get("device_fingerprint")
    
    is_current_device = False
    if current_fingerprint and current_fingerprint == removed_device.get("fingerprint"):
        is_current_device = True

    return {
        "message": "Device removed successfully",
        "target_device": device_id,
        "force_logout": is_current_device
    }

@router.get("/me", response_model=UserResponse)
async def read_users_me(current_user: dict = Depends(get_current_user)):
    user_id = str(current_user["_id"])
    
    # 1. Concurrency Check
    if user_id in inflight_me_requests:
        # Return 429 with custom JSON to help frontend handle it silently
        raise HTTPException(
            status_code=429,
            detail={
                "status": "locked",
                "message": "Profile request already in progress. Please await current one.",
                "error_type": "concurrency_lock"
            }
        )
    
    inflight_me_requests.add(user_id)
    
    try:
        db = Database.get_db()
        
        # Calculate storage used
        pipeline = [
            {"$match": {"owner_id": current_user["_id"]}},
            {"$group": {"_id": None, "total_size": {"$sum": "$size"}}}
        ]
        result = list(db.files.aggregate(pipeline))
        storage_used = result[0]["total_size"] if result else 0
        
        return UserResponse(
            id=current_user["_id"],
            email=current_user["email"],
            name=current_user["name"],
            role=current_user["role"],
            risk_score=current_user.get("risk_score", 0),
            profile_image=current_user.get("profile_image"),
            trusted_devices=current_user.get("trusted_devices", []),
            storage_used=storage_used,
            storage_limit=current_user.get("storage_limit", 5368709120)
        )
    finally:
        # Ensure ID is removed even if error occurs
        inflight_me_requests.discard(user_id)

@router.post("/devices/check-status")
async def check_device_status(request: Request, current_user: dict = Depends(get_current_user)):
    """Check if the current device is still allowed to access the account."""
    body = await request.json()
    device_fingerprint = body.get("device_fingerprint")
    
    if not device_fingerprint:
        raise HTTPException(status_code=400, detail="Device fingerprint required")

    # 1. CENTRALIZED VALIDATION
    # Use the shared logic to check block/revocation status
    validate_device_access(
        user=current_user,
        device_id=request.headers.get("X-Device-ID"),
        device_fingerprint=device_fingerprint
    )
    
    trusted_devices = current_user.get("trusted_devices", [])
    
    # Find the device
    device = next(
        (d for d in trusted_devices if d.get("fingerprint") == device_fingerprint),
        None
    )
    
    if not device:
        # Device not found - could be removed
        raise HTTPException(
            status_code=403, 
            detail="Device not found. You have been logged out."
        )
    
    
    if device.get("is_blocked", False):
        raise HTTPException(
            status_code=403, 
            detail="This device has been blocked. You have been logged out."
        )
    
    # CRITICAL: Second Layer Hardware Check
    # Even if fingerprint matches an 'active' device, check if HARDWARE ID is blocked
    # This catches cases where a device generated a new fingerprint but is physically blocked
    device_id = request.headers.get("X-Device-ID")
    if device_id:
        device_id = device_id.strip()
        hardware_blocked = next((d for d in trusted_devices if d.get("device_id") == device_id and d.get("is_blocked")), None)
        if hardware_blocked:
            print(f"[DEBUG] check_status: HARDWARE BLOCK DETECTED (ID: {device_id}). Denying access.")
            raise HTTPException(
                status_code=403, 
                detail="This device specific hardware is blocked."
            )

    return {"status": "active", "device_id": device.get("device_id")}

@router.put("/me", response_model=UserResponse)
async def update_user_me(user_update: UserUpdate, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    
    update_data = {k: v for k, v in user_update.dict().items() if v is not None}
    
    if "email" in update_data:
        # Check if email is already taken by another user
        existing_user = db.users.find_one({"email": update_data["email"]})
        if existing_user and existing_user["_id"] != current_user["_id"]:
            raise HTTPException(status_code=400, detail="Email already registered")
            
    if update_data:
        db.users.update_one({"_id": current_user["_id"]}, {"$set": update_data})
        
    # Fetch updated user
    updated_user = db.users.find_one({"_id": current_user["_id"]})
    
    return UserResponse(
        id=updated_user["_id"],
        email=updated_user["email"],
        name=updated_user["name"],
        role=updated_user["role"],
        risk_score=updated_user.get("risk_score", 0),
        profile_image=updated_user.get("profile_image"),
        trusted_devices=updated_user.get("trusted_devices", [])
    )

@router.post("/profile-image", response_model=UserResponse)
async def upload_profile_image(file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
    # Create upload directory if not exists
    upload_dir = "uploads/avatars"
    os.makedirs(upload_dir, exist_ok=True)
    
    # Generate unique filename
    file_extension = os.path.splitext(file.filename)[1]
    filename = f"{current_user['_id']}_{int(datetime.utcnow().timestamp())}{file_extension}"
    file_path = os.path.join(upload_dir, filename)
    
    # Save file
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # Update user profile
    db = Database.get_db()
    db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {"profile_image": f"/auth/profile-image/{filename}"}}
    )
    
    updated_user = db.users.find_one({"_id": current_user["_id"]})
    
    return UserResponse(
        id=updated_user["_id"],
        email=updated_user["email"],
        name=updated_user["name"],
        role=updated_user["role"],
        risk_score=updated_user.get("risk_score", 0),
        profile_image=updated_user.get("profile_image"),
        trusted_devices=updated_user.get("trusted_devices", [])
    )

@router.get("/profile-image/{filename}")
async def get_profile_image(filename: str):
    file_path = os.path.join("uploads/avatars", filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Image not found")
    return FileResponse(file_path)

@router.post("/change-password")
async def change_password(
    request: Request,
    password_data: PasswordChange,
    current_user: dict = Depends(get_current_user)
):
    from .logs import create_auth_activity
    from app.websocket_manager import manager
    
    db = Database.get_db()
    
    # Verify current password
    if not verify_password(password_data.current_password, current_user["password_hash"]):
        raise HTTPException(status_code=400, detail="Incorrect current password")
        
    # Update password and reduce risk score
    new_hash = get_password_hash(password_data.new_password)
    current_risk = current_user.get("risk_score", 0)
    new_risk = max(0, current_risk - 30)
    
    # Set token_valid_after to 1 second ago
    # This ensures the new token we generate AFTER this will be valid
    # while all OLD tokens (issued before this time) become invalid
    token_cutoff = datetime.utcnow() - timedelta(seconds=1)
    
    # Invalidate ALL sessions and clear trusted devices
    db.users.update_one(
        {"_id": current_user["_id"]},
        {
            "$set": {
                "password_hash": new_hash,
                "risk_score": new_risk,
                "token_valid_after": token_cutoff,  # Revoke old tokens
                "trusted_devices": []  # Clear all trusted devices
            },
            "$unset": {
                "device_fingerprint": "",  # Reset device binding
                "fingerprint_bound_at": ""
            }
        }
    )
    
    # Log the password change activity
    device_name = request.headers.get("X-Device-Name", "Unknown Device")
    client_ip = request.client.host if request.client else "unknown"
    
    create_auth_activity(
        title="Password Changed - All Devices Logged Out",
        device_name=device_name,
        ip_address=client_ip,
        activity_type="password_change",
        user_email=current_user["email"],
        user_name=current_user.get("name"),
        user_id=str(current_user["_id"])
    )
    
    # Broadcast logout event to all connected devices for this user
    try:
        await manager.send_personal_message({
            "type": "force_logout",
            "data": {
                "reason": "password_changed",
                "message": "Your password was changed. Please login again with your new password."
            }
        }, str(current_user["_id"]))
    except Exception as e:
        print(f"[WARN] Failed to broadcast logout event: {e}")
    
    # Clear all negative login activity (failed logins, blocked device attempts, etc.)
    # This resets the login activity score to zero in risk assessment
    db.auth_activity.delete_many({
        "$or": [
            {"user_email": current_user["email"]},
            {"user_id": str(current_user["_id"])}
        ],
        "type": {"$in": ["failed_login", "blocked_device", "fingerprint_mismatch", "biometric_login_failed"]}
    })
    
    # Also reset the risk_score to 0 completely (fresh start after password change)
    db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {"risk_score": 0, "failed_login_attempts": 0}}
    )
    
    # Generate a NEW token for the current device so user stays logged in
    # This token is issued AFTER token_valid_after, so it remains valid
    # Must include BOTH 'sub' (email) and 'user_id' for validation to pass
    new_token = create_access_token(
        data={
            "sub": current_user["email"],
            "user_id": str(current_user["_id"])
        },
        expires_delta=timedelta(hours=24)
    )
    
    return {
        "message": "Password updated successfully. All other devices have been logged out.",
        "logout_all": True,
        "activity_cleared": True,
        "access_token": new_token,  # New token for current device
        "token_type": "bearer"
    }

@router.delete("/account")
async def delete_account(
    confirmation: PasswordConfirmation,
    current_user: dict = Depends(get_current_user)
):
    db = Database.get_db()
    
    # Verify password
    if not verify_password(confirmation.password, current_user["password_hash"]):
        raise HTTPException(status_code=400, detail="Incorrect password")
        
    user_id = current_user["_id"]
    
    # Cascade Delete
    # 1. Delete Files
    db.files.delete_many({"owner_id": user_id})
    # 2. Delete Items
    db.items.delete_many({"owner_id": user_id})
    # 3. Delete Logs (optional, but requested "IDS logs")
    # Assuming logs have user_id or we filter by source/device? 
    # Logs might be mixed. If logs have user_id, delete them.
    # Our EventLog schema has user_id.
    db.logs.delete_many({"user_id": user_id})
    
    # 4. Delete User
    db.users.delete_one({"_id": user_id})
    
    # 5. Disconnect WebSockets
    # We can't easily disconnect them here without async loop access or just let them fail later?
    # But we can try to notify or just rely on token invalidation.
    # Ideally: await manager.disconnect_user(user_id) if we had that method.
    # For now, just return success.
    
    return {"message": "Account deleted successfully"}

@router.post("/logout-all")
async def logout_all(request: Request, current_user: dict = Depends(get_current_user)):
    from .logs import create_auth_activity
    
    db = Database.get_db()
    device_name = request.headers.get("X-Device-Name", "Unknown Device")
    client_ip = request.client.host if request.client else "unknown"
    
    # Log logout from all devices
    create_auth_activity(
        title="Logged Out From All Devices",
        device_name=device_name,
        ip_address=client_ip,
        activity_type="logout",
        user_email=current_user["email"],
        user_name=current_user.get("name"),
        user_id=str(current_user["_id"])
    )
    
    # Clear trusted devices
    db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {"trusted_devices": []}}
    )
    
    return {"message": "Logged out from all devices"}

@router.post("/logout")
async def logout(request: Request):
    """
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                     INDUSTRY-STANDARD SAFE LOGOUT                            ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  WHY LOGOUT MUST BE NON-AUTHENTICATED (No Depends(get_current_user)):        ║
    ║                                                                              ║
    ║  1. Users with EXPIRED tokens still need to logout properly                  ║
    ║  2. Users with REVOKED tokens (password change) still need to logout         ║
    ║  3. Logout is a SECURITY operation - it should NEVER fail                    ║
    ║  4. Denying logout leaves stale sessions, device bindings, and security risk ║
    ║  5. Logout must be IDEMPOTENT - calling it multiple times should be safe     ║
    ║                                                                              ║
    ║  BEHAVIOR:                                                                   ║
    ║  - Accept valid token     → Clean up session, return 200                     ║
    ║  - Accept expired token   → Clean up session, return 200                     ║
    ║  - Accept invalid token   → Return 200 (nothing to clean up)                 ║
    ║  - Accept missing token   → Return 200 (already logged out)                  ║
    ║                                                                              ║
    ║  ACTIONS (if user identified):                                               ║
    ║  - Clear session token                                                       ║
    ║  - Remove device from trusted_devices                                        ║
    ║  - Mark is_logged_in = False                                                 ║
    ║  - Disconnect WebSocket                                                      ║
    ║  - Log audit event                                                           ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    """
    from .logs import create_auth_activity
    from datetime import datetime
    
    # Extract device info (always available)
    device_name = request.headers.get("X-Device-Name", "Unknown Device")
    device_fingerprint = request.headers.get("X-Device-Fingerprint")
    client_ip = request.client.host if request.client else "unknown"
    
    try:
        # 1. Extract Token (if present)
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            # No token = already logged out effectively
            print(f"[LOGOUT] No token provided from {device_name} ({client_ip})")
            return {"message": "Logged out successfully", "status": "no_token"}
        
        token = auth_header.split(" ")[1]
        
        # 2. Identify User using LOOSE token validation
        #    This accepts expired tokens - we just need to identify WHO is logging out
        user = get_user_from_token_loose(token)
        
        if not user:
            # Token is completely invalid/corrupted, but that's OK
            print(f"[LOGOUT] Invalid token from {device_name} ({client_ip}) - no action needed")
            return {"message": "Logged out successfully", "status": "invalid_token"}
        
        user_id = user["_id"]
        user_email = user.get("email", "unknown")
        
        # CRITICAL: Extract session_id from token for revocation
        from jose import jwt
        from app.core.config import settings
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM], options={"verify_exp": False})
            session_id = payload.get("session_id")
        except:
            session_id = None
        
        # 3. Clear Session & Device Binding + REVOKE SESSION
        db = Database.get_db()
        
        update_query = {
            "$set": {
                "is_logged_in": False,
                "last_logout": datetime.utcnow()
            },
            "$unset": {
                "active_device": "",
                "session_token": "",
                "mfa_login_otp": "",
                "mfa_login_otp_expires": "",
                "refresh_token": ""
            }
        }
        
        # ADD SESSION TO REVOKED LIST
        if session_id:
            update_query["$addToSet"] = {"revoked_sessions": session_id}
            print(f"[LOGOUT] Revoking session: {session_id[:20]}...")
        
        # Remove this specific device from trusted_devices
        if device_fingerprint:
            update_query["$pull"] = {
                "trusted_devices": {"fingerprint": device_fingerprint}
            }
        
        db.users.update_one({"_id": user_id}, update_query)
        
        # 4. Disconnect WebSocket
        try:
            await manager.disconnect_user(str(user_id))
        except Exception as ws_error:
            print(f"[LOGOUT] WebSocket disconnect warning: {ws_error}")
        
        # 5. Log Audit Event
        try:
            create_auth_activity(
                title="User Logged Out",
                device_name=device_name,
                ip_address=client_ip,
                activity_type="logout",
                user_email=user_email,
                user_name=user.get("name"),
                user_id=str(user_id)
            )
        except Exception as log_error:
            print(f"[LOGOUT] Audit log warning: {log_error}")
        
        print(f"[LOGOUT] ✓ {user_email} logged out from {device_name}")
        return {"message": "Logged out successfully", "status": "success"}
        
    except Exception as e:
        # CRITICAL: Even if something goes wrong, NEVER return an error
        # Just log it and return success
        print(f"[LOGOUT] Unexpected error (returning 200 anyway): {e}")
        return {"message": "Logged out successfully", "status": "error_handled"}

@router.post("/reset-device-binding")
async def reset_device_binding(
    request: Request,
    confirmation: PasswordConfirmation,
    current_user: dict = Depends(get_current_user)
):
    """
    Reset the device fingerprint binding for the current user.
    This allows the user to login from a new device.
    Requires password confirmation for security.
    """
    from .logs import create_auth_activity
    
    db = Database.get_db()
    
    # Verify password
    if not verify_password(confirmation.password, current_user["password_hash"]):
        raise HTTPException(status_code=400, detail="Incorrect password")
    
    device_name = request.headers.get("X-Device-Name", "Unknown Device")
    client_ip = request.client.host if request.client else "unknown"
    
    # Remove device fingerprint binding
    db.users.update_one(
        {"_id": current_user["_id"]},
        {
            "$unset": {"device_fingerprint": "", "fingerprint_bound_at": ""},
            "$set": {"trusted_devices": []}  # Also clear trusted devices
        }
    )
    
    # Log the action
    create_auth_activity(
        title="Device Binding Reset",
        device_name=device_name,
        ip_address=client_ip,
        activity_type="fingerprint_reset",
        user_email=current_user["email"],
        user_name=current_user.get("name"),
        user_id=str(current_user["_id"])
    )
    
    return {"message": "Device binding has been reset. You can now login from a new device."}


# ================= BIOMETRIC LOGIN =================

class BiometricLoginRequest(BaseModel):
    device_fingerprint: str
    device_name: str = "Unknown Device"
    device_type: str = "unknown"

class DeviceBindRequest(BaseModel):
    device_fingerprint: str
    device_name: str = "Unknown Device"
    device_type: str = "unknown"


@router.post("/biometric-login")
async def biometric_login(request: Request, body: BiometricLoginRequest):
    """
    Biometric login using device fingerprint only.
    
    Prerequisites:
    1. User must have registered and logged in at least once with email/password
    2. Device fingerprint must be bound to user's account
    3. Biometric verification must pass on the device before calling this endpoint
    
    Flow:
    1. Find user by device_fingerprint
    2. If found → Generate token and login
    3. If not found → Return error (device not registered)
    """
    from .logs import create_auth_activity
    
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    device_fingerprint = body.device_fingerprint
    device_name = body.device_name
    device_type = body.device_type
    client_ip = request.client.host if request.client else "unknown"
    
    # Find user with this device fingerprint
    user = db.users.find_one({"device_fingerprint": device_fingerprint})
    
    if not user:
        # Device not registered to any user
        create_auth_activity(
            title="Biometric Login Failed - Unknown Device",
            device_name=device_name,
            ip_address=client_ip,
            activity_type="biometric_login_failed",
            user_email="unknown"
        )
        raise HTTPException(
            status_code=401,
            detail="Device not registered. Please login with email and password first.",
            headers={"X-Error-Type": "device_not_registered"}
        )
    
    # Check if user account is blocked
    if user.get("is_blocked", False):
        raise HTTPException(
            status_code=403,
            detail="Your account has been blocked.",
            headers={"X-Error-Type": "account_blocked"}
        )
    
    # Update device info in trusted_devices
    trusted_devices = user.get("trusted_devices", [])
    device_found = False
    device_found_index = -1
    
    # Check by fingerprint OR device_id to avoid duplicates
    for index, device in enumerate(trusted_devices):
        if device.get("fingerprint") == device_fingerprint or device.get("device_id") == device_fingerprint[:16]:
            device["last_active"] = datetime.utcnow()
            device["last_login"] = datetime.utcnow().isoformat()
            device["ip_address"] = client_ip
            device["name"] = device_name  # Update name
            device["fingerprint"] = device_fingerprint  # Ensure fingerprint is set
            device_found = True
            device_found_index = index
            trusted_devices[index] = device
            break
    
    if not device_found:
        # Add this device to trusted devices
        trusted_devices.append({
            "device_id": device_fingerprint[:16],
            "fingerprint": device_fingerprint,
            "name": device_name,
            "type": device_type,
            "first_login": datetime.utcnow().isoformat(),
            "last_login": datetime.utcnow().isoformat(),
            "last_active": datetime.utcnow(),
            "ip_address": client_ip,
            "is_trusted": True,
            "is_blocked": False
        })
    
    # Update user
    db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {"trusted_devices": trusted_devices}}
    )
    
    # Log successful biometric login
    create_auth_activity(
        title="Biometric Login Successful",
        device_name=device_name,
        ip_address=client_ip,
        activity_type="biometric_login",
        user_email=user["email"],
        user_name=user.get("name"),
        user_id=str(user["_id"])
    )
    
    # Generate access token with session_id for MFA login
    # Extract session_id from temp_mfa_data or generate new one
    import secrets
    mfa_session_id = user.get("temp_mfa_session_id") or secrets.token_urlsafe(32)
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={
            "sub": user["email"], 
            "user_id": user["_id"],
            "session_id": mfa_session_id  # Include session for MFA
        },
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user["_id"],
        "user_email": user["email"],
        "user_name": user.get("name"),
        "message": "Biometric login successful"
    }


@router.post("/bind-device")
async def bind_device(
    request: Request,
    body: DeviceBindRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Bind device fingerprint to current authenticated user.
    Call this after successful email/password login to enable biometric login.
    
    Flow:
    1. Check if fingerprint is already bound to another user → block
    2. Bind fingerprint to current user
    """
    from .logs import create_auth_activity
    
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    device_fingerprint = body.device_fingerprint
    device_name = body.device_name
    device_type = body.device_type
    client_ip = request.client.host if request.client else "unknown"
    
    # Check if this fingerprint is already bound to another user
    existing_user = db.users.find_one({
        "device_fingerprint": device_fingerprint,
        "_id": {"$ne": current_user["_id"]}
    })
    
    if existing_user:
        create_auth_activity(
            title="Device Binding Failed - Already Linked",
            device_name=device_name,
            ip_address=client_ip,
            activity_type="device_bind_failed",
            user_email=current_user["email"],
            user_name=current_user.get("name"),
            user_id=str(current_user["_id"])
        )
        raise HTTPException(
            status_code=403,
            detail="This device is already linked to another account.",
            headers={"X-Error-Type": "device_conflict"}
        )
    
    # Bind fingerprint to current user
    db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {
            "device_fingerprint": device_fingerprint,
            "fingerprint_bound_at": datetime.utcnow()
        }}
    )
    
    # Log the binding
    create_auth_activity(
        title="Device Bound for Biometric Login",
        device_name=device_name,
        ip_address=client_ip,
        activity_type="device_bound",
        user_email=current_user["email"],
        user_name=current_user.get("name"),
        user_id=str(current_user["_id"])
    )
    
    return {
        "message": "Device bound successfully. You can now use biometric login.",
        "device_fingerprint": device_fingerprint
    }


@router.get("/check-device/{device_fingerprint}")
async def check_device_binding(device_fingerprint: str):
    """
    Check if a device fingerprint is already bound to a user.
    Returns user info if bound, or indicates device is available.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    user = db.users.find_one({"device_fingerprint": device_fingerprint})
    
    if user:
        return {
            "is_bound": True,
            "user_email": user["email"],
            "user_name": user.get("name"),
            "bound_at": user.get("fingerprint_bound_at")
        }
    
    return {
        "is_bound": False,
        "message": "Device is not bound to any account"
    }


# ================= MFA (EMAIL-BASED OTP) =================
from app.core.email_utils import generate_otp, send_otp_email

@router.post("/mfa/enable")
async def enable_mfa(current_user: dict = Depends(get_current_user)):
    """
    Enable MFA for the current user.
    Sends a verification OTP to the user's email.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    # Check if MFA is already enabled
    if current_user.get("mfa_enabled"):
        raise HTTPException(status_code=400, detail="MFA is already enabled")
    
    # Generate OTP
    otp_code = generate_otp(settings.MFA_OTP_LENGTH)
    otp_expires = datetime.utcnow() + timedelta(minutes=settings.MFA_OTP_EXPIRE_MINUTES)
    
    # Store OTP temporarily
    db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {
            "mfa_otp_pending": otp_code,
            "mfa_otp_expires": otp_expires.isoformat(),
            "mfa_setup_pending": True
        }}
    )
    
    # Send OTP via email
    email = current_user["email"]
    if not send_otp_email(email, otp_code, purpose="enable_mfa"):
        raise HTTPException(status_code=500, detail="Failed to send verification email.")
    
    return {
        "message": f"Verification code sent to {email}",
        "email": email,
        "expires_in_minutes": settings.MFA_OTP_EXPIRE_MINUTES,
        "next_step": "Use /auth/mfa/verify to complete setup",
        "debug_otp": otp_code
    }


@router.post("/mfa/verify")
async def verify_mfa(
    code: str,
    current_user: dict = Depends(get_current_user)
):
    """
    Verify MFA OTP code and enable MFA if valid.
    This endpoint is used for completing MFA setup.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    # Check for pending setup
    if not current_user.get("mfa_setup_pending"):
        raise HTTPException(
            status_code=400, 
            detail="No pending MFA setup. Please enable MFA first."
        )
    
    # Get stored OTP
    stored_otp = current_user.get("mfa_otp_pending")
    otp_expires_str = current_user.get("mfa_otp_expires")
    
    if not stored_otp or not otp_expires_str:
        raise HTTPException(
            status_code=400, 
            detail="No OTP found. Please request a new code."
        )
    
    # Check expiry
    otp_expires = datetime.fromisoformat(otp_expires_str)
    if datetime.utcnow() > otp_expires:
        # Clear expired OTP
        db.users.update_one(
            {"_id": current_user["_id"]},
            {"$unset": {"mfa_otp_pending": "", "mfa_otp_expires": "", "mfa_setup_pending": ""}}
        )
        raise HTTPException(status_code=401, detail="OTP has expired. Please request a new code.")
    
    # Verify the code
    if code != stored_otp:
        raise HTTPException(status_code=401, detail="Invalid verification code")
    
    # Enable MFA & Reduce Risk
    current_risk = current_user.get("risk_score", 0)
    new_risk = max(0, current_risk - 50)
    
    db.users.update_one(
        {"_id": current_user["_id"]},
        {
            "$set": {
                "mfa_enabled": True,
                "mfa_enabled_at": datetime.utcnow().isoformat(),
                "risk_score": new_risk
            },
            "$unset": {"mfa_otp_pending": "", "mfa_otp_expires": "", "mfa_setup_pending": ""}
        }
    )
    
    return {"message": "MFA enabled successfully", "mfa_enabled": True}


class MFADisableRequest(BaseModel):
    password: str
    code: str

@router.post("/mfa/disable")
async def disable_mfa(
    body: MFADisableRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Disable MFA for the current user.
    Requires password and OTP verification.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    # Check if MFA is enabled
    if not current_user.get("mfa_enabled"):
        raise HTTPException(status_code=400, detail="MFA is not enabled")
    
    # Verify password
    # Verify password
    if not verify_password(body.password, current_user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid password")
    
    # Get stored OTP for disable verification
    stored_otp = current_user.get("mfa_disable_otp")
    otp_expires_str = current_user.get("mfa_disable_otp_expires")
    
    if not stored_otp or not otp_expires_str:
        raise HTTPException(
            status_code=400, 
            detail="No OTP found. Please request a disable OTP first."
        )
    
    # Check expiry
    otp_expires = datetime.fromisoformat(otp_expires_str)
    if datetime.utcnow() > otp_expires:
        db.users.update_one(
            {"_id": current_user["_id"]},
            {"$unset": {"mfa_disable_otp": "", "mfa_disable_otp_expires": ""}}
        )
        raise HTTPException(status_code=401, detail="OTP has expired")
    
    # Verify the code
    if body.code != stored_otp:
        raise HTTPException(status_code=401, detail="Invalid verification code")
    
    # Disable MFA
    db.users.update_one(
        {"_id": current_user["_id"]},
        {
            "$set": {"mfa_enabled": False},
            "$unset": {"mfa_enabled_at": "", "mfa_disable_otp": "", "mfa_disable_otp_expires": ""}
        }
    )
    
    return {"message": "MFA disabled successfully", "mfa_enabled": False}


@router.post("/mfa/request-disable-otp")
async def request_disable_otp(current_user: dict = Depends(get_current_user)):
    """
    Request an OTP to disable MFA.
    Sends verification code to user's email.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    if not current_user.get("mfa_enabled"):
        raise HTTPException(status_code=400, detail="MFA is not enabled")
    
    # Generate OTP
    otp_code = generate_otp(settings.MFA_OTP_LENGTH)
    otp_expires = datetime.utcnow() + timedelta(minutes=settings.MFA_OTP_EXPIRE_MINUTES)
    
    # Store OTP
    db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {
            "mfa_disable_otp": otp_code,
            "mfa_disable_otp_expires": otp_expires.isoformat()
        }}
    )
    
    # Send OTP via email
    email = current_user["email"]
    if not send_otp_email(email, otp_code, purpose="disable_mfa"):
        raise HTTPException(status_code=500, detail="Failed to send verification email.")
    
    return {
        "message": f"Verification code sent to {email}",
        "expires_in_minutes": settings.MFA_OTP_EXPIRE_MINUTES,
        "debug_otp": otp_code
    }


@router.get("/mfa/status")
async def get_mfa_status(current_user: dict = Depends(get_current_user)):
    """
    Get the current MFA status for the user.
    """
    return {
        "mfa_enabled": current_user.get("mfa_enabled", False),
        "mfa_enabled_at": current_user.get("mfa_enabled_at"),
        "has_pending_setup": current_user.get("mfa_setup_pending", False)
    }


@router.post("/mfa/send-login-otp")
async def send_login_otp(email: str):
    """
    Send login OTP to user's email.
    Called when user attempts to login and MFA is enabled.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    user = db.users.find_one({"email": email})
    if not user:
        # Don't reveal if user exists
        return {"message": "If the account exists, a code has been sent"}
    
    if not user.get("mfa_enabled"):
        raise HTTPException(status_code=400, detail="MFA is not enabled for this account")
    
    # Generate OTP
    otp_code = generate_otp(settings.MFA_OTP_LENGTH)
    otp_expires = datetime.utcnow() + timedelta(minutes=settings.MFA_OTP_EXPIRE_MINUTES)
    
    # Store OTP
    db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {
            "mfa_login_otp": otp_code,
            "mfa_login_otp_expires": otp_expires.isoformat()
        }}
    )
    
    # Send OTP via email
    if not send_otp_email(email, otp_code, purpose="login"):
        raise HTTPException(status_code=500, detail="Failed to send verification email.")
    
    return {
        "message": f"Verification code sent to {email}",
        "expires_in_minutes": settings.MFA_OTP_EXPIRE_MINUTES,
        "debug_otp": otp_code
    }


@router.post("/mfa/login-verify")
async def verify_mfa_login(
    email: str,
    code: str
):
    """
    Verify MFA code during login flow.
    Called after password verification if MFA is enabled.
    Returns the access token if verification succeeds.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    user = db.users.find_one({"email": email})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if not user.get("mfa_enabled"):
        raise HTTPException(status_code=400, detail="MFA is not enabled for this account")
    
    # Get stored OTP
    stored_otp = user.get("mfa_login_otp")
    otp_expires_str = user.get("mfa_login_otp_expires")
    
    if not stored_otp or not otp_expires_str:
        raise HTTPException(
            status_code=400, 
            detail="No OTP found. Please request a new code."
        )
    
    # Check expiry
    otp_expires = datetime.fromisoformat(otp_expires_str)
    if datetime.utcnow() > otp_expires:
        # Clear expired OTP
        db.users.update_one(
            {"_id": user["_id"]},
            {"$unset": {"mfa_login_otp": "", "mfa_login_otp_expires": ""}}
        )
        raise HTTPException(
            status_code=401, 
            detail="OTP has expired. Please request a new code."
        )
    
    # Verify the code
    if code != stored_otp:
        raise HTTPException(
            status_code=401, 
            detail="Invalid verification code",
            headers={"X-Error-Type": "mfa_invalid"}
        )
    
    # Clear used OTP
    db.users.update_one(
        {"_id": user["_id"]},
        {"$unset": {"mfa_login_otp": "", "mfa_login_otp_expires": ""}}
    )
    
    # Generate access token
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user["email"], "user_id": user["_id"]},
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "message": "MFA verified, login successful"
    }


@router.post("/mfa/resend-otp")
async def resend_otp(email: str, purpose: str = "login"):
    """
    Resend OTP for various purposes (login, enable, disable).
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    user = db.users.find_one({"email": email})
    if not user:
        return {"message": "If the account exists, a code has been sent"}
    
    # Generate new OTP
    otp_code = generate_otp(settings.MFA_OTP_LENGTH)
    otp_expires = datetime.utcnow() + timedelta(minutes=settings.MFA_OTP_EXPIRE_MINUTES)
    
    # Store based on purpose
    if purpose == "login":
        if not user.get("mfa_enabled"):
            raise HTTPException(status_code=400, detail="MFA is not enabled")
        db.users.update_one(
            {"_id": user["_id"]},
            {"$set": {
                "mfa_login_otp": otp_code,
                "mfa_login_otp_expires": otp_expires.isoformat()
            }}
        )
    elif purpose == "enable":
        db.users.update_one(
            {"_id": user["_id"]},
            {"$set": {
                "mfa_otp_pending": otp_code,
                "mfa_otp_expires": otp_expires.isoformat()
            }}
        )
    elif purpose == "disable":
        if not user.get("mfa_enabled"):
            raise HTTPException(status_code=400, detail="MFA is not enabled")
        db.users.update_one(
            {"_id": user["_id"]},
            {"$set": {
                "mfa_disable_otp": otp_code,
                "mfa_disable_otp_expires": otp_expires.isoformat()
            }}
        )
    
    # Send OTP via email
    email_purpose = purpose
    if purpose == "enable":
        email_purpose = "enable_mfa"
    elif purpose == "disable":
        email_purpose = "disable_mfa"
        
    print(f"DEBUG: Resending OTP to {email} for purpose {email_purpose}")
    if not send_otp_email(email, otp_code, purpose=email_purpose):
        raise HTTPException(status_code=500, detail="Failed to send verification email.")
    
    return {
        "message": f"Verification code sent to {email}",
        "expires_in_minutes": settings.MFA_OTP_EXPIRE_MINUTES,
        "debug_otp": otp_code
    }


# ===================== FORGOT PASSWORD =====================

@router.post("/forgot-password/request")
async def request_password_reset(email: str):
    """
    Request password reset - sends OTP to user's email.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    # Find user by email
    user = db.users.find_one({"email": email})
    if not user:
        # Don't reveal if email exists - return success anyway for security
        return {
            "message": "If this email is registered, you will receive a reset code",
            "expires_in_minutes": settings.MFA_OTP_EXPIRE_MINUTES
        }
    
    # Generate OTP
    otp_code = generate_otp(settings.MFA_OTP_LENGTH)
    otp_expires = datetime.utcnow() + timedelta(minutes=settings.MFA_OTP_EXPIRE_MINUTES)
    
    # Store OTP in user document
    db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {
            "password_reset_otp": otp_code,
            "password_reset_otp_expires": otp_expires.isoformat()
        }}
    )
    
    # Send OTP via email
    if not send_otp_email(email, otp_code, purpose="password_reset"):
        raise HTTPException(status_code=500, detail="Failed to send reset email")
    
    return {
        "message": "Reset code sent to your email",
        "expires_in_minutes": settings.MFA_OTP_EXPIRE_MINUTES
    }


@router.post("/forgot-password/verify")
async def verify_password_reset_otp(email: str, code: str):
    """
    Verify OTP and return a reset token.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    user = db.users.find_one({"email": email})
    if not user:
        raise HTTPException(status_code=400, detail="Invalid email or code")
    
    stored_otp = user.get("password_reset_otp")
    otp_expires_str = user.get("password_reset_otp_expires")
    
    if not stored_otp or not otp_expires_str:
        raise HTTPException(status_code=400, detail="No reset request found. Please request a new code.")
    
    # Check if expired
    otp_expires = datetime.fromisoformat(otp_expires_str)
    if datetime.utcnow() > otp_expires:
        # Clear expired OTP
        db.users.update_one(
            {"_id": user["_id"]},
            {"$unset": {"password_reset_otp": "", "password_reset_otp_expires": ""}}
        )
        raise HTTPException(status_code=400, detail="Code expired. Please request a new one.")
    
    # Verify code
    if code != stored_otp:
        raise HTTPException(status_code=400, detail="Invalid code")
    
    # Generate reset token (temporary, single-use)
    reset_token = str(uuid.uuid4())
    reset_token_expires = datetime.utcnow() + timedelta(minutes=10)  # 10 minutes to set new password
    
    # Store reset token and clear OTP
    db.users.update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "password_reset_token": reset_token,
                "password_reset_token_expires": reset_token_expires.isoformat()
            },
            "$unset": {
                "password_reset_otp": "",
                "password_reset_otp_expires": ""
            }
        }
    )
    
    return {
        "message": "Code verified successfully",
        "reset_token": reset_token
    }


@router.post("/forgot-password/reset")
async def reset_password_with_token(reset_token: str, new_password: str):
    """
    Reset password using the reset token.
    """
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    # Find user by reset token
    user = db.users.find_one({"password_reset_token": reset_token})
    if not user:
        raise HTTPException(status_code=400, detail="Invalid or expired reset link")
    
    # Check if token expired
    token_expires_str = user.get("password_reset_token_expires")
    if token_expires_str:
        token_expires = datetime.fromisoformat(token_expires_str)
        if datetime.utcnow() > token_expires:
            db.users.update_one(
                {"_id": user["_id"]},
                {"$unset": {"password_reset_token": "", "password_reset_token_expires": ""}}
            )
            raise HTTPException(status_code=400, detail="Reset link expired. Please request a new one.")
    
    # Validate password strength
    try:
        validate_strong_password(new_password)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    # Hash new password
    new_hash = get_password_hash(new_password)
    
    # Update password and invalidate all sessions
    token_cutoff = datetime.utcnow() - timedelta(seconds=1)
    
    db.users.update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "password_hash": new_hash,
                "token_valid_after": token_cutoff,
                "risk_score": 0,
                "failed_login_attempts": 0
            },
            "$unset": {
                "password_reset_token": "",
                "password_reset_token_expires": "",
                "device_fingerprint": "",
                "fingerprint_bound_at": ""
            }
        }
    )
    
    # Clear trusted devices
    db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {"trusted_devices": []}}
    )
    
    return {
        "message": "Password reset successfully. Please login with your new password."
    }


# ==================== LOGOUT ====================
@router.post("/logout")
async def logout(
    request: Request,
    current_user: dict = Depends(get_current_user)
):
    """
    Logout the current user: unbind device, clear session, allow other devices to login.
    """
    print(f"[LOGOUT] User {current_user.get('email')} is logging out...")
    
    db = Database.get_db()
    
    # Get device info from header
    device_name = request.headers.get("X-Device-Name", "Unknown Device")
    client_ip = request.client.host if request.client else "Unknown"
    
    # Clear device binding and session
    db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {
            "bound_device_id": None,
            "is_logged_in": False,
            "session_token": None
        }}
    )
    
    print(f"[LOGOUT] Device unbound for {current_user.get('email')}")
    
    # Log the logout activity
    create_auth_activity(
        title="User Logged Out - Device Unbound",
        device_name=device_name,
        ip_address=client_ip,
        activity_type="logout",
        user_email=current_user.get("email"),
        user_name=current_user.get("name"),
        user_id=str(current_user["_id"])
    )
    
    return {"message": "Logged out successfully. Device unbound."}


# ==================== BLOCK DEVICE ====================
class BlockDeviceRequest(BaseModel):
    device_fingerprint: str

@router.post("/devices/block")
async def block_device(
    request: BlockDeviceRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Block a device from accessing the account.
    If the device is currently logged in, force logout via WebSocket.
    """
    from app.websocket_manager import manager
    from .logs import create_auth_activity
    
    db = Database.get_db()
    fingerprint = request.device_fingerprint
    
    # Add to blocked_devices list
    db.users.update_one(
        {"_id": current_user["_id"]},
        {"$addToSet": {"blocked_devices": fingerprint}}
    )
    
    # Check if this is the currently bound device
    if current_user.get("bound_device_id") == fingerprint:
        # Clear the binding and session
        db.users.update_one(
            {"_id": current_user["_id"]},
            {"$set": {
                "bound_device_id": None,
                "is_logged_in": False,
                "session_token": None
            }}
        )
        
        # Send force logout WebSocket event
        await manager.force_logout_device(
            user_id=str(current_user["_id"]),
            event_type="device_blocked",
            reason="Your device has been blocked from this account."
        )
    
    create_auth_activity(
        title="Device Blocked",
        device_name="Blocked Device",
        ip_address="N/A",
        activity_type="device_blocked",
        user_email=current_user.get("email"),
        user_name=current_user.get("name"),
        user_id=str(current_user["_id"])
    )
    
    return {"message": "Device blocked successfully."}


# ==================== FORCE LOGOUT (from another device) ====================
@router.post("/devices/force-logout")
async def force_logout_device(
    current_user: dict = Depends(get_current_user)
):
    """
    Force logout the currently bound device (called from a new device that wants to take over).
    Clears the session and sends WebSocket event.
    """
    from app.websocket_manager import manager
    from .logs import create_auth_activity
    
    db = Database.get_db()
    
    # Check if there's a bound device
    if not current_user.get("is_logged_in") or not current_user.get("bound_device_id"):
        return {"message": "No active device to logout."}
    
    # Send force logout event
    await manager.force_logout_device(
        user_id=str(current_user["_id"]),
        event_type="force_logout",
        reason="You have been logged out from another device."
    )
    
    # Clear the binding
    db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {
            "bound_device_id": None,
            "is_logged_in": False,
            "session_token": None
        }}
    )
    
    create_auth_activity(
        title="Force Logout from Another Device",
        device_name="Remote",
        ip_address="N/A",
        activity_type="force_logout",
        user_email=current_user.get("email"),
        user_name=current_user.get("name"),
        user_id=str(current_user["_id"])
    )
    
    return {"message": "Device logged out successfully."}
