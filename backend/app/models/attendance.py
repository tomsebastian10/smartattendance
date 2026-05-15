from sqlalchemy import Column, Integer, String, Enum, DateTime, ForeignKey, Float, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from ..database import Base

class SessionState(str, enum.Enum):
    CREATED = "CREATED"
    ACTIVE = "ACTIVE"
    EXPIRED = "EXPIRED"
    TERMINATED = "TERMINATED"

class AttendanceStatus(str, enum.Enum):
    PRESENT = "PRESENT"
    LATE = "LATE"
    ABSENT = "ABSENT"
    FLAGGED = "FLAGGED"

class AttendanceSession(Base):
    __tablename__ = "attendance_sessions"

    id = Column(Integer, primary_key=True, index=True)
    faculty_id = Column(Integer, ForeignKey("users.id"))
    classroom_id = Column(Integer, ForeignKey("classrooms.id"))
    subject_id = Column(Integer, ForeignKey("subjects.id"))
    session_token = Column(String, unique=True, index=True, nullable=False)
    qr_secret = Column(String, nullable=False)
    ble_uuid = Column(String, nullable=False)
    state = Column(Enum(SessionState), default=SessionState.CREATED)
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)

    records = relationship("AttendanceRecord", back_populates="session")
    subject = relationship("Subject", back_populates="sessions")

class AttendanceRecord(Base):
    __tablename__ = "attendance_records"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("users.id"))
    session_id = Column(Integer, ForeignKey("attendance_sessions.id"))
    
    gps_lat = Column(Float)
    gps_long = Column(Float)
    rssi_strength = Column(Integer)
    
    gps_score = Column(Integer, default=0)
    ble_score = Column(Integer, default=0)
    qr_score = Column(Integer, default=0)
    device_score = Column(Integer, default=0)
    total_score = Column(Integer, default=0)
    
    status = Column(Enum(AttendanceStatus), default=AttendanceStatus.PRESENT)
    fraud_flags = Column(JSON)
    validation_snapshot = Column(JSON)
    
    timestamp = Column(DateTime(timezone=True), server_default=func.now())

    student = relationship("User", back_populates="attendance_records")
    session = relationship("AttendanceSession", back_populates="records")

class Classroom(Base):
    __tablename__ = "classrooms"

    id = Column(Integer, primary_key=True, index=True)
    room_name = Column(String, nullable=False)
    building = Column(String)
    gps_lat = Column(Float, nullable=False)
    gps_long = Column(Float, nullable=False)
    gps_radius_meters = Column(Integer, default=200)
    ble_profile = Column(JSON)
