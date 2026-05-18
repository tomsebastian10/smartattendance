import sys
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add the current directory to sys.path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from app.database import Base
from app.models.user import User, UserRole, Device
from app.models.attendance import AttendanceSession, AttendanceRecord, Classroom, SessionState
from app.models.academic import Subject, Enrollment, TimetableSlot, LeaveRequest, LeaveType, LeaveStatus
from app.models.announcement import Announcement
from datetime import date, time, datetime, timedelta
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/smartattendance")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

from app.auth.security import get_password_hash

def seed_user():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        PASSWORD_HASH = get_password_hash("password123")
        # 1. Seed Users
        users = [
            {"email": "student@test.com", "name": "Test Student", "role": UserRole.STUDENT},
            {"email": "teacher@test.com", "name": "Test Faculty", "role": UserRole.FACULTY},
            {"email": "hod@test.com", "name": "Dr. Sarah Smith", "role": UserRole.ADMIN},
        ]

        for u_data in users:
            user = db.query(User).filter(User.email == u_data["email"]).first()
            if not user:
                user = User(
                    name=u_data["name"],
                    email=u_data["email"],
                    password_hash=PASSWORD_HASH,
                    role=u_data["role"]
                )
                db.add(user)
                db.flush()
            else:
                user.password_hash = PASSWORD_HASH
            print(f"User {u_data['email']} is ready.")

        # 2. Seed Classroom
        classroom = db.query(Classroom).filter_by(room_name="L-101").first()
        if not classroom:
            classroom = Classroom(
                room_name="L-101",
                building="Main Block",
                gps_lat=12.9716,
                gps_long=77.5946,
                gps_radius_meters=500
            )
            db.add(classroom)
            db.flush()
        print(f"Classroom {classroom.room_name} is ready.")

        # 3. Seed Subjects
        subjects_data = [
            {"code": "CS301", "name": "Cloud Computing", "credits": 4, "department": "Computer Science"},
            {"code": "CS302", "name": "Machine Learning", "credits": 4, "department": "Computer Science"},
            {"code": "CS303", "name": "Information Security", "credits": 3, "department": "Computer Science"},
            {"code": "CS304", "name": "Mobile Application Development", "credits": 4, "department": "Computer Science"},
        ]
        
        subjects = {}
        for s_data in subjects_data:
            subj = db.query(Subject).filter_by(code=s_data["code"]).first()
            if not subj:
                subj = Subject(
                    name=s_data["name"],
                    code=s_data["code"],
                    credits=s_data["credits"],
                    department=s_data["department"]
                )
                db.add(subj)
                db.flush()
            subjects[s_data["code"]] = subj
            print(f"Subject {subj.code}: {subj.name} is ready.")
            
        # 4. Seed Timetable Slots for ALL weekdays
        db.query(TimetableSlot).delete()
        
        # We will schedule:
        # Monday (0): CS302 from 09:00 to 11:00
        # Tuesday (1): CS303 from 11:00 to 13:00
        # Wednesday (2): CS304 from 14:00 to 16:00
        # Thursday (3): CS301 from 10:00 to 12:00
        # Friday (4): CS302 from 13:00 to 15:00
        # Saturday (5): CS303 from 09:00 to 11:00
        # Sunday (6): CS301 from 00:00 to 23:59 (Current test day slot)
        
        slots_data = [
            {"day": 0, "code": "CS302", "start": time(9, 0), "end": time(11, 0)},
            {"day": 1, "code": "CS303", "start": time(11, 0), "end": time(13, 0)},
            {"day": 2, "code": "CS304", "start": time(14, 0), "end": time(16, 0)},
            {"day": 3, "code": "CS301", "start": time(10, 0), "end": time(12, 0)},
            {"day": 4, "code": "CS302", "start": time(13, 0), "end": time(15, 0)},
            {"day": 5, "code": "CS303", "start": time(9, 0), "end": time(11, 0)},
            {"day": 6, "code": "CS301", "start": time(0, 0), "end": time(23, 59)},
        ]
        
        for slot_info in slots_data:
            s_obj = subjects[slot_info["code"]]
            slot = TimetableSlot(
                subject_id=s_obj.id,
                day_of_week=slot_info["day"],
                start_time=slot_info["start"],
                end_time=slot_info["end"],
                classroom_id=classroom.id
            )
            db.add(slot)
            print(f"Scheduled {s_obj.code} on Day {slot_info['day']} at {slot_info['start']} to {slot_info['end']}.")

        # 5. Seed Enrollments for ALL subjects
        student = db.query(User).filter(User.role == UserRole.STUDENT).first()
        for code, s_obj in subjects.items():
            enrollment = db.query(Enrollment).filter_by(student_id=student.id, subject_id=s_obj.id).first()
            if not enrollment:
                enrollment = Enrollment(student_id=student.id, subject_id=s_obj.id)
                db.add(enrollment)
            print(f"Enrolled student in {code}")

        # 6. Seed Leave Request
        db.query(LeaveRequest).delete()
        leave = LeaveRequest(
            student_id=student.id,
            leave_type=LeaveType.MEDICAL,
            start_date=date.today(),
            end_date=date.today(),
            reason="Seeded medical leave for testing HOD dashboard.",
            status=LeaveStatus.PENDING
        )
        db.add(leave)
        print("Seeded fresh test leave request.")

        # 7. Seed Past Attendance Sessions for History
        from app.models.attendance import AttendanceStatus
        
        # Clear old session data so we can re-seed cleanly
        db.query(AttendanceRecord).delete()
        db.query(AttendanceSession).delete()
        
        teacher = db.query(User).filter(User.email == "teacher@test.com").first()
        student = db.query(User).filter(User.email == "student@test.com").first()
        
        sessions_history = [
            {
                "days_ago": 2,
                "subject_id": subjects["CS301"].id,
                "present": True,
                "started_hour": 10,
            },
            {
                "days_ago": 1,
                "subject_id": subjects["CS301"].id,
                "present": False,
                "started_hour": 11,
            },
            {
                "days_ago": 0,
                "subject_id": subjects["CS301"].id,
                "present": True,
                "started_hour": 9,
            }
        ]
        
        for i, s_hist in enumerate(sessions_history):
            s_date = datetime.now() - timedelta(days=s_hist["days_ago"])
            started_at = datetime(s_date.year, s_date.month, s_date.day, s_hist["started_hour"], 0, 0)
            expires_at = started_at + timedelta(minutes=60)
            
            past_session = AttendanceSession(
                faculty_id=teacher.id,
                classroom_id=classroom.id,
                subject_id=s_hist["subject_id"],
                session_token=f"past_token_{i}",
                qr_secret=f"past_qr_{i}",
                ble_uuid=f"past_ble_{i}",
                state=SessionState.TERMINATED,
                started_at=started_at,
                expires_at=expires_at
            )
            db.add(past_session)
            db.flush()
            
            # Seed attendance record for student
            status = AttendanceStatus.PRESENT if s_hist["present"] else AttendanceStatus.ABSENT
            record = AttendanceRecord(
                student_id=student.id,
                session_id=past_session.id,
                status=status,
                total_score=50.0 if s_hist["present"] else 0.0
            )
            db.add(record)
        print("Seeded past sessions history for faculty.")
        
        db.commit()
        print("Database seeding completed successfully!")
        
    except Exception as e:
        db.rollback()
        print(f"Seeding failed: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_user()
