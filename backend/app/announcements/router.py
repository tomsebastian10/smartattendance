from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models.user import User, UserRole
from ..models.announcement import Announcement
from ..schemas.academic import AnnouncementBase, AnnouncementResponse
from ..auth.dependencies import get_current_user, get_current_hod
from ..models.academic import Enrollment

router = APIRouter(prefix="/announcements", tags=["Announcements"])

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
        is_global=ann_in.is_global
    )
    db.add(new_ann)
    db.commit()
    db.refresh(new_ann)
    
    # Add author name for response
    new_ann.author_name = current_hod.name
    return new_ann

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
        ).order_by(Announcement.created_at.desc()).all()
    else:
        # Faculty/Admin see all
        announcements = db.query(Announcement).order_by(Announcement.created_at.desc()).all()
    
    for ann in announcements:
        ann.author_name = ann.author.name
        
    return announcements
