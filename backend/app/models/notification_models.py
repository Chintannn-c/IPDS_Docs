from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from datetime import datetime
from enum import Enum


class NotificationCategory(str, Enum):
    """Notification categories for organizing and filtering"""
    SECURITY = "security"
    FILE = "file"
    SYSTEM = "system"
    INFO = "info"


class NotificationPriority(str, Enum):
    """Priority levels for notifications"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    URGENT = "urgent"


class NotificationCreate(BaseModel):
    """Schema for creating a notification"""
    user_id: str
    title: str
    message: str
    category: NotificationCategory = NotificationCategory.INFO
    priority: NotificationPriority = NotificationPriority.MEDIUM
    data: Optional[Dict[str, Any]] = None  # Additional metadata
    
    class Config:
        use_enum_values = True


class NotificationUpdate(BaseModel):
    """Schema for updating a notification"""
    is_read: Optional[bool] = None
    
    class Config:
        use_enum_values = True


class NotificationResponse(BaseModel):
    """Schema for notification responses"""
    id: str
    user_id: str
    title: str
    message: str
    category: str
    priority: str
    is_read: bool = False
    data: Optional[Dict[str, Any]] = None
    created_at: datetime
    
    class Config:
        use_enum_values = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


class NotificationPreferences(BaseModel):
    """User notification preferences"""
    user_id: str
    enabled_categories: list[str] = [
        NotificationCategory.SECURITY.value,
        NotificationCategory.FILE.value,
        NotificationCategory.SYSTEM.value,
        NotificationCategory.INFO.value,
    ]
    min_priority: str = NotificationPriority.LOW.value
    sound_enabled: bool = True
    auto_delete_days: int = 30  # Auto-delete notifications older than X days
    
    class Config:
        use_enum_values = True


class NotificationListResponse(BaseModel):
    """Paginated notification list response"""
    notifications: list[NotificationResponse]
    total: int
    page: int
    page_size: int
    has_more: bool
