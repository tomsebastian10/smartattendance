from pydantic import BaseModel
from typing import Optional, Dict
from datetime import datetime
from ..models.attendance import SessionState, AttendanceStatus

class GPSData(BaseModel):
    lat: float
    long: float
    accuracy: Optional[float] = None

class BLEData(BaseModel):
    rssi: int
    teacher_uuid: str

class SessionCreate(BaseModel):
    classroom_id: int
    subject_id: int
    duration_mins: int = 60
    lat: Optional[float] = None
    long: Optional[float] = None

class SessionResponse(BaseModel):
    id: int
    session_token: str
    qr_secret: str
    ble_uuid: str
    state: SessionState
    expires_at: datetime
    class Config:
        from_attributes = True

class AttendanceVerify(BaseModel):
    session_token: str
    qr_token: str
    gps_data: Optional[GPSData] = None
    ble_data: Optional[BLEData] = None

class AttendanceResult(BaseModel):
    status: AttendanceStatus
    score: int
    breakdown: Dict[str, int]
