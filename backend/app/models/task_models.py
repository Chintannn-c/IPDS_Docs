from enum import Enum
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class TaskStatus(str, Enum):
    PENDING = "pending"
    EXTRACTING = "extracting"
    ANALYZING = "analyzing"
    COMPLETE = "complete"
    FAILED = "failed"

class SummarizationTask(BaseModel):
    task_id: str
    document_id: str
    document_name: str
    status: TaskStatus
    progress: int  # 0-100
    result: Optional[dict] = None
    error: Optional[str] = None
    created_at: datetime
    updated_at: datetime
