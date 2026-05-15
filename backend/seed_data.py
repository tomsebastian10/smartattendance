from app.database import SessionLocal, Base, engine
from app.models.user import User, UserRole, Device
from app.models.attendance import AttendanceSession, AttendanceRecord, Classroom
from app.auth.security import get_password_hash

def seed():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        password_hash = get_password_hash("password123")
        # Create/Update Teacher
        teacher = db.query(User).filter(User.email == "teacher@test.com").first()
        if not teacher:
            db.add(User(name="Test Teacher", email="teacher@test.com", password_hash=password_hash, role=UserRole.FACULTY))
        else:
            teacher.password_hash = password_hash
        
        # Create/Update Student
        student = db.query(User).filter(User.email == "student@test.com").first()
        if not student:
            db.add(User(name="Test Student", email="student@test.com", password_hash=password_hash, role=UserRole.STUDENT))
        else:
            student.password_hash = password_hash
        
        # Create Classroom
        if not db.query(Classroom).filter(Classroom.room_name == "CS301").first():
            db.add(Classroom(room_name="CS301", building="Science Block", gps_lat=0.0, gps_long=0.0, gps_radius_meters=10000))
        
        db.commit()
        print("Seed data created successfully!")
    finally:
        db.close()

if __name__ == "__main__":
    seed()
