# API Contracts

## Base URL: `/api/v1`

## 1. Authentication

### `POST /auth/register`
Registers a new user and captures the initial device fingerprint.
- **Request Body**:
  ```json
  {
    "name": "string",
    "email": "string",
    "role": "STUDENT | FACULTY",
    "device_hash": "string"
  }
  ```

### `POST /auth/login`
Authenticates user and returns a JWT. Validates device fingerprint for students.
- **Request Body**: `{"email": "string", "password": "string", "device_hash": "string"}`
- **Response**: `{"access_token": "string", "refresh_token": "string"}`

---

## 2. Attendance Sessions (Faculty Only)

### `POST /attendance/start-session`
Starts a new attendance session for a specific classroom.
- **Request Body**: `{"classroom_id": "int", "duration_mins": 60}`
- **Response**:
  ```json
  {
    "session_id": "string",
    "ble_uuid": "string",
    "qr_secret": "string",
    "expires_at": "datetime"
  }
  ```

### `GET /attendance/session/{session_id}/status`
Retrieves live stats for an active session.
- **Response**: `{"student_count": 120, "state": "ACTIVE"}`

---

## 3. Attendance Submission (Student Only)

### `POST /attendance/verify`
The core endpoint for marking attendance.
- **Request Body**:
  ```json
  {
    "session_id": "string",
    "qr_token": "string",
    "nonce": "string",
    "ble_data": {
      "rssi": -62,
      "teacher_uuid": "string"
    },
    "gps_data": {
      "lat": 12.9716,
      "long": 77.5946,
      "accuracy": 10.5
    }
  }
  ```
- **Response**:
  ```json
  {
    "status": "SUCCESS | REJECTED | PENDING_REVIEW",
    "score": 90,
    "breakdown": {
      "ble": 50,
      "gps": 20,
      "qr": 20,
      "device": 0
    }
  }
  ```

---

## 4. History & Reports

### `GET /attendance/history`
Returns historical attendance records for the authenticated user.
- **Query Params**: `limit`, `offset`, `start_date`, `end_date`
