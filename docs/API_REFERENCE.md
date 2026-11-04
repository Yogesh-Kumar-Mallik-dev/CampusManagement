# REST API Reference

The CampusManagement backend serves RESTful JSON endpoints over HTTP/1.1 (and HTTP/2) on port `8080`.

- **Base URL**: `http://localhost:8080` (or `https://api.campus.institution.edu`)
- **Default Content-Type**: `application/json`
- **Authentication**: Bearer Token or canonical campus handle session header.

---

## 1. Authentication & System Health

### 1.1 Institutional Sign In
Authenticates pre-provisioned identities (zero public registration).

- **Method**: `POST`
- **Path**: `/api/v1/auth/login`

**Request Body:**
```json
{
  "handle": "harish_2025_l_btech_1",
  "password": "Password123!"
}
```

**Response (HTTP 200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "usr_01ha8c...",
    "campus_handle": "harish_2025_l_btech_1",
    "full_name": "Harish Kumar",
    "email": "harish@campus.institution.edu",
    "archetype": "student",
    "status": "active",
    "roles": ["student"],
    "scopes": ["sec:cse-3a", "dept:cse", "campus:main"]
  }
}
```

---

### 1.2 Health & Cache Status
Checks server health and Redis cache readiness.

- **Method**: `GET`
- **Path**: `/api/health`

**Response (HTTP 200 OK):**
```json
{
  "status": "ok",
  "timestamp": "2026-11-04T09:15:00Z",
  "cache_ready": true
}
```

---

## 2. Identity Management & Scoped RBAC

### 2.1 List Campus Identities
- **Method**: `GET`
- **Path**: `/api/v1/users?archetype=student&status=active&search=harish`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "usr_01ha8c...",
    "campus_handle": "harish_2025_l_btech_1",
    "full_name": "Harish Kumar",
    "email": "harish@campus.institution.edu",
    "archetype": "student",
    "status": "active",
    "roles": ["student"],
    "created_at": "2025-08-01T08:00:00Z"
  }
]
```

---

### 2.2 Onboard Student Identity
Admits a student and deterministically mints their canonical handle.

- **Method**: `POST`
- **Path**: `/api/v1/users/student`

**Request Body:**
```json
{
  "full_name": "Ananya Roy",
  "email": "ananya.roy@campus.institution.edu",
  "phone": "+919876543210",
  "admission_year": 2025,
  "entry_type": "r",
  "program": "btech",
  "department": "cse",
  "section": "cse-1a"
}
```

**Response (HTTP 201 Created):**
```json
{
  "id": "usr_01hb9d...",
  "campus_handle": "ananya_2025_r_btech_1",
  "full_name": "Ananya Roy",
  "archetype": "student",
  "status": "active"
}
```

---

### 2.3 Onboard Employee Identity
Provisions faculty or administrative staff with unified handle schema.

- **Method**: `POST`
- **Path**: `/api/v1/users/employee`

**Request Body:**
```json
{
  "full_name": "Dr. Ramesh Sharma",
  "email": "ramesh.sharma@campus.institution.edu",
  "phone": "+919123456789",
  "joining_year": 2025,
  "department": "cse",
  "designation": "Associate Professor",
  "initial_role": "faculty",
  "initial_scope": "dept:cse"
}
```

**Response (HTTP 201 Created):**
```json
{
  "id": "usr_01hb9e...",
  "campus_handle": "dr_ramesh_sharma_2025_emp_1",
  "full_name": "Dr. Ramesh Sharma",
  "archetype": "employee",
  "status": "active"
}
```

---

### 2.4 Discontinue / Offboard User
Transitions user lifecycle to discontinued and revokes access.

- **Method**: `POST`
- **Path**: `/api/v1/users/discontinue`

**Request Body:**
```json
{
  "user_id": "usr_01hb9e...",
  "reason": "Graduated / Completed degree requirements"
}
```

**Response (HTTP 200 OK):**
```json
{
  "success": true,
  "user_id": "usr_01hb9e...",
  "status": "discontinued"
}
```

---

### 2.5 Scoped Permission Check
Evaluates whether a user can execute an action on a target scope.

- **Method**: `GET`
- **Path**: `/api/v1/permissions/check?user_id=usr_01hb9e...&permission=attendance:record&scope=sec:cse-3a`

**Response (HTTP 200 OK):**
```json
{
  "allowed": true,
  "matched_scope": "dept:cse",
  "granted_by_role": "faculty"
}
```

---

## 3. Optical Data Transfer Attendance

### 3.1 Start Optical Broadcast Session
Initiates an optical lecture session with rolling HMAC session secret.

- **Method**: `POST`
- **Path**: `/api/v1/attendance/optical/start`

**Request Body:**
```json
{
  "course_id": "CS301",
  "course_code": "CS301",
  "course_name": "Operating Systems",
  "scope_code": "sec:cse-3a",
  "room_number": "LH-101",
  "marked_by_user_id": "usr_dr_sharma",
  "marked_by_name": "Dr. Sharma",
  "refresh_interval_ms": 1500
}
```

**Response (HTTP 201 Created):**
```json
{
  "id": "opt_c74d6f83b19e",
  "course_id": "CS301",
  "course_code": "CS301",
  "course_name": "Operating Systems",
  "room_number": "LH-101",
  "session_secret": "9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c",
  "refresh_interval_ms": 1500,
  "started_at": "2026-11-04T09:00:00Z",
  "expires_at": "2026-11-04T10:00:00Z",
  "is_active": true,
  "verified_records": []
}
```

---

### 3.2 Verify Student Optical Frame Scan
Verifies a live scanned rolling QR code packet from a student device.

- **Method**: `POST`
- **Path**: `/api/v1/attendance/optical/verify`

**Request Body:**
```json
{
  "session_id": "opt_c74d6f83b19e",
  "payload": "CPOS:OPT:eyJ0IjoiT1BUIiwic2lkIjoib3B0X2M3NGQ2ZjgzYjE5ZSIsImNjIjoiQ1MzMDEiLCJjbiI6Ik9wZXJhdGluZyBTeXN0ZW1zIiwicm0iOiJMSC0xMDEiLCJzZXEiOjQyLCJ0cyI6MTczMDcwNzgwMCwibmMiOiJlM2IwYzQ0MiIsInNpZyI6ImE0Zjg5ZDIwYzE1ZThiNGEifQ",
  "student_id": "usr_harish_kumar",
  "student_name": "Harish Kumar",
  "campus_handle": "harish_2025_l_btech_1"
}
```

**Response (HTTP 200 OK):**
```json
{
  "verified": true,
  "message": "Optical signature verified and attendance confirmed.",
  "session_id": "opt_c74d6f83b19e",
  "course_code": "CS301",
  "course_name": "Operating Systems",
  "student_name": "Harish Kumar",
  "campus_handle": "harish_2025_l_btech_1",
  "sequence": 42,
  "recorded_at": "2026-11-04T09:10:02Z"
}
```

**Error Responses:**
- `HTTP 400 Bad Request`: `"Expired optical frame (age: 8s, max: 6s). Students must scan directly from podium display."`
- `HTTP 401 Unauthorized`: `"Invalid cryptographic signature for frame sequence."`

---

### 3.3 Live Optical Session Roster Feed
Returns the real-time list of verified students during active optical broadcast.

- **Method**: `GET`
- **Path**: `/api/v1/attendance/optical/roster?session_id=opt_c74d6f83b19e`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "rec_01",
    "session_id": "opt_c74d6f83b19e",
    "student_id": "usr_harish_kumar",
    "student_name": "Harish Kumar",
    "campus_handle": "harish_2025_l_btech_1",
    "status": "present",
    "remarks": "OPTICAL_FRAME_#42"
  }
]
```

---

### 3.4 Conclude Optical Session
Closes the broadcast, invalidates the session secret, and saves final roster.

- **Method**: `POST`
- **Path**: `/api/v1/attendance/optical/end`

**Request Body:**
```json
{
  "session_id": "opt_c74d6f83b19e"
}
```

**Response (HTTP 200 OK):**
```json
{
  "success": true,
  "session_id": "opt_c74d6f83b19e",
  "verified_count": 58,
  "status": "finalized"
}
```

---

## 4. Academics, Schedules & Sync

### 4.1 Query Timetable by Scope
Returns weekly schedule slots for a class cohort or room.

- **Method**: `GET`
- **Path**: `/api/v1/academics/timetable?scope=sec:cse-3a`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "slot_01",
    "course_id": "CS301",
    "course_code": "CS301",
    "course_name": "Operating Systems",
    "scope_code": "sec:cse-3a",
    "instructor_name": "Dr. Sharma",
    "day_of_week": 1,
    "start_time": "09:00",
    "end_time": "10:00",
    "room_number": "LH-101",
    "slot_type": "lecture"
  }
]
```

---

### 4.2 Offline Delta Sync
Fetches incremental changes since the client's last sync checkpoint.

- **Method**: `GET`
- **Path**: `/api/v1/sync?since=2026-11-01T00:00:00Z`

**Response (HTTP 200 OK):**
```json
{
  "server_time": "2026-11-04T09:15:00Z",
  "courses": [],
  "timetable_slots": [],
  "attendance_sessions": [],
  "attendance_records": [],
  "notices": []
}
```
