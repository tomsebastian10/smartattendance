import sys
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add the current directory to sys.path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from app.database import Base
from app.models.user import User, UserRole, Device
from app.models.attendance import AttendanceSession, AttendanceRecord, Classroom
from app.models.academic import Subject, Enrollment, TimetableSlot, LeaveRequest, LeaveType, LeaveStatus
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

        # 3. Seed Subject
        subject = db.query(Subject).filter_by(code="CS301").first()
        if not subject:
            subject = Subject(
                name="Cloud Computing",
                code="CS301",
                credits=4,
                department="Computer Science"
            )
            db.add(subject)
            db.flush()
        print(f"Subject {subject.name} is ready.")

        # 4. Seed Timetable Slot for NOW
        now = datetime.now()
        current_day = now.weekday()
        
        # Create a slot that spans 1 hour before and 1 hour after now
        # Use clean time without microseconds
        start_dt = now - timedelta(hours=1)
        end_dt = now + timedelta(hours=1)
        start_time = time(start_dt.hour, start_dt.minute)
        end_time = time(end_dt.hour, end_dt.minute)

        # Clear old slots for clean test
        db.query(TimetableSlot).delete()
        
        slot = TimetableSlot(
            subject_id=subject.id,
            day_of_week=current_day,
            start_time=start_time,
            end_time=end_time,
            classroom_id=classroom.id
        )
        db.add(slot)
        print(f"Scheduled {subject.code} for today (Day {current_day}) at {start_time} to {end_time}.")

        # 5. Seed Enrollment
        student = db.query(User).filter(User.role == UserRole.STUDENT).first()
        enrollment = db.query(Enrollment).filter_by(student_id=student.id, subject_id=subject.id).first()
        if not enrollment:
            enrollment = Enrollment(student_id=student.id, subject_id=subject.id)
            db.add(enrollment)

        # 6. Seed Leave Request
        existing_leave = db.query(LeaveRequest).first()
        if not existing_leave:
            leave = LeaveRequest(
                student_id=student.id,
                leave_type=LeaveType.MEDICAL,
                start_date=date.today(),
                end_date=date.today(),
                reason="Seeded medical leave for testing HOD dashboard.",
                status=LeaveStatus.PENDING
            )
            db.add(leave)
            print("Seeded test leave request.")
        
        db.commit()
        print("Database seeding completed successfully!")
        
    except Exception as e:
        db.rollback()
        print(f"Seeding failed: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_user()
