from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import List, Optional
from datetime import datetime
import re

def validate_strong_password(password: str) -> str:
    """Validate password meets security requirements"""
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters")
    if not re.search(r'[A-Z]', password):
        raise ValueError("Password must contain an uppercase letter")
    if not re.search(r'[a-z]', password):
        raise ValueError("Password must contain a lowercase letter")
    if not re.search(r'[0-9]', password):
        raise ValueError("Password must contain a number")
    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        raise ValueError("Password must contain a special character (!@#$%^&*...)")
    return password

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    name: str
    
    @field_validator('password')
    @classmethod
    def password_strength(cls, v):
        return validate_strong_password(v)

class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None

class PasswordChange(BaseModel):
    current_password: str
    new_password: str
    
    @field_validator('new_password')
    @classmethod
    def password_strength(cls, v):
        return validate_strong_password(v)

class PasswordConfirmation(BaseModel):
    password: str

class Session(BaseModel):
    """Active session tracking"""
    session_id: str
    device_fingerprint: str
    created_at: datetime
    last_active: datetime
    ip_address: Optional[str] = None

class TrustedDevice(BaseModel):
    """Enhanced device model for multi-account support"""
    # Core fields (required for backward compatibility)
    device_id: str
    name: str = "Unknown Device"
    type: str = "unknown"  # 'mobile', 'desktop', 'tablet', 'web'
    
    # Session & Account (optional)
    session_id: Optional[str] = None
    account_id: Optional[str] = None
    
    # Enhanced Detection (optional)
    os: Optional[str] = None
    browser_or_app: Optional[str] = None
    location: Optional[str] = None
    
    # Status Flags
    is_current_device: bool = False
    is_trusted: bool = False
    is_blocked: bool = False
    is_active: bool = True
    
    # Tracking
    last_active: Optional[datetime] = None
    created_at: Optional[datetime] = None
    ip_address: Optional[str] = None
    fingerprint: Optional[str] = None
    
    # Allow extra fields for backward compatibility
    model_config = {"extra": "allow", "strict": False}

class UserResponse(BaseModel):
    id: str
    email: EmailStr
    name: str
    role: str
    risk_score: int
    profile_image: Optional[str] = None
    trusted_devices: List[TrustedDevice] = []
    storage_used: int = 0
    storage_limit: int = 5368709120  # 5 GB default

class Token(BaseModel):
    access_token: str
    token_type: str

class FileModel(BaseModel):
    id: str
    filename: str
    size: int
    upload_date: datetime
    owner_id: str
    safety_score: int = 100
    scan_status: str = "scanned"
    is_risky: bool = False
    is_quarantined: bool = False
    risk_reason: Optional[str] = None

class EventLog(BaseModel):
    user_id: Optional[str] = None
    ip: str
    action: str
    timestamp: datetime
    device_info: str
    risk_level: str

class ItemUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    type: Optional[str] = None
    is_summarized: Optional[bool] = None
    summary_paragraph: Optional[str] = None
    bullet_points: Optional[List[str]] = None
    keywords: Optional[List[str]] = None
    original_content: Optional[str] = None

class ItemBase(BaseModel):
    name: str
    description: str
    type: str = "text"
    is_summarized: bool = False
    summary_paragraph: Optional[str] = None
    bullet_points: List[str] = []
    keywords: List[str] = []
    original_content: Optional[str] = None
    owner_id: str
    created_at: datetime
    updated_at: datetime

class Folder(BaseModel):
    id: str
    name: str
    parent_id: Optional[str] = None
    owner_id: str
    created_at: datetime

class Document(BaseModel):
    id: str
    title: str
    content: str
    folder_id: Optional[str] = None
    owner_id: str
    created_at: datetime
    updated_at: datetime

class Item(BaseModel):
    id: str
    name: str
    description: str
    type: str = "text"
    owner_id: str
    is_summarized: bool = False
    summary_paragraph: Optional[str] = None
    bullet_points: List[str] = []
    keywords: List[str] = []
    original_content: Optional[str] = None



class LogActor(BaseModel):
    user_id: str
    name: str
    role: str
    ip_address: Optional[str] = None

class LogTarget(BaseModel):
    type: str  # FILE, USER, SYSTEM
    id: Optional[str] = None
    name: Optional[str] = None

class ActivityLog(BaseModel):
    log_id: str
    timestamp: datetime
    actor: LogActor
    action: str
    user_id: Optional[str] = None
    target: Optional[LogTarget] = None
    status: str # SUCCESS, INFO, WARNING, ERROR
    metadata: Optional[dict] = None

class FileStage(BaseModel):
    completed: bool = False
    timestamp: Optional[datetime] = None
    actor_id: Optional[str] = None

class FileStages(BaseModel):
    initiated: FileStage = Field(default_factory=FileStage)
    verified: FileStage = Field(default_factory=FileStage)
    approved: FileStage = Field(default_factory=FileStage)
    closed: FileStage = Field(default_factory=FileStage)

class FileTracking(BaseModel):
    file_id: str
    current_stage: str # INITIATED, VERIFIED, APPROVED, CLOSED
    stages: FileStages
    is_delayed: bool = False
    sla_deadline: Optional[datetime] = None

class SummarizedBy(BaseModel):
    user_id: str
    user_email: str

class DocumentSummary(BaseModel):
    document_id: str
    document_name: str
    summary: str
    key_points: List[str]
    risk_flags: List[str]
    content_preview: str
    version: int = 1
    summarized_by: SummarizedBy
    summarized_at: datetime = Field(default_factory=datetime.now)
    ai_model: str = "mistral-large-latest"

class SummarySaveRequest(BaseModel):
    document_id: str
    document_name: str
    summary_data: dict
