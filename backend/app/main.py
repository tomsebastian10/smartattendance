from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from .auth.router import router as auth_router
from .attendance.router import router as attendance_router
from .announcements.router import router as announcements_router
from .services.websocket_manager import manager
from fastapi.staticfiles import StaticFiles
import os

app = FastAPI(
    title="Smart Attendance System API",
    description="Multi-factor attendance validation using BLE, GPS, and Dynamic QR.",
    version="1.0.0"
)

# Ensure uploads directory exists
os.makedirs("uploads", exist_ok=True)

# Mount static files for uploads
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(auth_router, prefix="/api/v1")
app.include_router(attendance_router, prefix="/api/v1")
app.include_router(announcements_router, prefix="/api/v1")

@app.get("/")
async def root():
    return {"message": "Smart Attendance System API is running"}

@app.websocket("/ws/session/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    await manager.connect(websocket, session_id)
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket, session_id)

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
