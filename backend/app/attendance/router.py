from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime, timedelta, timezone
import uuid
import secrets
import os
import shutil
from ..database import get_db
from ..models.user import User, UserRole
from ..models.attendance import AttendanceSession, AttendanceRecord, SessionState, AttendanceStatus
from ..schemas.attendance import SessionCreate, SessionResponse, AttendanceVerify, AttendanceResult
from ..auth.dependencies import get_current_faculty, get_current_user, get_current_hod
from ..qr.service import qr_service
from ..schemas.academic import StudentDashboardStats, AttendanceStats, TimetableSlotResponse, LeaveRequestCreate, LeaveRequestResponse, StudentRosterItem, FacultySessionHistoryItem
from ..models.academic import Subject, Enrollment, TimetableSlot, LeaveRequest, LeaveStatus, LeaveType
from ..gps.service import gps_service
from ..ble.service import ble_service
from ..validation.engine import validation_engine
from ..models.attendance import AttendanceSession, AttendanceRecord, SessionState, AttendanceStatus, Classroom
from ..models.announcement import Announcement
from ..services.redis_service import redis_service
from ..services.logger import log_validation_event, log_fraud_event
from ..services.websocket_manager import manager

router = APIRouter(prefix="/attendance", tags=["Attendance"])

@router.get("/student-stats", response_model=StudentDashboardStats)
def get_student_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Fetch all enrollments for the student
    enrollments = db.query(Enrollment).filter(Enrollment.student_id == current_user.id).all()
    
    subject_stats = []
    total_present = 0
    total_classes = 0
    
    for enrollment in enrollments:
        subject = enrollment.subject
        # Total sessions conducted for this subject
        sessions_conducted = db.query(AttendanceSession).filter(AttendanceSession.subject_id == subject.id).count()
        # Present records for this student in this subject
        present_count = db.query(AttendanceRecord).join(AttendanceSession).filter(
            AttendanceRecord.student_id == current_user.id,
            AttendanceSession.subject_id == subject.id,
            AttendanceRecord.status == AttendanceStatus.PRESENT
        ).count()
        
        percentage = (present_count / sessions_conducted * 100) if sessions_conducted > 0 else 100.0
        
        status = "SAFE"
        if percentage < 75:
            status = "CRITICAL"
        elif percentage < 85:
            status = "WARNING"
            
        subject_stats.append(AttendanceStats(
            subject_id=subject.id,
            subject_name=subject.name,
            subject_code=subject.code,
            total_classes=sessions_conducted,
            present_count=present_count,
            attendance_percentage=round(percentage, 2),
            status=status
        ))
        
        total_present += present_count
        total_classes += sessions_conducted
        
    overall_percentage = (total_present / total_classes * 100) if total_classes > 0 else 100.0
    
    # Simple prediction logic
    prediction = "You are doing great! Keep it up."
    if overall_percentage < 75:
        # Simplified prediction: (0.75 * total_classes - total_present) / (1 - 0.75)
        # Assuming we want to reach 75%
        needed = int((0.75 * total_classes - total_present) / 0.25) if total_classes > 0 else 0
        prediction = f"You need to attend approximately {max(0, needed)} more classes to reach 75%."

    # Dynamic historic attendance trend calculation
    enrolled_subject_ids = [e.subject_id for e in enrollments]
    sessions = db.query(AttendanceSession).filter(
        AttendanceSession.subject_id.in_(enrolled_subject_ids)
    ).order_by(AttendanceSession.started_at.asc()).all()
    
    records = db.query(AttendanceRecord).filter(
        AttendanceRecord.student_id == current_user.id
    ).all()
    
    record_status = {r.session_id: r.status for r in records}
    
    attendance_trend = []
    total_conducted = 0
    total_present_so_far = 0
    
    for s in sessions:
        total_conducted += 1
        status = record_status.get(s.id, AttendanceStatus.ABSENT)
        if status == AttendanceStatus.PRESENT:
            total_present_so_far += 1
        percentage = (total_present_so_far / total_conducted * 100.0)
        attendance_trend.append(round(percentage, 2))
        
    if not attendance_trend:
        attendance_trend = [100.0]
    if len(attendance_trend) == 1:
        attendance_trend = [attendance_trend[0], attendance_trend[0]]
    if len(attendance_trend) > 10:
        attendance_trend = attendance_trend[-10:]

    return StudentDashboardStats(
        overall_attendance=round(overall_percentage, 2),
        subject_stats=subject_stats,
        prediction=prediction,
        attendance_trend=attendance_trend
    )

@router.get("/timetable", response_model=List[TimetableSlotResponse])
def get_timetable(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Fetch timetable slots for subjects the student is enrolled in
    slots = db.query(TimetableSlot).join(Subject).join(Enrollment).filter(
        Enrollment.student_id == current_user.id
    ).all()
    
    # Map to response schema
    result = []
    for slot in slots:
        classroom = db.query(Classroom).filter(Classroom.id == slot.classroom_id).first()
        result.append(TimetableSlotResponse(
            id=slot.id,
            subject_name=slot.subject.name,
            subject_code=slot.subject.code,
            subject_id=slot.subject_id,
            classroom_id=slot.classroom_id,
            day_of_week=slot.day_of_week,
            start_time=slot.start_time,
            end_time=slot.end_time,
            room_name=classroom.room_name if classroom else "Unknown"
        ))
    return result

@router.post("/leave-request", response_model=LeaveRequestResponse)
def apply_leave(
    leave_in: LeaveRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    new_request = LeaveRequest(
        student_id=current_user.id,
        leave_type=leave_in.leave_type,
        start_date=leave_in.start_date,
        end_date=leave_in.end_date,
        reason=leave_in.reason,
        document_url=leave_in.document_url
    )
    db.add(new_request)
    db.commit()
    db.refresh(new_request)
    return new_request

@router.get("/my-leaves", response_model=List[LeaveRequestResponse])
def get_student_leaves(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    requests = db.query(LeaveRequest).filter(
        LeaveRequest.student_id == current_user.id
    ).order_by(LeaveRequest.created_at.desc()).all()
    
    for req in requests:
        req.student_name = current_user.name
    return requests

@router.post("/upload-proof")
def upload_proof(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    # Ensure static uploads dir exists
    os.makedirs("uploads", exist_ok=True)
    
    # Generate unique filename to avoid naming conflicts
    ext = os.path.splitext(file.filename)[1]
    filename = f"proof_{uuid.uuid4()}{ext}"
    filepath = os.path.join("uploads", filename)
    
    # Save the file
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # Return the static URL path
    return {"document_url": f"/uploads/{filename}"}

@router.post("/start-session", response_model=SessionResponse)
def start_session(
    session_in: SessionCreate, 
    db: Session = Depends(get_db), 
    current_faculty: User = Depends(get_current_faculty)
):
    # Generate unique session identifiers
    session_token = secrets.token_urlsafe(16)
    qr_secret = secrets.token_hex(16)
    ble_uuid = str(uuid.uuid4())
    
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=session_in.duration_mins)

    # Safety fallback: if the requested classroom_id doesn't exist, use the first available one
    classroom_id = session_in.classroom_id
    classroom = db.query(Classroom).filter(Classroom.id == classroom_id).first()
    if not classroom:
        classroom = db.query(Classroom).first()
        if not classroom:
            raise HTTPException(status_code=400, detail="No classrooms found in the database. Please seed the database.")
        classroom_id = classroom.id
    
    new_session = AttendanceSession(
        faculty_id=current_faculty.id,
        classroom_id=classroom_id,
        subject_id=session_in.subject_id,
        session_token=session_token,
        qr_secret=qr_secret,
        ble_uuid=ble_uuid,
        state=SessionState.ACTIVE,
        expires_at=expires_at,
        faculty_lat=session_in.lat,
        faculty_long=session_in.long
    )
    
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    
    return new_session

@router.get("/active-session", response_model=Optional[SessionResponse])
def get_active_session(
    db: Session = Depends(get_db),
    current_faculty: User = Depends(get_current_faculty)
):
    # Find any currently active session started by this faculty
    session = db.query(AttendanceSession).filter(
        AttendanceSession.faculty_id == current_faculty.id,
        AttendanceSession.state == SessionState.ACTIVE
    ).first()
    return session

@router.post("/verify", response_model=AttendanceResult)
def verify_attendance(
    verify_in: AttendanceVerify, 
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    # 1. Fetch Session
    session = db.query(AttendanceSession).filter(
        AttendanceSession.session_token == verify_in.session_token,
        AttendanceSession.state == SessionState.ACTIVE
    ).first()
    
    if not session or datetime.now(timezone.utc) > session.expires_at:
        raise HTTPException(status_code=400, detail="Attendance session is not active or expired")

    # 2. Duplicate Check (Redis + DB)
    if redis_service.is_attendance_processed(session.id, current_user.id):
        raise HTTPException(status_code=400, detail="Attendance already marked for this session")

    # 3. Validation Logic (Modular Engine)
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    
    # Use Teacher's live location if available, otherwise fallback to Classroom DB location
    target_lat = session.faculty_lat if session.faculty_lat is not None else (classroom.gps_lat if classroom else 0)
    target_long = session.faculty_long if session.faculty_long is not None else (classroom.gps_long if classroom else 0)
    
    context = {
        "qr_secret": session.qr_secret,
        "lat": target_lat,
        "long": target_long,
        "radius": classroom.gps_radius_meters if classroom else 200,
        "ble_uuid": session.ble_uuid
    }
    
    # Prepare data for engine
    validation_data = {
        "qr_data": verify_in.qr_token,
        "gps_data": {"lat": verify_in.gps_data.lat, "long": verify_in.gps_data.long} if verify_in.gps_data else None,
        "ble_data": {"rssi": verify_in.ble_data.rssi, "teacher_uuid": verify_in.ble_data.teacher_uuid} if verify_in.ble_data else None
    }
    
    validation_result = validation_engine.process(validation_data, context)
    total_score = validation_result["total_score"]
    breakdown = validation_result["breakdown"]

    # 4. Status Determination
    # QR valid (20) + device trust (10) = 30 minimum for a valid QR scan.
    # GPS/BLE add bonus points but are not required for MVP.
    qr_score = breakdown["qr"]["score"]
    if qr_score > 0 and total_score >= 25:
        # Valid QR scan → always PRESENT
        status_result = AttendanceStatus.PRESENT
    elif total_score >= 50:
        status_result = AttendanceStatus.FLAGGED
    else:
        status_result = AttendanceStatus.ABSENT
    
    # 5. Store Record with Snapshot
    record = AttendanceRecord(
        student_id=current_user.id,
        session_id=session.id,
        qr_score=breakdown["qr"]["score"],
        gps_score=breakdown["gps"]["score"],
        ble_score=breakdown["ble"]["score"],
        device_score=breakdown["device"]["score"],
        total_score=total_score,
        status=status_result,
        validation_snapshot=breakdown, # Store the full breakdown as JSONB
        gps_lat=verify_in.gps_data.lat if verify_in.gps_data else None,
        gps_long=verify_in.gps_data.long if verify_in.gps_data else None,
        rssi_strength=verify_in.ble_data.rssi if verify_in.ble_data else None
    )
    
    db.add(record)
    
    # Mark as processed in Redis (Idempotency)
    redis_service.mark_attendance_processed(session.id, current_user.id)
    
    db.commit()

    # Trigger Real-time Dashboard Update (via Background Task)
    background_tasks.add_task(
        manager.broadcast_session_update, 
        str(session.id), 
        {
            "event": "NEW_ATTENDANCE",
            "student_name": current_user.name,
            "score": total_score,
            "status": status_result,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
    )
    
    log_validation_event("ATTENDANCE_VERIFIED", {
        "student_id": current_user.id,
        "session_id": session.id,
        "score": total_score,
        "snapshot": breakdown
    })
    
    return {
        "status": status_result,
        "score": total_score,
        "breakdown": {k: v["score"] for k, v in breakdown.items()}
    }

@router.get("/faculty-timetable", response_model=List[TimetableSlotResponse])
def get_faculty_timetable(
    db: Session = Depends(get_db),
    current_faculty: User = Depends(get_current_faculty)
):
    # Fetch slots where this faculty is teaching (assuming Subject model has faculty_id or similar, 
    # for now we'll fetch slots for subjects in the CS department as a placeholder or all subjects)
    slots = db.query(TimetableSlot).join(Subject).all() # Simplified for now
    
    result = []
    for slot in slots:
        classroom = db.query(Classroom).filter(Classroom.id == slot.classroom_id).first()
        result.append(TimetableSlotResponse(
            id=slot.id,
            subject_name=slot.subject.name,
            subject_code=slot.subject.code,
            subject_id=slot.subject_id,
            classroom_id=slot.classroom_id,
            day_of_week=slot.day_of_week,
            start_time=slot.start_time,
            end_time=slot.end_time,
            room_name=classroom.room_name if classroom else "Unknown"
        ))
    return result

@router.get("/current-class", response_model=Optional[TimetableSlotResponse])
def get_current_class(
    db: Session = Depends(get_db),
    current_faculty: User = Depends(get_current_faculty)
):
    now = datetime.now()
    current_day = now.weekday() # 0-6 (Mon-Sun)
    current_time = now.time()
    
    # Find slot that matches current day and time
    slot = db.query(TimetableSlot).filter(
        TimetableSlot.day_of_week == current_day,
        TimetableSlot.start_time <= current_time,
        TimetableSlot.end_time >= current_time
    ).first()
    
    if not slot: return None
    
    classroom = db.query(Classroom).filter(Classroom.id == slot.classroom_id).first()
    return TimetableSlotResponse(
        id=slot.id,
        subject_name=slot.subject.name,
        subject_code=slot.subject.code,
        subject_id=slot.subject_id,
        classroom_id=slot.classroom_id,
        day_of_week=slot.day_of_week,
        start_time=slot.start_time,
        end_time=slot.end_time,
        room_name=classroom.room_name if classroom else "Unknown"
    )

@router.get("/session/{session_id}/roster", response_model=List[StudentRosterItem])
def get_session_roster(
    session_id: int,
    db: Session = Depends(get_db),
    current_faculty: User = Depends(get_current_faculty)
):
    session = db.query(AttendanceSession).filter(AttendanceSession.id == session_id).first()
    if not session: raise HTTPException(status_code=404, detail="Session not found")
    
    # Get all students enrolled in this subject
    enrolled_students = db.query(User).join(Enrollment).filter(Enrollment.subject_id == session.subject_id).all()
    
    # Get all attendance records for this session
    records = {r.student_id: r for r in db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session_id).all()}
    
    roster = []
    for student in enrolled_students:
        record = records.get(student.id)
        roster.append(StudentRosterItem(
            student_id=student.id,
            name=student.name,
            status=record.status if record else AttendanceStatus.ABSENT,
            total_score=record.total_score if record else 0.0
        ))
    
    # Sort: Present on top, then alphabetical
    roster.sort(key=lambda x: (x.status != AttendanceStatus.PRESENT, x.name))
    return roster

@router.post("/session/{session_id}/mark-present/{student_id}")
def mark_student_present(
    session_id: int,
    student_id: int,
    db: Session = Depends(get_db),
    current_faculty: User = Depends(get_current_faculty)
):
    # Check if record exists
    record = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session_id,
        AttendanceRecord.student_id == student_id
    ).first()
    
    if record:
        record.status = AttendanceStatus.PRESENT
        record.total_score = 100.0 # Override
    else:
        record = AttendanceRecord(
            student_id=student_id,
            session_id=session_id,
            status=AttendanceStatus.PRESENT,
            total_score=100.0,
            qr_score=100, gps_score=100, ble_score=100, device_score=100
        )
        db.add(record)
    
    # Mark in Redis to prevent future QR scanning duplicates
    redis_service.mark_attendance_processed(session_id, student_id)
    
    db.commit()
    return {"status": "success"}

@router.post("/end-session/{session_id}")
def end_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_faculty: User = Depends(get_current_faculty)
):
    session = db.query(AttendanceSession).filter(AttendanceSession.id == session_id).first()
    if not session: raise HTTPException(status_code=404, detail="Session not found")
    
    session.state = SessionState.TERMINATED
    
    # Auto-insert ABSENT for no-shows
    enrolled_student_ids = [e.student_id for e in db.query(Enrollment).filter(Enrollment.subject_id == session.subject_id).all()]
    marked_student_ids = [r.student_id for r in db.query(AttendanceRecord).filter(AttendanceRecord.session_id == session_id).all()]
    
    missing_ids = set(enrolled_student_ids) - set(marked_student_ids)
    for s_id in missing_ids:
        absent_record = AttendanceRecord(
            student_id=s_id,
            session_id=session_id,
            status=AttendanceStatus.ABSENT,
            total_score=0.0
        )
        db.add(absent_record)
    
    db.commit()
    return {"status": "session_ended"}

@router.get("/faculty-session-history", response_model=List[FacultySessionHistoryItem])
def get_faculty_session_history(
    db: Session = Depends(get_db),
    current_faculty: User = Depends(get_current_faculty)
):
    sessions = db.query(AttendanceSession).filter(
        AttendanceSession.faculty_id == current_faculty.id
    ).order_by(AttendanceSession.started_at.desc()).all()
    
    result = []
    for s in sessions:
        enrolled_count = db.query(Enrollment).filter(Enrollment.subject_id == s.subject_id).count()
        
        present_count = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == s.id,
            AttendanceRecord.status == AttendanceStatus.PRESENT
        ).count()
        
        absent_count = max(0, enrolled_count - present_count)
        
        duration_mins = 60
        if s.expires_at and s.started_at:
            delta = s.expires_at - s.started_at
            duration_mins = int(delta.total_seconds() / 60)
            
        classroom = db.query(Classroom).filter(Classroom.id == s.classroom_id).first()
        
        result.append(FacultySessionHistoryItem(
            id=s.id,
            subject_name=s.subject.name if s.subject else "Unknown",
            subject_code=s.subject.code if s.subject else "N/A",
            room_name=classroom.room_name if classroom else "Unknown",
            date=s.started_at.strftime("%Y-%m-%d") if s.started_at else "",
            start_time=s.started_at.strftime("%H:%M") if s.started_at else "",
            duration_mins=duration_mins,
            present_count=present_count,
            absent_count=absent_count,
            state=s.state.value
        ))
    return result

@router.get("/leave-requests", response_model=List[LeaveRequestResponse])
def get_hod_leave_requests(
    status: Optional[LeaveStatus] = None,
    db: Session = Depends(get_db),
    current_hod: User = Depends(get_current_hod)
):
    query = db.query(LeaveRequest)
    if status:
        query = query.filter(LeaveRequest.status == status)
    requests = query.order_by(LeaveRequest.created_at.desc()).all()
    
    for req in requests:
        req.student_name = req.student.name
    return requests

@router.post("/leave-requests/{request_id}/approve")
def approve_leave_request(
    request_id: int,
    db: Session = Depends(get_db),
    current_hod: User = Depends(get_current_hod)
):
    request = db.query(LeaveRequest).filter(LeaveRequest.id == request_id).first()
    if not request: raise HTTPException(status_code=404, detail="Request not found")
    
    request.status = LeaveStatus.APPROVED
    
    # BACKFILL ATTENDANCE
    sessions = db.query(AttendanceSession).filter(
        func.date(AttendanceSession.started_at) >= request.start_date,
        func.date(AttendanceSession.started_at) <= request.end_date
    ).all()
    
    for session in sessions:
        record = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session.id,
            AttendanceRecord.student_id == request.student_id
        ).first()
        
        if record:
            record.status = AttendanceStatus.PRESENT
            record.total_score = 100.0
        else:
            new_record = AttendanceRecord(
                student_id=request.student_id,
                session_id=session.id,
                status=AttendanceStatus.PRESENT,
                total_score=100.0
            )
            db.add(new_record)
            
    db.commit()
    return {"status": "approved", "backfilled_count": len(sessions)}

@router.post("/leave-requests/{request_id}/reject")
def reject_leave_request(
    request_id: int,
    db: Session = Depends(get_db),
    current_hod: User = Depends(get_current_hod)
):
    request = db.query(LeaveRequest).filter(LeaveRequest.id == request_id).first()
    if not request: raise HTTPException(status_code=404, detail="Request not found")
    
    request.status = LeaveStatus.REJECTED
    db.commit()
    return {"status": "rejected"}
