from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base

class Announcement(Base):
    __tablename__ = "announcements"

    id = Column(Integer, primary_key=True, index=True)
    author_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String, nullable=False)
    body = Column(Text, nullable=False)
    image_url = Column(String, nullable=True) # URL path to the uploaded image
    target_subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=True) # If null, broadcast to all
    is_global = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    author = relationship("User")
    subject = relationship("Subject")
