from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime, timedelta
from pydantic import BaseModel
from typing import List, Optional
import uuid
from app.services.auth_service import get_current_user
from app.models.schemas import Item

router = APIRouter()

# Use MongoDB collection for persistence
from app.db.database import Database

# We'll store items in the "items" collection
# No global in‑memory list is needed; the collection is accessed per request.

from bson import ObjectId
from datetime import datetime


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

@router.get("/", response_model=List[Item])
async def read_items(current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    if db is None:
        return []
    docs = list(db["items"].find({"owner_id": current_user["_id"]}))
    return [
        Item(
            id=str(doc.get("_id")), 
            name=doc.get("name", ""), 
            description=doc.get("description", ""),
            type=doc.get("type", "text"),
            owner_id=str(doc.get("owner_id")),
            is_summarized=doc.get("is_summarized", False),
            summary_paragraph=doc.get("summary_paragraph"),
            bullet_points=doc.get("bullet_points", []),
            keywords=doc.get("keywords", []),
            original_content=doc.get("original_content")
        ) for doc in docs
    ]

@router.post("/", response_model=Item)
async def create_item(item: ItemBase, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="MongoDB not connected")
    
    item_dict = item.dict()
    item_dict["owner_id"] = current_user["_id"]
    
    result = db["items"].insert_one(item_dict)
    return Item(
        id=str(result.inserted_id), 
        name=item.name, 
        description=item.description,
        type=item.type,
        owner_id=str(current_user["_id"]),
        is_summarized=item.is_summarized,
        summary_paragraph=item.summary_paragraph,
        bullet_points=item.bullet_points,
        keywords=item.keywords,
        original_content=item.original_content
    )

@router.put("/{item_id}", response_model=Item)
async def update_item(item_id: str, item_update: ItemUpdate, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="MongoDB not connected")
    
    update_data = {k: v for k, v in item_update.dict().items() if v is not None}
    
    result = db["items"].find_one_and_update(
        {"_id": ObjectId(item_id), "owner_id": current_user["_id"]},
        {"$set": update_data},
        return_document=True
    )
    
    if not result:
        raise HTTPException(status_code=404, detail="Item not found")
        
    return Item(
        id=str(result["_id"]),
        name=result["name"],
        description=result["description"],
        type=result.get("type", "text"),
        owner_id=str(result["owner_id"]),
        is_summarized=result.get("is_summarized", False),
        summary_paragraph=result.get("summary_paragraph"),
        bullet_points=result.get("bullet_points", []),
        keywords=result.get("keywords", []),
        original_content=result.get("original_content")
    )

@router.delete("/{item_id}")
async def delete_item(item_id: str, current_user: dict = Depends(get_current_user)):
    db = Database.get_db()
    if db is None:
        raise HTTPException(status_code=500, detail="MongoDB not connected")
        
    result = db["items"].delete_one({"_id": ObjectId(item_id), "owner_id": current_user["_id"]})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Item not found")
    return {"message": "Item deleted successfully"}
