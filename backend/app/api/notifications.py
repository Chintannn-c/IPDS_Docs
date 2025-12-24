from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional
from datetime import datetime, timedelta
from app.models.notification_models import (
    NotificationCreate,
    NotificationUpdate,
    NotificationResponse,
    NotificationPreferences,
    NotificationListResponse,
    NotificationCategory,
    NotificationPriority,
)
from app.services.auth_service import get_current_user
from app.db.database import Database
from bson import ObjectId
import pymongo

router = APIRouter()


def get_db():
    """Get database instance"""
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=503, detail="Database connection unavailable")
    return db


def notification_to_response(notification: dict) -> NotificationResponse:
    """Convert MongoDB document to NotificationResponse"""
    return NotificationResponse(
        id=str(notification["_id"]),
        user_id=notification["user_id"],
        title=notification["title"],
        message=notification["message"],
        category=notification["category"],
        priority=notification["priority"],
        is_read=notification.get("is_read", False),
        data=notification.get("data"),
        created_at=notification["created_at"],
    )


@router.get("/notifications", response_model=NotificationListResponse)
async def get_notifications(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    category: Optional[NotificationCategory] = None,
    is_read: Optional[bool] = None,
    priority: Optional[NotificationPriority] = None,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """
    Get paginated list of notifications for the current user.
    
    - **page**: Page number (1-indexed)
    - **page_size**: Items per page (max 100)
    - **category**: Filter by category (optional)
    - **is_read**: Filter by read status (optional)
    - **priority**: Filter by priority (optional)
    """
    collection = db.notifications
    user_id = current_user["_id"]
    
    # Build query filter
    query = {"user_id": user_id}
    if category:
        query["category"] = category.value
    if is_read is not None:
        query["is_read"] = is_read
    if priority:
        query["priority"] = priority.value
    
    # Get total count
    total = collection.count_documents(query)
    
    # Get paginated results
    skip = (page - 1) * page_size
    cursor = collection.find(query).sort("created_at", pymongo.DESCENDING).skip(skip).limit(page_size)
    
    notifications = [notification_to_response(doc) for doc in cursor]
    
    has_more = (skip + len(notifications)) < total
    
    return NotificationListResponse(
        notifications=notifications,
        total=total,
        page=page,
        page_size=page_size,
        has_more=has_more,
    )


@router.get("/notifications/unread-count")
async def get_unread_count(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """Get count of unread notifications for current user"""
    collection = db.notifications
    user_id = current_user["_id"]
    
    count = collection.count_documents({"user_id": user_id, "is_read": False})
    
    return {"count": count}


@router.get("/notifications/{notification_id}", response_model=NotificationResponse)
async def get_notification(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """Get a specific notification by ID"""
    collection = db.notifications
    user_id = current_user["_id"]
    
    try:
        notification = collection.find_one({
            "_id": ObjectId(notification_id),
            "user_id": user_id
        })
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid notification ID")
    
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    return notification_to_response(notification)


@router.put("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """Mark a notification as read"""
    collection = db.notifications
    user_id = current_user["_id"]
    
    try:
        result = collection.update_one(
            {"_id": ObjectId(notification_id), "user_id": user_id},
            {"$set": {"is_read": True}}
        )
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid notification ID")
    
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    return {"message": "Notification marked as read"}


@router.put("/notifications/read-all")
async def mark_all_read(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """Mark all notifications as read for current user"""
    collection = db.notifications
    user_id = current_user["_id"]
    
    result = collection.update_many(
        {"user_id": user_id, "is_read": False},
        {"$set": {"is_read": True}}
    )
    
    return {"message": f"Marked {result.modified_count} notifications as read"}


@router.delete("/notifications/all")
async def delete_all_notifications(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """Delete all notifications for current user"""
    collection = db.notifications
    user_id = current_user["_id"]
    
    print(f"DEBUG: delete_all - user_id raw: {user_id}, type: {type(user_id)}")
    
    # Try deleting with raw ID first
    result = collection.delete_many({"user_id": user_id})
    print(f"DEBUG: delete_all (raw) - deleted: {result.deleted_count}")

    # If nothing deleted, try deleting with string ID
    if result.deleted_count == 0:
        print(f"DEBUG: delete_all - 0 deleted with raw ID, trying string ID...")
        user_id_str = str(user_id)
        result_str = collection.delete_many({"user_id": user_id_str})
        print(f"DEBUG: delete_all (string) - deleted: {result_str.deleted_count}")
        if result_str.deleted_count > 0:
            return {"message": f"Deleted {result_str.deleted_count} notifications (string match)"}

    return {"message": f"Deleted {result.deleted_count} notifications"}


@router.delete("/notifications/{notification_id}")
async def delete_notification(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """Delete a specific notification"""
    collection = db.notifications
    user_id = current_user["_id"]
    
    print(f"DEBUG: delete_one - user_id raw: {user_id}, type: {type(user_id)}")
    
    try:
        # Try deleting with raw ID
        result = collection.delete_one({
            "_id": ObjectId(notification_id),
            "user_id": user_id
        })
        
        # If not found, try with string ID
        if result.deleted_count == 0:
             print(f"DEBUG: delete_one - 0 deleted with raw ID, trying string ID...")
             user_id_str = str(user_id)
             result = collection.delete_one({
                "_id": ObjectId(notification_id),
                "user_id": user_id_str
            })
        
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Notification not found")
            
    except Exception as e:
        print(f"Error deleting notification: {e}")
        # Only raise 400 if it's an ID error
        if "ObjectId" in str(e):
             raise HTTPException(status_code=400, detail="Invalid notification ID")
        raise e
    
    return {"message": "Notification deleted"}


@router.post("/notifications", response_model=NotificationResponse)
async def create_notification(
    notification: NotificationCreate,
    db=Depends(get_db),
):
    """
    Create a new notification (internal use or system-generated).
    Note: This endpoint should be protected or used only internally.
    """
    collection = db.notifications
    
    notification_doc = {
        "user_id": notification.user_id,
        "title": notification.title,
        "message": notification.message,
        "category": notification.category.value,
        "priority": notification.priority.value,
        "is_read": False,
        "data": notification.data or {},
        "created_at": datetime.utcnow(),
    }
    
    result = collection.insert_one(notification_doc)
    notification_doc["_id"] = result.inserted_id
    
    return notification_to_response(notification_doc)


@router.get("/notifications/preferences", response_model=NotificationPreferences)
async def get_notification_preferences(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """Get notification preferences for current user"""
    collection = db.notification_preferences
    user_id = current_user["_id"]
    
    prefs = collection.find_one({"user_id": user_id})
    
    if not prefs:
        # Return default preferences
        return NotificationPreferences(user_id=user_id)
    
    return NotificationPreferences(
        user_id=prefs["user_id"],
        enabled_categories=prefs.get("enabled_categories", [c.value for c in NotificationCategory]),
        min_priority=prefs.get("min_priority", NotificationPriority.LOW.value),
        sound_enabled=prefs.get("sound_enabled", True),
        auto_delete_days=prefs.get("auto_delete_days", 30),
    )


@router.put("/notifications/preferences")
async def update_notification_preferences(
    preferences: NotificationPreferences,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """Update notification preferences for current user"""
    collection = db.notification_preferences
    user_id = current_user["_id"]
    
    prefs_doc = {
        "user_id": user_id,
        "enabled_categories": preferences.enabled_categories,
        "min_priority": preferences.min_priority,
        "sound_enabled": preferences.sound_enabled,
        "auto_delete_days": preferences.auto_delete_days,
    }
    
    collection.update_one(
        {"user_id": user_id},
        {"$set": prefs_doc},
        upsert=True
    )
    
    return {"message": "Preferences updated successfully"}


# Helper function to create notifications (can be used by other modules)
async def create_notification_for_user(
    db,
    user_id: str,
    title: str,
    message: str,
    category: NotificationCategory = NotificationCategory.INFO,
    priority: NotificationPriority = NotificationPriority.MEDIUM,
    data: Optional[dict] = None,
) -> dict:
    """
    Helper function to create a notification.
    Returns the created notification document.
    """
    collection = db.notifications
    
    notification_doc = {
        "user_id": user_id,
        "title": title,
        "message": message,
        "category": category.value if isinstance(category, NotificationCategory) else category,
        "priority": priority.value if isinstance(priority, NotificationPriority) else priority,
        "is_read": False,
        "data": data or {},
        "created_at": datetime.utcnow(),
    }
    
    result = collection.insert_one(notification_doc)
    notification_doc["_id"] = result.inserted_id
    
    return notification_doc
