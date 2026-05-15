from sqlalchemy import Column, Integer, String, Enum, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from ..database import Base

class UserRole(str, enum.Enum):
    STUDENT = "STUDENT"
    FACULTY = "FACULTY"
    ADMIN = "ADMIN"

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    role = Column(Enum(UserRole), default=UserRole.STUDENT)
    department = Column(String)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    devices = relationship("Device", back_populates="owner")
    attendance_records = relationship("AttendanceRecord", back_populates="student")
    enrollments = relationship("Enrollment", back_populates="student")
    leave_requests = relationship("LeaveRequest", back_populates="student")

class Device(Base):
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    device_hash = Column(String, unique=True, index=True, nullable=False)
    device_name = Column(String)
    trusted = Column(Boolean, default=True)
    last_seen = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    owner = relationship("User", back_populates="devices")
