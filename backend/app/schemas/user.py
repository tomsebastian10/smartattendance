from pydantic import BaseModel, EmailStr
from typing import Optional
from ..models.user import UserRole

class UserBase(BaseModel):
    name: str
    email: EmailStr
    role: UserRole = UserRole.STUDENT
    department: Optional[str] = None

class UserCreate(UserBase):
    password: str
    device_hash: Optional[str] = None
    device_name: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str
    device_hash: str
    device_name: Optional[str] = None

class UserResponse(UserBase):
    id: int
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse

class UserUpdate(BaseModel):
    name: Optional[str] = None
    password: Optional[str] = None
