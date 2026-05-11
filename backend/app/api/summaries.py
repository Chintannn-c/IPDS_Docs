from fastapi import APIRouter, Depends, HTTPException, Response, BackgroundTasks
from app.services.auth_service import oauth2_scheme, get_current_user
from app.services.encryption_service import decrypt_data
from app.db.database import Database
from app.models.schemas import DocumentSummary, SummarizedBy, SummarySaveRequest
from app.models.task_models import SummarizationTask, TaskStatus
from app.services.ai_service import AIService
from datetime import datetime, timezone
import os
import fitz  # PyMuPDF
from bson import ObjectId
import io
from PIL import Image
import pytesseract
import hashlib
from uuid import uuid4
from app.websocket_manager import manager
from concurrent.futures import ThreadPoolExecutor, as_completed
import time
from app.core.performance import timing_decorator

router = APIRouter()

UPLOAD_DIR = "uploads"

# In-memory task storage (use Redis in production for persistence)
tasks_store = {}

def compute_file_hash(file_path: str) -> str:
    """Compute SHA256 hash of file for cache validation."""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

@timing_decorator("OCR Extraction")
def extract_text_with_ocr(file_path: str, filename: str, decrypted_data: bytes) -> str:
    """Extracts text from PDF using OCR with parallel processing and adaptive resolution."""
    try:
        print(f"[OCR] Starting OCR extraction for: {filename}")
        
        # Parallel OCR processing for better performance
        def process_page(page_num, pdf_bytes):
            # Each thread opens its own document instance to avoid threading issues
            doc = fitz.open(stream=pdf_bytes, filetype="pdf")
            page = doc[page_num]
            page_rect = page.rect
            
            # Adaptive resolution based on page size
            # Small pages or detailed content get higher DPI
            if page_rect.width < 400 or page_rect.height < 600:
                zoom = 3  # High quality for small text
            else:
                zoom = 2  # Standard quality
            
            # Extract page as image
            pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom))
            img_data = pix.tobytes("png")
            
            # Convert to PIL Image and run OCR
            img = Image.open(io.BytesIO(img_data))
            page_text = pytesseract.image_to_string(img, lang='eng')
            
            doc.close()  # Close this thread's document instance
            return page_num, page_text
        
        # Get page count from a temporary document
        temp_doc = fitz.open(stream=decrypted_data, filetype="pdf")
        page_count = len(temp_doc)
        temp_doc.close()
        
        # Process pages in parallel (up to 4 concurrent)
        from app.core.config import settings
        max_workers = min(settings.OCR_PARALLEL_PAGES, page_count)
        
        ocr_results = {}
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {executor.submit(process_page, i, decrypted_data): i for i in range(page_count)}
            for future in as_completed(futures):
                page_num, page_text = future.result()
                ocr_results[page_num] = page_text
                print(f"[OCR] Completed page {page_num + 1}/{page_count}")
        
        # Reconstruct text in correct order
        ocr_text = ""
        for i in range(page_count):
            ocr_text += f"\n--- Page {i + 1} ---\n{ocr_results[i]}"
        
        print(f"[OCR] Extracted {len(ocr_text)} characters from {page_count} pages")
        return ocr_text
    except Exception as e:
        print(f"[OCR] Error during OCR extraction: {e}")
        return ""

def extract_text_from_file(file_path: str, filename: str, file_record: dict = None) -> str:
    """Extracts text from various file formats with OCR fallback and smart caching."""
    ext = os.path.splitext(filename)[1].lower()
    
    # Decrypt first
    with open(file_path, "rb") as f:
        encrypted_data = f.read()
    
    decrypted_data = decrypt_data(encrypted_data)
    
    if ext == ".pdf":
        # Check cache first
        if file_record and file_record.get("ocr_cache"):
            file_hash = compute_file_hash(file_path)
            cache = file_record["ocr_cache"]
            if cache.get("file_hash") == file_hash:
                print(f"[CACHE] Using cached OCR text ({len(cache['text'])} chars)")
                return cache["text"]
            else:
                print(f"[CACHE] File hash mismatch, cache invalidated")
        
        try:
            # First try normal text extraction
            doc = fitz.open(stream=decrypted_data, filetype="pdf")
            text = ""
            page_count = len(doc)
            for page in doc:
                text += page.get_text()
            doc.close()  # Close after text extraction
            
            # Smart OCR trigger based on text density
            # Check if there's meaningful text content
            word_count = len(text.strip().split())
            char_density = len(text.strip()) / max(page_count, 1)
            
            # Trigger OCR if text is sparse or low density
            if word_count < 20 or char_density < 10:
                print(f"[OCR] Insufficient text (words: {word_count}, density: {char_density:.1f}), using OCR...")
                text = extract_text_with_ocr(file_path, filename, decrypted_data)
                
                # Cache OCR result
                if file_record:
                    db = Database.get_db()
                    db.files.update_one(
                        {"_id": file_record["_id"]},
                        {"$set": {"ocr_cache": {
                            "text": text,
                            "extracted_at": datetime.now(timezone.utc),
                            "file_hash": compute_file_hash(file_path)
                        }}}
                    )
                    print(f"[CACHE] OCR text cached for future use")
            else:
                print(f"[TEXT] Extracted {len(text)} characters from PDF")
            
            return text
        except Exception as e:
            print(f"Error extracting PDF text: {e}")
            return ""
    
    elif ext in [".jpg", ".jpeg", ".png"]:
        # Direct OCR for image files
        try:
            print(f"[OCR] Processing image file: {filename}")
            img = Image.open(io.BytesIO(decrypted_data))
            text = pytesseract.image_to_string(img, lang='eng')
            print(f"[OCR] Extracted {len(text)} characters from image")
            return text
        except Exception as e:
            print(f"[OCR] Error extracting text from image: {e}")
            return ""
    
    elif ext in [".txt", ".md", ".py", ".dart", ".js", ".html", ".css"]:
        try:
            return decrypted_data.decode("utf-8")
        except UnicodeDecodeError:
            try:
                return decrypted_data.decode("latin-1")
            except:
                return ""
    else:
        return ""

@router.post("/save")
async def save_summary(req: SummarySaveRequest, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    
    # Check if document exists and belongs to user
    file_record = db.files.find_one({"_id": req.document_id, "owner_id": current_user["_id"]})
    if not file_record:
        raise HTTPException(status_code=404, detail="Document not found")

    # Get latest version
    last_summary = db.document_summaries.find_one(
        {"document_id": req.document_id},
        sort=[("version", -1)]
    )
    new_version = (last_summary["version"] + 1) if last_summary else 1

    summary_doc = {
        "document_id": req.document_id,
        "document_name": req.document_name,
        "summary": str(req.summary_data.get("summary", "") or ""),
        "key_points": req.summary_data.get("key_points", []) or [],
        "risk_flags": req.summary_data.get("risk_flags", []) or [],
        "content_preview": str(req.summary_data.get("content_preview", "") or ""),
        "version": new_version,
        "summarized_by": {
            "user_id": str(current_user["_id"]),
            "user_email": current_user["email"]
        },
        "summarized_at": datetime.now(timezone.utc),
        "ai_model": req.summary_data.get("used_model", "unknown")
    }

    print(f"[SUMMARIES] Saving summary v{new_version} for doc: {req.document_name}")
    result = db.document_summaries.insert_one(summary_doc)
    summary_doc["_id"] = str(result.inserted_id)
    
    return summary_doc

@router.get("/history")
async def get_summary_history(document_id: str = None, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    query = {"summarized_by.user_id": str(current_user["_id"])}
    if document_id:
        query["document_id"] = document_id
        
    summaries = list(db.document_summaries.find(query).sort("summarized_at", -1))
    for s in summaries:
        s["_id"] = str(s["_id"])
    return summaries

@router.get("/{summary_id}")
async def get_summary(summary_id: str, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    try:
        summary = db.document_summaries.find_one({"_id": ObjectId(summary_id)})
    except:
        raise HTTPException(status_code=400, detail="Invalid summary ID")

    if not summary:
        raise HTTPException(status_code=404, detail="Summary not found")
        
    if summary["summarized_by"]["user_id"] != str(current_user["_id"]):
        raise HTTPException(status_code=403, detail="Unauthorized access to this summary")

    summary["_id"] = str(summary["_id"])
    return summary

@router.post("/notes/summarize")
async def summarize_note(
    request: dict,
    current_user: dict = Depends(get_current_user)
):
    """
    Summarize note content using AI.
    Does NOT save to history - just returns the summary text.
    """
    content = request.get("content", "")
    
    if not content or len(content.strip()) < 50:
        raise HTTPException(
            status_code=400,
            detail="Note content is too short to summarize (minimum 50 characters)"
        )
    
    try:
        # Use AI service to generate structured summary
        ai_service = AIService()
        result = ai_service.summarize_note_structured(content)
        
        # Validate result
        if not result.get("summary_paragraph"):
            raise HTTPException(
                status_code=500,
                detail="Failed to generate summary"
            )
        
        return {
            "summary_paragraph": result.get("summary_paragraph", ""),
            "bullet_points": result.get("bullet_points", []),
            "keywords": result.get("keywords", []),
            "success": True
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Summarization failed: {str(e)}"
        )

@router.delete("/{summary_id}")
async def delete_summary(summary_id: str, current_user: dict = Depends(get_current_user)):
    """Delete a summary from the database."""
    db = Database.get_db()
    try:
        # Find the summary first to check ownership
        summary = db.document_summaries.find_one({"_id": ObjectId(summary_id)})
    except:
        raise HTTPException(status_code=400, detail="Invalid summary ID")

    if not summary:
        raise HTTPException(status_code=404, detail="Summary not found")
        
    # Check if the user owns this summary
    if summary["summarized_by"]["user_id"] != str(current_user["_id"]):
        raise HTTPException(status_code=403, detail="Unauthorized to delete this summary")

    # Delete the summary
    result = db.document_summaries.delete_one({"_id": ObjectId(summary_id)})
    
    if result.deleted_count == 0:
        raise HTTPException(status_code=500, detail="Failed to delete summary")
    
    print(f"[SUMMARIES] Deleted summary {summary_id} by user {current_user['email']}")
    return {"message": "Summary deleted successfully", "deleted_id": summary_id}


@router.post("/resummarize/{document_id}")
async def resummarize(document_id: str, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    
    # Lookup using UUID string (not ObjectId - this system uses UUID for file IDs)
    file_record = db.files.find_one({"_id": document_id, "owner_id": current_user["_id"]})
    if not file_record:
        raise HTTPException(status_code=404, detail="Document not found")

    # Extract text with caching support
    text = extract_text_from_file(file_record["path"], file_record["filename"], file_record)
    # Removed strict check to allow AI to handle empty text (e.g. image-only PDFs)
    if text is None:
        text = ""
        
    # Analyze using Mistral with chunking support for large documents
    # Use chunked analysis to handle documents of any size (same as initial analysis)
    analysis = AIService.analyze_document_chunked(text) or {}
    
    # Save as new version automatically
    last_summary = db.document_summaries.find_one(
        {"document_id": document_id},
        sort=[("version", -1)]
    )
    new_version = (last_summary["version"] + 1) if last_summary else 1

    summary_doc = {
        "document_id": document_id,
        "document_name": file_record["filename"],
        "summary": str(analysis.get("summary", "") or ""),
        "key_points": analysis.get("key_points", []) or [],
        "risk_flags": analysis.get("risk_flags", []) or [],
        "content_preview": str(analysis.get("content_preview", "") or ""),
        "version": new_version,
        "summarized_by": {
            "user_id": str(current_user["_id"]),
            "user_email": current_user["email"]
        },
        "summarized_at": datetime.now(timezone.utc),
        "ai_model": analysis.get("used_model", "unknown")
    }

    print(f"[SUMMARIES] Re-summarized v{new_version} for: {file_record['filename']}")
    result = db.document_summaries.insert_one(summary_doc)
    summary_doc["_id"] = str(result.inserted_id)
    
    # Update main file record for consistency/legacy fallback
    db.files.update_one(
        {"_id": document_id},
        {"$set": {"analysis": analysis, "analyzed_at": datetime.now(timezone.utc)}}
    )
    
    return summary_doc

# Background processing function
async def process_summarization_background(task_id: str, document_id: str, user: dict):
    """Background task to process document summarization asynchronously."""
    try:
        db = Database.get_db()
        
        # Update task status: EXTRACTING
        tasks_store[task_id]["status"] = TaskStatus.EXTRACTING
        tasks_store[task_id]["progress"] = 20
        tasks_store[task_id]["updated_at"] = datetime.now(timezone.utc)
        
        # Send WebSocket update
        await manager.send_personal_message(
            {"type": "task_update", "task_id": task_id, "status": "extracting", "progress": 20},
            user["_id"]
        )
        
        # Get file record
        file_record = db.files.find_one({"_id": document_id, "owner_id": user["_id"]})
        if not file_record:
            raise Exception("Document not found")
        
        # Extract text (with caching)
        text = extract_text_from_file(file_record["path"], file_record["filename"], file_record)
        if text is None:
            text = ""
        
        # Update task status: ANALYZING
        tasks_store[task_id]["status"] = TaskStatus.ANALYZING
        tasks_store[task_id]["progress"] = 60
        tasks_store[task_id]["updated_at"] = datetime.now(timezone.utc)
        
        await manager.send_personal_message(
            {"type": "task_update", "task_id": task_id, "status": "analyzing", "progress": 60},
            user["_id"]
        )
        
        # Run AI analysis (ALWAYS FRESH)
        max_chars = 15000
        truncated_text = text[:max_chars]
        analysis = AIService.analyze_document(truncated_text) or {}
        
        # Save summary
        last_summary = db.document_summaries.find_one(
            {"document_id": document_id},
            sort=[("version", -1)]
        )
        new_version = (last_summary["version"] + 1) if last_summary else 1
        
        summary_doc = {
            "document_id": document_id,
            "document_name": file_record["filename"],
            "summary": str(analysis.get("summary", "") or ""),
            "key_points": analysis.get("key_points", []) or [],
            "risk_flags": analysis.get("risk_flags", []) or [],
            "content_preview": str(analysis.get("content_preview", "") or ""),
            "version": new_version,
            "summarized_by": {
                "user_id": str(user["_id"]),
                "user_email": user["email"]
            },
            "summarized_at": datetime.now(timezone.utc),
            "ai_model": analysis.get("used_model", "unknown")
        }
        
        result = db.document_summaries.insert_one(summary_doc)
        summary_doc["_id"] = str(result.inserted_id)
        
        # Update main file record
        db.files.update_one(
            {"_id": document_id},
            {"$set": {"analysis": analysis, "analyzed_at": datetime.now(timezone.utc)}}
        )
        
        # Update task status: COMPLETE
        tasks_store[task_id]["status"] = TaskStatus.COMPLETE
        tasks_store[task_id]["progress"] = 100
        tasks_store[task_id]["result"] = summary_doc
        tasks_store[task_id]["updated_at"] = datetime.now(timezone.utc)
        
        print(f"[TASK] Completed async summarization for task {task_id}")
        
        await manager.send_personal_message(
            {"type": "task_complete", "task_id": task_id, "result": summary_doc},
            user["_id"]
        )
        
    except Exception as e:
        print(f"[TASK] Error in background task {task_id}: {e}")
        tasks_store[task_id]["status"] = TaskStatus.FAILED
        tasks_store[task_id]["error"] = str(e)
        tasks_store[task_id]["updated_at"] = datetime.now(timezone.utc)
        
        await manager.send_personal_message(
            {"type": "task_failed", "task_id": task_id, "error": str(e)},
            user["_id"]
        )

@router.post("/resummarize-async/{document_id}")
async def resummarize_async(
    document_id: str,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user)
):
    """
    Async endpoint for document summarization with background processing.
    Returns immediately with task_id for status polling.
    """
    db = Database.get_db()
    
    # Verify document exists
    file_record = db.files.find_one({"_id": document_id, "owner_id": current_user["_id"]})
    if not file_record:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Create task
    task_id = str(uuid4())
    task = {
        "task_id": task_id,
        "document_id": document_id,
        "document_name": file_record["filename"],
        "status": TaskStatus.PENDING,
        "progress": 0,
        "result": None,
        "error": None,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc)
    }
    tasks_store[task_id] = task
    
    # Add background task
    background_tasks.add_task(
        process_summarization_background,
        task_id,
        document_id,
        current_user
    )
    
    print(f"[TASK] Created async summarization task {task_id} for document {file_record['filename']}")
    
    return {
        "task_id": task_id,
        "status": "pending",
        "message": "Summarization task started in background"
    }

@router.get("/tasks/{task_id}")
async def get_task_status(task_id: str, current_user: dict = Depends(get_current_user)):
    """Get the status of an async summarization task."""
    if task_id not in tasks_store:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = tasks_store[task_id]
    return {
        "task_id": task["task_id"],
        "document_id": task["document_id"],
        "document_name": task["document_name"],
        "status": task["status"],
        "progress": task["progress"],
        "result": task["result"],
        "error": task["error"],
        "created_at": task["created_at"],
        "updated_at": task["updated_at"]
    }

@router.get("/{summary_id}/export-pdf")
async def export_pdf(summary_id: str, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    try:
        summary = db.document_summaries.find_one({"_id": ObjectId(summary_id)})
        if not summary:
            raise HTTPException(status_code=404, detail="Summary not found")
        
        # 1. Start PDF
        doc = fitz.open()
        page = doc.new_page()
        y = 50
        
        # Helper to safely insert text (strips non-ASCII for maximum compatibility)
        def safe_text(text):
            if not text: return ""
            return "".join([c if ord(c) < 128 else "?" for c in str(text)])

        # Header (Standard Helvetica)
        page.insert_text((50, y), "IPDS - Document Summary Report", fontsize=18)
        y += 40
        
        # 2. Date handling
        summarized_at = summary.get('summarized_at', datetime.now(timezone.utc))
        if summarized_at.tzinfo is None:
            summarized_at = summarized_at.replace(tzinfo=timezone.utc)
        display_date = summarized_at.astimezone().strftime('%d %b %Y, %I:%M %p')

        # 3. Basic Info
        page.insert_text((50, y), f"Document: {safe_text(summary.get('document_name'))}", fontsize=12)
        y += 20
        page.insert_text((50, y), f"Summary Version: v{summary.get('version', 1)}", fontsize=12)
        y += 20
        page.insert_text((50, y), f"Summarized By: {safe_text(summary.get('summarized_by', {}).get('user_email'))}", fontsize=12)
        y += 20
        page.insert_text((50, y), f"Summarized On: {display_date}", fontsize=12)
        y += 20
        page.insert_text((50, y), f"AI Model: {safe_text(summary.get('ai_model', 'unknown'))}", fontsize=12)
        y += 30
        
        page.draw_line((50, y), (550, y))
        y += 30
        
        # 4. Summary Text
        page.insert_text((50, y), "SUMMARY", fontsize=14)
        y += 20
        summary_text = safe_text(summary.get('summary', 'No summary content.'))
        page.insert_textbox(fitz.Rect(50, y, 550, y + 100), summary_text)
        y += 120
        
        # 5. Key Points
        page.insert_text((50, y), "KEY POINTS", fontsize=14)
        y += 20
        for pt in summary.get('key_points', []):
            page.insert_text((50, y), f"- {safe_text(pt)}", fontsize=11)
            y += 15
            if y > 750:
                page = doc.new_page()
                y = 50
        
        # 6. Risk Flags
        y += 20
        page.insert_text((50, y), "SECURITY RISK FLAGS", fontsize=14)
        y += 20
        risk_flags = summary.get('risk_flags', [])
        if risk_flags:
            for flag in risk_flags:
                page.insert_text((50, y), f"[!] {safe_text(flag)}", fontsize=11, color=(1, 0, 0))
                y += 15
        else:
            page.insert_text((50, y), "No security risks detected.", fontsize=11)

        # 7. Finalize
        pdf_stream = io.BytesIO()
        doc.save(pdf_stream)
        doc.close()
        
        safe_filename = "".join([c for c in summary.get("document_name", "download") if c.isalnum() or c in "._- "]).strip()
        
        return Response(
            content=pdf_stream.getvalue(),
            media_type="application/pdf",
            headers={"Content-Disposition": f'attachment; filename="summary_{safe_filename}.pdf"'}
        )
    except Exception as e:
        print(f"ERROR in PDF Export: {str(e)}")
        raise HTTPException(status_code=500, detail=f"PDF Generation failed: {str(e)}")