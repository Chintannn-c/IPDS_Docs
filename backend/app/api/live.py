from fastapi import APIRouter, Depends, Query, HTTPException
from typing import List, Optional
from app.db.database import db
from app.models.schemas import ActivityLog, FileTracking

router = APIRouter()

from app.services.auth_service import get_current_user

@router.get("/activity-logs", response_model=List[ActivityLog])
async def get_activity_logs(
    limit: int = 50,
    action: Optional[str] = None,
    status: Optional[str] = None,
    target_type: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """
    Fetch historical activity logs for the current user.
    """
    if db.db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
    
    uid = current_user["_id"]
    # Query logs where user is the ACTOR (did something) OR the TARGET (something happened to them)
    query = {
        "$or": [
            {"actor.user_id": uid},             # Actor (ObjectId)
            {"actor.user_id": str(uid)},        # Actor (String)
            {"target.id": str(uid)},            # Target (String)
            {"target.id": uid}                  # Target (ObjectId - rare but possible)
        ]
    }

    if action:
        query["action"] = action
    if status:
        query["status"] = status
    if target_type:
        query["target.type"] = target_type
        
    cursor = db.db.activity_logs.find(query).sort("timestamp", -1).limit(limit)
    
    # Ensure timestamps are timezone-aware (UTC) before sending
    results = []
    from datetime import timezone
    for doc in cursor:
        if "timestamp" in doc and doc["timestamp"]:
            # Assume Mongo stored them as naive UTC
            doc["timestamp"] = doc["timestamp"].replace(tzinfo=timezone.utc)
        results.append(ActivityLog(**doc))
        
    return results

@router.get("/file-tracking/{file_id}", response_model=FileTracking)
async def get_file_tracking(file_id: str):
    """
    Get the current lifecycle tracking status of a file.
    """
    if db.db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
        
    doc = db.db.file_tracking.find_one({"file_id": file_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Tracking info not found")
        
    return FileTracking(**doc)
