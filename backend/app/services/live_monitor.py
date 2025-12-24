from datetime import datetime, timezone
from typing import Optional
from app.db.database import db
from app.models.schemas import ActivityLog, LogActor, LogTarget, FileTracking, FileStages, FileStage

class LiveMonitor:
    @staticmethod
    async def log_activity(
        actor: LogActor,
        action: str,
        status: str,
        target: Optional[LogTarget] = None,
        metadata: Optional[dict] = None
    ):
        """
        Logs a system activity and sends it to the specific user via WebSocket.
        """
        from app.websocket_manager import manager

        log_id = f"log_{int(datetime.now(timezone.utc).timestamp()*1000)}"
        
        log_entry = ActivityLog(
            log_id=log_id,
            timestamp=datetime.now(timezone.utc),
            actor=actor,
            user_id=actor.user_id,
            action=action,
            target=target,
            status=status,
            metadata=metadata
        )
        
        # Save to DB (Synchronous PyMongo)
        if db.db is not None:
             db.db.activity_logs.insert_one(log_entry.dict())
        
        # Send to specific user via WebSocket
        if actor.user_id and actor.user_id != "unknown":
            await manager.send_personal_message({
                "type": "log.new",
                "data": log_entry.dict(exclude_none=True) 
            }, actor.user_id)
        
    @staticmethod
    async def init_file_tracking(file_id: str, actor_id: str):
        """
        Starts tracking a new file's lifecycle.
        """
        from app.websocket_manager import manager

        tracking = FileTracking(
            file_id=file_id,
            current_stage="INITIATED",
            stages=FileStages(
                initiated=FileStage(completed=True, timestamp=datetime.now(timezone.utc), actor_id=actor_id)
            )
        )
        
        if db.db is not None:
            # Upsert to avoid duplicates if re-uploaded/re-init
            db.db.file_tracking.update_one(
                {"file_id": file_id},
                {"$set": tracking.dict()},
                upsert=True
            )
            
        if actor_id:
            await manager.send_personal_message({
                "type": "file.tracking_update",
                "data": tracking.dict(exclude_none=True)
            }, actor_id)

    @staticmethod
    async def update_file_stage(file_id: str, stage: str, actor_id: str, status: str = "completed"):
        """
        Updates the stage of a file (e.g. verified, approved).
        """
        from app.websocket_manager import manager

        if db.db is None:
            return

        # Fetch current state
        record = db.db.file_tracking.find_one({"file_id": file_id})
        if not record:
            return # Should have initiated first
            
        tracking = FileTracking(**record)
        
        # Update specific stage
        new_stage_data = FileStage(completed=True, timestamp=datetime.now(timezone.utc), actor_id=actor_id)
        
        if stage == "verified":
            tracking.stages.verified = new_stage_data
            tracking.current_stage = "VERIFIED"
        elif stage == "approved":
            tracking.stages.approved = new_stage_data
            tracking.current_stage = "APPROVED"
        elif stage == "closed":
            tracking.stages.closed = new_stage_data
            tracking.current_stage = "CLOSED"
            
        # Save Update
        db.db.file_tracking.update_one(
            {"file_id": file_id},
            {"$set": tracking.dict()}
        )
        
        if actor_id:
            await manager.send_personal_message({
                "type": "file.tracking_update",
                "data": tracking.dict(exclude_none=True)
            }, actor_id)
