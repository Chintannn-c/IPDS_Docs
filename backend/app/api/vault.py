from fastapi import APIRouter, HTTPException, Depends, Request
from app.services.auth_service import get_current_user, get_password_hash, verify_password
from app.db.database import Database
from datetime import datetime, timedelta
from pydantic import BaseModel
from typing import Optional
import time

router = APIRouter()

class VaultPasswordSet(BaseModel):
    password: str

class VaultPasswordVerify(BaseModel):
    password: str

@router.get("/status")
async def get_vault_status(current_user: dict = Depends(get_current_user)):
    """Check if vault password is set."""
    return {
        "is_set": "vault_password_hash" in current_user and current_user["vault_password_hash"] is not None,
        "is_locked": current_user.get("vault_lockout_until") is not None and 
                    datetime.fromisoformat(current_user["vault_lockout_until"]) > datetime.utcnow()
    }

@router.post("/set-password")
async def set_vault_password(data: VaultPasswordSet, current_user: dict = Depends(get_current_user)):
    """Set or change the vault password."""
    db = Database.get_db()
    hashed_password = get_password_hash(data.password)
    
    db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {
            "vault_password_hash": hashed_password,
            "vault_failed_attempts": 0,
            "vault_lockout_until": None
        }}
    )
    return {"message": "Vault password set successfully"}

@router.post("/verify")
async def verify_vault_password(data: VaultPasswordVerify, current_user: dict = Depends(get_current_user)):
    """Verify vault password with retry limit and lockout."""
    db = Database.get_db()
    
    # Check lockout
    lockout_until = current_user.get("vault_lockout_until")
    if lockout_until:
        lockout_dt = datetime.fromisoformat(lockout_until)
        if lockout_dt > datetime.utcnow():
            remaining = int((lockout_dt - datetime.utcnow()).total_seconds())
            raise HTTPException(
                status_code=423, 
                detail=f"Vault is locked. Try again in {remaining} seconds."
            )

    password_hash = current_user.get("vault_password_hash")
    if not password_hash:
        raise HTTPException(status_code=400, detail="Vault password not set")

    if verify_password(data.password, password_hash):
        # Success: Reset failed attempts and set verification timestamp
        now = datetime.utcnow()
        db.users.update_one(
            {"_id": current_user["_id"]},
            {"$set": {
                "vault_failed_attempts": 0, 
                "vault_lockout_until": None,
                "active_device.vault_verified_at": now.isoformat()
            }}
        )
        return {"message": "Vault verified", "verified": True}
    else:
        # Failure: Increment attempts
        failed_attempts = current_user.get("vault_failed_attempts", 0) + 1
        update_data = {"vault_failed_attempts": failed_attempts}
        
        if failed_attempts >= 3:
            # Lockout for 5 minutes
            lockout_time = datetime.utcnow() + timedelta(minutes=5)
            update_data["vault_lockout_until"] = lockout_time.isoformat()
            
            db.users.update_one({"_id": current_user["_id"]}, {"$set": update_data})
            raise HTTPException(
                status_code=423, 
                detail="Too many failed attempts. Vault locked for 5 minutes."
            )
        
        db.users.update_one({"_id": current_user["_id"]}, {"$set": update_data})
        raise HTTPException(
            status_code=401, 
            detail=f"Incorrect vault password. {3 - failed_attempts} attempts remaining."
        )
