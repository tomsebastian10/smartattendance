from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, time, date
from ..models.academic import LeaveType, LeaveStatus
from ..models.attendance import AttendanceStatus

class SubjectBase(BaseModel):
    name: str
    code: str
    credits: int
    department: Optional[str] = None

class SubjectResponse(SubjectBase):
    id: int
    class Config:
        from_attributes = True

class AttendanceStats(BaseModel):
    subject_id: int
    subject_name: str
    subject_code: str
    total_classes: int
    present_count: int
    attendance_percentage: float
    status: str # "SAFE", "WARNING", "CRITICAL"

class StudentDashboardStats(BaseModel):
    overall_attendance: float
    subject_stats: List[AttendanceStats]
    prediction: str # Message about how many classes to attend

class TimetableSlotResponse(BaseModel):
    id: int
    subject_name: str
    subject_code: str
    day_of_week: int
    start_time: time
    end_time: time
    room_name: str
    class Config:
        from_attributes = True

class LeaveRequestCreate(BaseModel):
    leave_type: LeaveType
    start_date: date
    end_date: date
    reason: str
    document_url: Optional[str] = None

class LeaveRequestResponse(BaseModel):
    id: int
    student_name: Optional[str] = None
    leave_type: LeaveType
    start_date: date
    end_date: date
    status: LeaveStatus
    reason: str
    created_at: datetime
    class Config:
        from_attributes = True
class StudentRosterItem(BaseModel):
    student_id: int
    name: str
    status: AttendanceStatus
    total_score: Optional[float] = 0.0

class AnnouncementBase(BaseModel):
    title: str
    body: str
    target_subject_id: Optional[int] = None
    is_global: bool = False

class AnnouncementResponse(AnnouncementBase):
    id: int
    author_name: str
    created_at: datetime
    class Config:
        from_attributes = True
