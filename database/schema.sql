-- PostgreSQL Schema for Smart Attendance System

-- Enum for User Roles
CREATE TYPE user_role AS ENUM ('STUDENT', 'FACULTY', 'ADMIN');

-- Enum for Session States
CREATE TYPE session_state AS ENUM ('CREATED', 'ACTIVE', 'EXPIRED', 'TERMINATED');

-- Enum for Attendance Status
CREATE TYPE attendance_status AS ENUM ('PRESENT', 'LATE', 'ABSENT', 'FLAGGED');

-- Users Table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'STUDENT',
    department VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Classrooms Table
CREATE TABLE classrooms (
    id SERIAL PRIMARY KEY,
    room_name VARCHAR(100) NOT NULL,
    building VARCHAR(100),
    gps_lat DOUBLE PRECISION NOT NULL,
    gps_long DOUBLE PRECISION NOT NULL,
    gps_radius_meters INTEGER DEFAULT 200, -- Geofence radius
    ble_profile JSONB -- Classroom-specific BLE RSSI profiles
);

-- Devices Table (Fingerprinting)
CREATE TABLE devices (
    id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    device_hash VARCHAR(255) UNIQUE NOT NULL,
    device_name VARCHAR(100),
    trusted BOOLEAN DEFAULT TRUE,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, device_hash)
);

-- Attendance Sessions Table
CREATE TABLE attendance_sessions (
    id SERIAL PRIMARY KEY,
    faculty_id INTEGER REFERENCES users(id),
    classroom_id INTEGER REFERENCES classrooms(id),
    session_token VARCHAR(255) UNIQUE NOT NULL,
    qr_secret VARCHAR(255) NOT NULL,
    ble_uuid UUID NOT NULL,
    state session_state DEFAULT 'CREATED',
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Attendance Records Table (Confidence-Based Scoring)
CREATE TABLE attendance_records (
    id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES users(id),
    session_id INTEGER REFERENCES attendance_sessions(id),
    
    -- Scoring Data
    gps_lat DOUBLE PRECISION,
    gps_long DOUBLE PRECISION,
    rssi_strength INTEGER,
    
    -- Confidence Scores
    gps_score INTEGER DEFAULT 0,
    ble_score INTEGER DEFAULT 0,
    qr_score INTEGER DEFAULT 0,
    device_score INTEGER DEFAULT 0,
    total_score INTEGER DEFAULT 0,
    
    status attendance_status DEFAULT 'PRESENT',
    validation_snapshot JSONB, -- Stores detailed metrics (distance, RSSI, TTL)
    fraud_flags JSONB, -- Stores specific flags like "IMPOSSIBLE_MOVEMENT"
    
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, session_id)
);

-- Attendance Attempts Table (Logging failures and proxy attempts)
CREATE TABLE attendance_attempts (
    id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES users(id),
    session_id INTEGER REFERENCES attendance_sessions(id),
    qr_token VARCHAR(255),
    error_message TEXT,
    validation_snapshot JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_attendance_student ON attendance_records(student_id);
CREATE INDEX idx_attendance_session ON attendance_records(session_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_sessions_state ON attendance_sessions(state);
