# Smart Attendance System - Quick Start Guide

This project consists of a FastAPI backend and a Flutter mobile application.

## Prerequisites
- **Python 3.9+**
- **Flutter SDK**
- **PostgreSQL**
- **Redis** (Optional for local dev, but recommended)

---

## 1. Backend Setup (FastAPI)

1. **Navigate to backend directory**:
   ```powershell
   cd backend
   ```

2. **Create a virtual environment**:
   ```powershell
   python -m venv venv
   .\venv\Scripts\activate
   ```

3. **Install dependencies**:
   ```powershell
   pip install -r requirements.txt
   ```

4. **Environment Variables**:
   Create a `.env` file in the `backend/` directory:
   ```env
   DATABASE_URL=postgresql://postgres:postgres@localhost:5432/smartattendance
   REDIS_HOST=localhost
   REDIS_PORT=6379
   SECRET_KEY=your_secret_key_here
   ```

5. **Initialize Database**:
   Run the schema script against your local PostgreSQL instance:
   ```powershell
   psql -U postgres -d smartattendance -f ../database/schema.sql
   ```

6. **Run the server**:
   ```powershell
   uvicorn app.main:app --reload
   ```

---

## 2. Mobile App Setup (Flutter)

1. **Navigate to mobile directory**:
   ```powershell
   cd mobile
   ```

2. **Get dependencies**:
   ```powershell
   flutter pub get
   ```

3. **Configure API Endpoint**:
   Open `lib/utils/constants.dart` and update the `baseUrl` to your local IP or `10.0.2.2` (for Android Emulator).

4. **Run the app**:
   ```powershell
   flutter run
   ```

---

## 3. Testing the Flow
1. **Register/Login** via the Mobile App.
2. **Start a Session** (Faculty role required).
3. **Scan QR** from the Student Dashboard.
4. **Watch Live Updates** on the backend logs or via a WebSocket client at `ws://localhost:8000/ws/session/{id}`.

## Troubleshooting
- **Redis**: If you don't have Redis running, the app will log errors. You can modify `redis_service.py` to use a local dictionary for simple testing.
- **GPS**: Emulators might need manual location mocking to pass the geofence check.
