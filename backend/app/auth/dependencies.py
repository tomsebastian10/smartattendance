from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.orm import Session
from ..database import get_db
from ..models.user import User, UserRole
from .security import SECRET_KEY, ALGORITHM

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/v1/auth/login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            print("DEBUG: Email in token payload is None")
            raise credentials_exception
    except JWTError as e:
        print(f"DEBUG: JWT Error: {e}")
        raise credentials_exception
    
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        print(f"DEBUG: User not found in DB for email {email}")
        raise credentials_exception
    return user

def get_current_faculty(current_user: User = Depends(get_current_user)):
    print(f"DEBUG FACULTY CHECK: user={current_user.email}, role={current_user.role}, type={type(current_user.role)}")
    if current_user.role not in [UserRole.FACULTY, UserRole.ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Faculty access required"
        )
    return current_user

def get_current_hod(current_user: User = Depends(get_current_user)):
    print(f"DEBUG HOD CHECK: user={current_user.email}, role={current_user.role}")
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="HOD access required"
        )
    return current_user
