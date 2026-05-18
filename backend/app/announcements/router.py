from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List
import os
import uuid
import shutil
from ..database import get_db
from ..models.user import User, UserRole
from ..models.announcement import Announcement
from ..schemas.academic import AnnouncementBase, AnnouncementResponse
from ..auth.dependencies import get_current_user, get_current_hod
from ..models.academic import Enrollment

router = APIRouter(prefix="/announcements", tags=["Announcements"])

@router.post("/upload-image")
def upload_announcement_image(
    file: UploadFile = File(...),
    current_hod: User = Depends(get_current_hod)
):
    # Ensure static uploads dir exists
    os.makedirs("uploads", exist_ok=True)
    
    # Generate unique filename to avoid naming conflicts
    ext = os.path.splitext(file.filename)[1]
    filename = f"{uuid.uuid4()}{ext}"
    filepath = os.path.join("uploads", filename)
    
    # Save the file
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # Return the static URL path
    return {"image_url": f"/uploads/{filename}"}

@router.post("/", response_model=AnnouncementResponse)
def create_announcement(
    ann_in: AnnouncementBase,
    db: Session = Depends(get_db),
    current_hod: User = Depends(get_current_hod)
):
    new_ann = Announcement(
        author_id=current_hod.id,
        title=ann_in.title,
        body=ann_in.body,
        target_subject_id=ann_in.target_subject_id,
        target_role=ann_in.target_role,
        is_global=ann_in.is_global,
        image_url=ann_in.image_url
    )
    db.add(new_ann)
    db.commit()
    db.refresh(new_ann)
    
    # Add author name for response
    new_ann.author_name = current_hod.name
    return new_ann

@router.delete("/{announcement_id}")
def delete_announcement(
    announcement_id: int,
    db: Session = Depends(get_db),
    current_hod: User = Depends(get_current_hod)
):
    ann = db.query(Announcement).filter(Announcement.id == announcement_id).first()
    if not ann:
        raise HTTPException(status_code=404, detail="Announcement not found")
        
    # Remove image if it exists
    if ann.image_url:
        filename = ann.image_url.split("/")[-1]
        filepath = os.path.join("uploads", filename)
        if os.path.exists(filepath):
            try:
                os.remove(filepath)
            except Exception as e:
                print(f"Failed to delete file {filepath}: {e}")
                
    db.delete(ann)
    db.commit()
    return {"status": "success", "message": "Announcement deleted successfully"}

@router.get("/", response_model=List[AnnouncementResponse])
def get_my_announcements(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == UserRole.STUDENT:
        # Get global announcements + subject-specific ones for enrolled subjects
        subject_ids = [e.subject_id for e in db.query(Enrollment).filter(Enrollment.student_id == current_user.id).all()]
        announcements = db.query(Announcement).filter(
            (Announcement.is_global == True) | (Announcement.target_subject_id.in_(subject_ids))
        ).filter(
            (Announcement.target_role == None) | (Announcement.target_role == "STUDENT")
        ).order_by(Announcement.created_at.desc()).all()
    elif current_user.role == UserRole.FACULTY:
        # Faculty see targeted FACULTY announcements or completely general ones
        announcements = db.query(Announcement).filter(
            (Announcement.target_role == None) | (Announcement.target_role == "FACULTY")
        ).order_by(Announcement.created_at.desc()).all()
    else:
        # Admin/HOD see all
        announcements = db.query(Announcement).order_by(Announcement.created_at.desc()).all()
    
    for ann in announcements:
        ann.author_name = ann.author.name
        
    return announcements
