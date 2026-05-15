# Sequence Diagrams

## 1. Full Attendance Flow
This diagram illustrates the interaction between the Teacher App, Student App, and Backend during a standard attendance verification.

```mermaid
sequenceDiagram
    participant T as Teacher App
    participant S as Student App
    participant B as FastAPI Backend
    participant R as Redis
    participant DB as PostgreSQL

    T->>B: POST /attendance/start-session
    B->>DB: Create Session Record
    B->>R: Store Session Secret & Nonce
    B-->>T: Return session_id, ble_uuid, qr_secret

    Note over T: Broadcasts BLE (ble_uuid)
    Note over T: Displays Dynamic QR (qr_token)

    S->>S: Scan QR Code
    S->>S: Scan BLE (Get RSSI)
    S->>S: Get GPS Location

    S->>B: POST /attendance/verify (qr_token, rssi, gps, device_hash)
    B->>R: Validate qr_token & nonce
    B->>R: Check rate limits
    B->>DB: Fetch classroom geofence
    B->>B: Run Confidence Scoring Engine
    B->>DB: Insert Attendance Record
    B-->>S: Return Result (Score + Status)
    
    B->>T: WebSocket Update (Live Count)
```

## 2. Dynamic QR Rotation
How the QR code updates without a backend hit for every student scan.

```mermaid
sequenceDiagram
    participant T as Teacher App
    participant S as Student App
    participant B as FastAPI Backend

    Note over T, B: Session Active
    loop Every 15-20 Seconds
        T->>T: Generate New Token (Secret + Timestamp)
        T->>B: Sync New Token/Nonce (Optional/Batch)
    end

    S->>T: Scan QR
    S->>B: Submit Token
    B->>B: HMAC Validation (Secret + Time Window)
    B-->>S: Validated
```

## 3. Device Fingerprinting & Auth
Preventing multiple devices for one account.

```mermaid
sequenceDiagram
    participant S as Student App
    participant B as FastAPI Backend
    participant DB as PostgreSQL

    S->>B: POST /auth/login (email, device_hash)
    B->>DB: Fetch User & Trusted Device
    alt hash matches
        B-->>S: JWT Access Token
    else hash mismatch
        B-->>S: 403 Forbidden (Unauthorized Device)
    end
```
