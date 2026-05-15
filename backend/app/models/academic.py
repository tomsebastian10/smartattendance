from sqlalchemy import Column, Integer, String, Enum, DateTime, ForeignKey, Float, JSON, Time, Date
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from ..database import Base

class LeaveType(str, enum.Enum):
    MEDICAL = "MEDICAL"
    ON_DUTY = "ON_DUTY"
    OTHER = "OTHER"

class LeaveStatus(str, enum.Enum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"

class Subject(Base):
    __tablename__ = "subjects"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    code = Column(String, unique=True, index=True, nullable=False)
    credits = Column(Integer, default=3)
    department = Column(String)

    enrollments = relationship("Enrollment", back_populates="subject")
    timetable_slots = relationship("TimetableSlot", back_populates="subject")
    sessions = relationship("AttendanceSession", back_populates="subject")

class Enrollment(Base):
    __tablename__ = "enrollments"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("users.id"))
    subject_id = Column(Integer, ForeignKey("subjects.id"))
    enrolled_at = Column(DateTime(timezone=True), server_default=func.now())

    student = relationship("User", back_populates="enrollments")
    subject = relationship("Subject", back_populates="enrollments")

class TimetableSlot(Base):
    __tablename__ = "timetable_slots"

    id = Column(Integer, primary_key=True, index=True)
    subject_id = Column(Integer, ForeignKey("subjects.id"))
    day_of_week = Column(Integer) # 0=Monday, 6=Sunday
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    classroom_id = Column(Integer, ForeignKey("classrooms.id"))

    subject = relationship("Subject", back_populates="timetable_slots")

class LeaveRequest(Base):
    __tablename__ = "leave_requests"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("users.id"))
    leave_type = Column(Enum(LeaveType), nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    reason = Column(String)
    status = Column(Enum(LeaveStatus), default=LeaveStatus.PENDING)
    document_url = Column(String) # URL to uploaded proof
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    student = relationship("User", back_populates="leave_requests")
