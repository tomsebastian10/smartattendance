from app.database import SessionLocal, Base, engine
# Explicitly import ALL models to ensure they are registered with Base.metadata
from app.models.user import User, Device
from app.models.attendance import AttendanceSession, AttendanceRecord, Classroom
from app.models.academic import Subject, Enrollment, TimetableSlot
from datetime import time

def seed_academic():
    print("Known tables in metadata:", Base.metadata.tables.keys())
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # 1. Create Subjects
        subjects_data = [
            {"name": "Cloud Computing", "code": "CS301", "credits": 4, "department": "CSE"},
            {"name": "Machine Learning", "code": "CS302", "credits": 4, "department": "CSE"},
            {"name": "Network Security", "code": "CS303", "credits": 3, "department": "CSE"},
            {"name": "Mobile App Development", "code": "CS304", "credits": 3, "department": "CSE"},
        ]
        
        for s_data in subjects_data:
            if not db.query(Subject).filter(Subject.code == s_data["code"]).first():
                db.add(Subject(**s_data))
        
        db.commit()
        
        # 2. Enroll Student
        student = db.query(User).filter(User.email == "student@test.com").first()
        if student:
            all_subjects = db.query(Subject).all()
            for s in all_subjects:
                if not db.query(Enrollment).filter(Enrollment.student_id == student.id, Enrollment.subject_id == s.id).first():
                    db.add(Enrollment(student_id=student.id, subject_id=s.id))
        
        # 3. Create Timetable
        if student:
            cc = db.query(Subject).filter(Subject.code == "CS301").first()
            # Find a classroom or create a default one if none exists
            classroom = db.query(Classroom).first()
            if not classroom:
                classroom = Classroom(room_name="L-101", building="Block A", gps_lat=12.9716, gps_long=77.5946)
                db.add(classroom)
                db.commit()
                db.refresh(classroom)

            if cc and not db.query(TimetableSlot).filter(TimetableSlot.subject_id == cc.id).first():
                # Monday 9:00 - 10:00
                db.add(TimetableSlot(subject_id=cc.id, day_of_week=0, start_time=time(9, 0), end_time=time(10, 0), classroom_id=classroom.id))
                # Wednesday 11:00 - 12:00
                db.add(TimetableSlot(subject_id=cc.id, day_of_week=2, start_time=time(11, 0), end_time=time(12, 0), classroom_id=classroom.id))
        
        db.commit()
        print("Academic seed data created successfully!")
    finally:
        db.close()

if __name__ == "__main__":
    seed_academic()
