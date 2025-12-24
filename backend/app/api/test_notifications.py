from fastapi import APIRouter, Depends
from app.services.auth_service import get_current_user
from app.websocket_manager import manager
from app.models.notification_models import NotificationCategory, NotificationPriority

router = APIRouter()


@router.post("/test-notification")
async def test_notification(current_user: dict = Depends(get_current_user)):
    """
    Test endpoint to manually trigger a notification.
    Use this to verify that notifications are working end-to-end.
    """
    user_id = str(current_user["_id"])
    
    # Send a test notification via WebSocket
    await manager.create_and_broadcast_notification(
        user_id=user_id,
        title="🔔 Test Notification",
        message="This is a test notification to verify your push notification system is working!",
        category=NotificationCategory.INFO.value,
        priority=NotificationPriority.HIGH.value,
        data={"test": True},
        notification_type="notification"
    )
    
    return {
        "message": "Test notification sent!",
        "user_id": user_id,
        "status": "Check your phone for the notification"
    }


@router.post("/test-security-alert")
async def test_security_alert(current_user: dict = Depends(get_current_user)):
    """
    Test endpoint to simulate a security alert notification.
    """
    user_id = str(current_user["_id"])
    
    await manager.create_and_broadcast_notification(
        user_id=user_id,
        title="🚨 Security Alert",
        message="Suspicious login attempt detected from unknown device!",
        category=NotificationCategory.SECURITY.value,
        priority=NotificationPriority.URGENT.value,
        data={"device": "Unknown Device", "location": "Unknown"},
        notification_type="notification"
    )
    
    return {
        "message": "Security alert sent!",
        "user_id": user_id
    }


@router.post("/test-file-upload")
async def test_file_upload_notification(current_user: dict = Depends(get_current_user)):
    """
    Test endpoint to simulate a file upload notification.
    """
    user_id = str(current_user["_id"])
    
    await manager.create_and_broadcast_notification(
        user_id=user_id,
        title="📁 File Uploaded",
        message="Your file 'document.pdf' has been uploaded successfully!",
        category=NotificationCategory.FILE.value,
        priority=NotificationPriority.MEDIUM.value,
        data={"filename": "document.pdf", "size": "2.5 MB"},
        notification_type="notification"
    )
    
    return {
        "message": "File upload notification sent!",
        "user_id": user_id
    }
