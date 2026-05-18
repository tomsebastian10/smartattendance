import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/smartattendance")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)

def check_db():
    db = SessionLocal()
    try:
        from app.models.academic import Subject, Enrollment, TimetableSlot
        from app.models.user import User
        from app.models.attendance import AttendanceSession, AttendanceRecord, Classroom
        
        print("--- DATABASE DIAGNOSTIC ---")
        print(f"Total Users: {db.query(User).count()}")
        for u in db.query(User).all():
            print(f" - {u.email} ({u.role.value if hasattr(u.role, 'value') else u.role})")
            
        print(f"Total Classrooms: {db.query(Classroom).count()}")
        for c in db.query(Classroom).all():
            print(f" - Classroom ID {c.id}: {c.room_name}")
        print(f"Total Subjects: {db.query(Subject).count()}")
        for s in db.query(Subject).all():
            print(f" - Subject ID {s.id}: {s.code} ({s.name})")
            
        print(f"Total Enrollments: {db.query(Enrollment).count()}")
        print(f"Total Timetable Slots: {db.query(TimetableSlot).count()}")
        
        print(f"Total Attendance Sessions: {db.query(AttendanceSession).count()}")
        for session in db.query(AttendanceSession).all():
            print(f" - Session ID {session.id}: Subject {session.subject_id}, Faculty {session.faculty_id}, State {session.state}")
            
        print(f"Total Attendance Records: {db.query(AttendanceRecord).count()}")
        for record in db.query(AttendanceRecord).all():
            print(f" - Record: Student {record.student_id}, Session {record.session_id}, Status {record.status}")
            
    except Exception as e:
        print(f"Diagnostic error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    check_db()
