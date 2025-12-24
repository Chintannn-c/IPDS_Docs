from fastapi import APIRouter, Depends, HTTPException, Response
from app.services.auth_service import oauth2_scheme, get_current_user
from app.services.encryption_service import decrypt_data
from app.db.database import Database
from app.models.schemas import DocumentSummary, SummarizedBy, SummarySaveRequest
from app.services.ai_service import AIService
from datetime import datetime, timezone
import os
import fitz  # PyMuPDF
from bson import ObjectId
import io

router = APIRouter()

UPLOAD_DIR = "uploads"

def extract_text_from_file(file_path: str, filename: str) -> str:
    """Extracts text from various file formats."""
    ext = os.path.splitext(filename)[1].lower()
    
    # Decrypt first
    with open(file_path, "rb") as f:
        encrypted_data = f.read()
    
    decrypted_data = decrypt_data(encrypted_data)
    
    if ext == ".pdf":
        try:
            doc = fitz.open(stream=decrypted_data, filetype="pdf")
            text = ""
            for page in doc:
                text += page.get_text()
            doc.close()
            return text
        except Exception as e:
            print(f"Error extracting PDF text: {e}")
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
        "ai_model": "mistral-large-latest"
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

@router.post("/resummarize/{document_id}")
async def resummarize(document_id: str, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    
    # Lookup using UUID string (not ObjectId - this system uses UUID for file IDs)
    file_record = db.files.find_one({"_id": document_id, "owner_id": current_user["_id"]})
    if not file_record:
        raise HTTPException(status_code=404, detail="Document not found")

    # Extract text
    text = extract_text_from_file(file_record["path"], file_record["filename"])
    # Removed strict check to allow AI to handle empty text (e.g. image-only PDFs)
    if text is None:
        text = ""

    # Analyze using Mistral
    max_chars = 15000 
    truncated_text = text[:max_chars]
    # Failure-safe AI analysis - ensure we never crash on AI errors
    analysis = AIService.analyze_document(truncated_text) or {}
    
    # Save as new version automatically or return for UI to save? 
    # The requirement says "Stored as version + 1". So we save it.
    
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
        "ai_model": "mistral-large-latest"
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