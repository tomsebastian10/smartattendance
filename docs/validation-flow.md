# Validation Flow & Confidence Scoring

This document outlines the logic used by the Backend Validation Engine to verify student attendance.

## Confidence-Based Scoring System

Attendance is not a binary check but a cumulative score. A student is marked present if their total score meets or exceeds the **Threshold of 80**.

| Component | Max Points | Condition | Description |
| :--- | :---: | :--- | :--- |
| **BLE Proximity** | 50 | RSSI >= -65dBm | Strong proximity to the teacher's beacon. |
| **BLE Proximity** | 30 | -85 < RSSI < -65 | Moderate proximity. |
| **GPS Geofence** | 20 | In Campus | Device is within the defined campus/building boundary. |
| **QR Validation** | 20 | Valid Token | The scanned QR token is active and matches the session. |
| **Trusted Device** | 10 | Primary Device | The device fingerprint matches the student's primary trusted device. |

**Success Threshold: 80+**

### Example Scenarios

1. **Ideal Case**: BLE Strong (50) + GPS Valid (20) + QR Valid (20) + Trusted (10) = **100** (Success)
2. **Weak Signal**: BLE Moderate (30) + GPS Valid (20) + QR Valid (20) + Trusted (10) = **80** (Success)
3. **Spoofing Attempt (No BLE)**: GPS Valid (20) + QR Valid (20) + Trusted (10) = **50** (Rejected)
4. **Untrusted Device**: BLE Strong (50) + GPS Valid (20) + QR Valid (20) = **90** (Success, but flagged for review)

## Detailed Component Logic

### 1. BLE (Classroom-Level)
- **Teacher Device**: Broadcasts a BLE packet containing `session_id`.
- **Student Device**: Scans for the `session_id`.
- **Adaptive RSSI**: The backend evaluates the RSSI score based on classroom-specific profiles if available.

### 2. GPS (Campus-Level)
- **Geofence**: A circular or polygonal boundary around the campus/building.
- **Validation**: `Distance(StudentLocation, ClassroomCenter) <= AllowedRadius`.
- **Note**: Used for coarse positioning to filter out remote "proxy" attempts.

### 3. Dynamic QR (Visual Proof)
- **TTL**: 15-20 seconds.
- **Payload**: Includes a one-time nonce and session ID.
- **Replay Protection**: Each QR token can only be used once per student.

### 4. Device Fingerprinting
- **Logic**: During registration, the student's hardware ID (e.g., IMEI hash, Android ID) is stored.
- **Enforcement**: Students cannot log in from multiple devices simultaneously to prevent account sharing.

## Fraud Detection Rules
- **Impossible Movement**: If a student marks attendance in two rooms that are geographically far apart within a short time.
- **Proxy Pattern**: If a single device attempts to mark attendance for multiple student IDs.
- **Static GPS**: If multiple students report the exact same latitude/longitude (indicator of GPS spoofing apps).
