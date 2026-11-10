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

### 2.4 Onboard Contractor / Vendor Identity
Onboards third-party staff, issues security gate pass, and assigns zone access.

- **Method**: `POST`
- **Path**: `/api/v1/users/contractor`

**Request Body:**
```json
{
  "first_name": "Mukesh",
  "last_name": "Verma",
  "email": "mukesh.verma@sodexo.com",
  "personal_email": "m.verma@personal.com",
  "phone": "+91 98333 44556",
  "onboarding_year": 2025,
  "vendor_organization": "Sodexo Campus Dining",
  "service_type": "canteen",
  "gate_pass_id": "GP-2025-0891",
  "supervisor_name": "Anil Kapoor",
  "supervisor_phone": "+91 98222 11000",
  "permitted_scopes": ["gate:main", "building:canteen"]
}
```

**Response (HTTP 201 Created):**
```json
{
  "id": "usr_01hc1f...",
  "campus_handle": "mukesh_2025_ext_1",
  "full_name": "Mukesh Verma",
  "archetype": "external",
  "status": "active",
  "contractor_profile": {
    "vendor_organization": "Sodexo Campus Dining",
    "service_type": "canteen",
    "gate_pass_id": "GP-2025-0891"
  }
}
```

---

### 2.5 Self-Service User Profile Update
Updates personal contact details and emergency information for a user.

- **Method**: `POST`
- **Path**: `/api/v1/users/profile/update`

**Request Body:**
```json
{
  "user_id": "usr-harish_2025_l_btech_1",
  "personal_email": "harish.personal@example.com",
  "phone": "+91 98765 43210",
  "emergency_contact_name": "Suresh Kumar (Father)",
  "emergency_contact_phone": "+91 98765 00112",
  "blood_group": "O+",
  "address": "Room 204, Aryabhatta Hostel Block, Campus North"
}
```

**Response (HTTP 200 OK):**
```json
{
  "id": "usr-harish_2025_l_btech_1",
  "campus_handle": "harish_2025_l_btech_1",
  "first_name": "Harish",
  "last_name": "Kumar",
  "email": "harish_2025_l_btech_1@campus.edu",
  "personal_email": "harish.personal@example.com",
  "phone": "+91 98765 43210",
  "emergency_contact_name": "Suresh Kumar (Father)",
  "emergency_contact_phone": "+91 98765 00112",
  "blood_group": "O+",
  "address": "Room 204, Aryabhatta Hostel Block, Campus North",
  "archetype": "student",
  "status": "active"
}
```

---

### 2.6 Discontinue / Offboard User
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

---

## 5. Academic Departments & Program Hierarchies

Academic structures model Many-to-Many ($M:N$) department affiliations, academic degree programs, and curriculum cycles.

### 5.1 List Academic Departments
Retrieves all academic departments.

- **Method**: `GET`
- **Path**: `/api/v1/departments`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "dept_cse",
    "code": "CSE",
    "name": "Computer Science & Engineering",
    "description": "Department of Computer Science & Engineering",
    "hod_id": "usr_emp_hod_cse",
    "hod_name": "Dr. Ramesh Sharma",
    "created_at": "2026-11-01T00:00:00Z",
    "updated_at": "2026-11-01T00:00:00Z"
  }
]
```

---

### 5.2 Get Department Detail
Retrieves comprehensive details of a department including associated programs, faculty members, subjects, and sections.

- **Method**: `GET`
- **Path**: `/api/v1/departments?id=dept_cse`

**Response (HTTP 200 OK):**
```json
{
  "department": {
    "id": "dept_cse",
    "code": "CSE",
    "name": "Computer Science & Engineering",
    "hod_id": "usr_emp_hod_cse",
    "hod_name": "Dr. Ramesh Sharma"
  },
  "programs": [
    {
      "id": "prog_btech_cse",
      "code": "BTECH-CSE",
      "name": "Bachelor of Technology in Computer Science",
      "department_ids": ["dept_cse"],
      "total_semesters": 8
    }
  ],
  "teachers": [
    {
      "id": "usr_emp_hod_cse",
      "campus_handle": "ramesh_2020_emp_01",
      "first_name": "Ramesh",
      "last_name": "Sharma",
      "email": "ramesh.sharma@campus.edu"
    }
  ],
  "subjects": [],
  "sections": []
}
```

---

### 5.3 Create Academic Department
Provisions a new academic department with an optional Head of Department (HOD).

- **Method**: `POST`
- **Path**: `/api/v1/departments`

**Request Body:**
```json
{
  "code": "AI-DS",
  "name": "Artificial Intelligence & Data Science",
  "description": "Department of Artificial Intelligence and Data Science",
  "hod_id": "usr_emp_hod_cse"
}
```

**Response (HTTP 201 Created):**
```json
{
  "id": "dept_aids_uuid",
  "code": "AI-DS",
  "name": "Artificial Intelligence & Data Science",
  "description": "Department of Artificial Intelligence and Data Science",
  "hod_id": "usr_emp_hod_cse",
  "hod_name": "Dr. Ramesh Sharma",
  "created_at": "2026-11-06T10:00:00Z",
  "updated_at": "2026-11-06T10:00:00Z"
}
```

---

### 5.4 List Programs
Lists all degree programs offered across departments.

- **Method**: `GET`
- **Path**: `/api/v1/academics/programs`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "prog_bca",
    "code": "BCA",
    "name": "Bachelor of Computer Applications",
    "department_ids": ["dept_cse", "dept_it"],
    "total_semesters": 6,
    "created_at": "2026-11-01T00:00:00Z"
  }
]
```

---

### 5.5 List Semesters & Semester Detail
Lists academic semesters or retrieves detail with subjects and cohorts.

- **Method**: `GET`
- **Path**: `/api/v1/academics/semesters` (or `/api/v1/academics/semesters?id={semester_id}`)

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "sem_bca_s1",
    "program_id": "prog_bca",
    "semester_number": 1,
    "academic_year": "2026-2027",
    "term_type": "odd",
    "created_at": "2026-11-01T00:00:00Z"
  }
]
```

---

### 5.6 List Faculty Teachers
Retrieves active faculty teachers available for subject and lab allocations.

- **Method**: `GET`
- **Path**: `/api/v1/academics/teachers`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "usr_emp_hod_cse",
    "campus_handle": "ramesh_2020_emp_01",
    "first_name": "Ramesh",
    "last_name": "Sharma",
    "email": "ramesh.sharma@campus.edu",
    "archetype": "faculty"
  }
]
```

---

## 6. Cross-Program Sections & Cohort Mobility

Supports shared cross-program lecture sections (e.g., BCA and B.Sc. IT attending Calculus together), individual student section transfers, and cohort merges.

### 6.1 List & Inspect Sections
- **Method**: `GET`
- **Path**: `/api/v1/academics/sections` (or `?id={section_id}`)

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "sec_bca_1a",
    "name": "BCA-1A",
    "semester_id": "sem_bca_s1",
    "program_ids": ["prog_bca", "prog_bsc_it"],
    "capacity": 60,
    "is_shared": true,
    "enrolled_count": 45,
    "created_at": "2026-11-01T00:00:00Z"
  }
]
```

---

### 6.2 Create Cross-Program Section
- **Method**: `POST`
- **Path**: `/api/v1/academics/sections`

**Request Body:**
```json
{
  "name": "SHARED-MATH-1",
  "semester_id": "sem_bca_s1",
  "program_ids": ["prog_bca", "prog_bsc_it"],
  "capacity": 100,
  "is_shared": true
}
```

**Response (HTTP 201 Created):**
```json
{
  "id": "sec_shared_math_1",
  "name": "SHARED-MATH-1",
  "semester_id": "sem_bca_s1",
  "program_ids": ["prog_bca", "prog_bsc_it"],
  "capacity": 100,
  "is_shared": true,
  "enrolled_count": 0,
  "created_at": "2026-11-06T10:15:00Z"
}
```

---

### 6.3 Assign Student to Section
- **Method**: `POST`
- **Path**: `/api/v1/academics/sections/assign-student`

**Request Body:**
```json
{
  "student_id": "usr_stu_001",
  "section_id": "sec_bca_1a",
  "program_id": "prog_bca"
}
```

**Response (HTTP 200 OK):**
```json
{
  "success": true,
  "student_id": "usr_stu_001",
  "section_id": "sec_bca_1a",
  "program_id": "prog_bca"
}
```

---

### 6.4 Transfer Student Between Sections (Mobility)
Transfers an individual student from their current section to a destination section.

- **Method**: `POST`
- **Path**: `/api/v1/academics/sections/transfer-student`

**Request Body:**
```json
{
  "student_id": "usr_stu_001",
  "target_section_id": "sec_bca_1b"
}
```

**Response (HTTP 200 OK):**
```json
{
  "success": true,
  "student_id": "usr_stu_001",
  "target_section_id": "sec_bca_1b"
}
```

---

### 6.5 Merge Section Cohorts
Consolidates all enrolled students from a source section into a target section in a single atomic transaction.

- **Method**: `POST`
- **Path**: `/api/v1/academics/sections/merge`

**Request Body:**
```json
{
  "source_section_id": "sec_bca_1b",
  "target_section_id": "sec_bca_1a"
}
```

**Response (HTTP 200 OK):**
```json
{
  "success": true,
  "students_migrated": 28,
  "source_section_id": "sec_bca_1b",
  "target_section_id": "sec_bca_1a"
}
```

---

## 7. Subjects with Odd/Even Term Aliasing & Syllabus Audit Archive

Academic subjects model decoupled catalog codes where identical course contents bear different course codes across semester cycles (e.g., `BCA-102` in Odd Term vs. `BCA-202` in Even Term), accompanied by an immutable Board of Studies (BoS) syllabus revision audit trail.

### 7.1 List Subjects with Term Aliases
- **Method**: `GET`
- **Path**: `/api/v1/academics/subjects`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "subj_c_prog",
    "name": "Programming in C & Data Foundations",
    "description": "Core procedural programming and pointers",
    "default_code": "CS-101",
    "odd_semester_code": "BCA-102",
    "even_semester_code": "BCA-202",
    "credits": 4,
    "hours_per_week": 4,
    "current_syllabus_version_id": "syl_ver_01",
    "syllabus_content": "Unit 1: C Syntax, Variables, Types...\nUnit 2: Pointers & Dynamic Allocation...",
    "created_at": "2026-11-01T00:00:00Z",
    "updated_at": "2026-11-01T00:00:00Z"
  }
]
```

---

### 7.2 Create Subject with Odd/Even Aliasing & Initial Syllabus
- **Method**: `POST`
- **Path**: `/api/v1/academics/subjects`

**Request Body:**
```json
{
  "name": "Database Management Systems",
  "description": "Relational algebra, SQL, normal forms, and transaction ACID properties",
  "default_code": "CS-301",
  "odd_semester_code": "BCA-301",
  "even_semester_code": "BCA-401",
  "credits": 4,
  "hours_per_week": 4,
  "syllabus_content": "Unit 1: ER Modeling and Relational Calculus..."
}
```

**Response (HTTP 201 Created):**
```json
{
  "id": "subj_dbms_uuid",
  "name": "Database Management Systems",
  "default_code": "CS-301",
  "odd_semester_code": "BCA-301",
  "even_semester_code": "BCA-401",
  "credits": 4,
  "hours_per_week": 4,
  "current_syllabus_version_id": "syl_ver_dbms_v1",
  "syllabus_content": "Unit 1: ER Modeling and Relational Calculus...",
  "created_at": "2026-11-06T10:30:00Z",
  "updated_at": "2026-11-06T10:30:00Z"
}
```

---

### 7.3 Revise Subject Syllabus
Commits a new immutable syllabus version to the curriculum audit log.

- **Method**: `POST`
- **Path**: `/api/v1/academics/subjects/syllabus`

**Request Body:**
```json
{
  "subject_id": "subj_c_prog",
  "revision_code": "BOS-2026-REV3",
  "content": "Unit 1: Modern C17 Standards...\nUnit 2: Memory Safety & Address Sanitizers...",
  "approved_by": "Dr. Ramesh Sharma (BoS Chairperson)",
  "revision_notes": "Added memory sanitizers and updated standard libraries"
}
```

**Response (HTTP 201 Created):**
```json
{
  "id": "syl_ver_rev3_uuid",
  "subject_id": "subj_c_prog",
  "revision_code": "BOS-2026-REV3",
  "content": "Unit 1: Modern C17 Standards...\nUnit 2: Memory Safety & Address Sanitizers...",
  "effective_date": "2026-11-06T10:45:00Z",
  "approved_by": "Dr. Ramesh Sharma (BoS Chairperson)",
  "revision_notes": "Added memory sanitizers and updated standard libraries",
  "created_at": "2026-11-06T10:45:00Z"
}
```

---

### 7.4 Query Syllabus Immutable Audit Trail
Fetches the full historical revision ledger for academic accreditation audits.

- **Method**: `GET`
- **Path**: `/api/v1/academics/subjects/syllabus?subject_id=subj_c_prog`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "syl_ver_rev3_uuid",
    "subject_id": "subj_c_prog",
    "revision_code": "BOS-2026-REV3",
    "content": "Unit 1: Modern C17 Standards...",
    "effective_date": "2026-11-06T10:45:00Z",
    "approved_by": "Dr. Ramesh Sharma (BoS Chairperson)",
    "revision_notes": "Added memory sanitizers and updated standard libraries",
    "created_at": "2026-11-06T10:45:00Z"
  },
  {
    "id": "syl_ver_01",
    "subject_id": "subj_c_prog",
    "revision_code": "BOS-2024-INITIAL",
    "content": "Unit 1: C Syntax...",
    "effective_date": "2024-07-01T00:00:00Z",
    "approved_by": "Academic Council",
    "revision_notes": "Initial syllabus ratification",
    "created_at": "2024-07-01T00:00:00Z"
  }
]
```

---

## 8. Practical Lab Batches & Deterministic Auto-Partitioning

Sections are partitioned into practical lab batches ($B_1, B_2, \dots, B_N$) to accommodate laboratory capacity constraints.

### 8.1 List Lab Batches for Section
- **Method**: `GET`
- **Path**: `/api/v1/academics/sections/batches?section_id=sec_bca_1a`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "batch_bca_1a_b1",
    "section_id": "sec_bca_1a",
    "name": "B1",
    "capacity": 30,
    "student_count": 22,
    "student_ids": ["usr_stu_001", "usr_stu_002"],
    "created_at": "2026-11-01T00:00:00Z"
  }
]
```

---

### 8.2 Create Individual Lab Batch
- **Method**: `POST`
- **Path**: `/api/v1/academics/sections/batches`

**Request Body:**
```json
{
  "section_id": "sec_bca_1a",
  "name": "B3",
  "capacity": 25
}
```

**Response (HTTP 201 Created):**
```json
{
  "id": "batch_bca_1a_b3",
  "section_id": "sec_bca_1a",
  "name": "B3",
  "capacity": 25,
  "student_count": 0,
  "student_ids": [],
  "created_at": "2026-11-06T11:00:00Z"
}
```

---

### 8.3 Deterministic Auto-Partition Batches
Evenly partitions all enrolled students in a section across $N$ batches using a deterministic round-robin assignment based on student IDs / handles.

- **Method**: `POST`
- **Path**: `/api/v1/academics/sections/batches/auto-partition`

**Request Body:**
```json
{
  "section_id": "sec_bca_1a",
  "batch_count": 2,
  "batch_names": ["Batch 1 (A-M)", "Batch 2 (N-Z)"]
}
```

**Response (HTTP 201 Created):**
```json
[
  {
    "id": "batch_gen_1",
    "section_id": "sec_bca_1a",
    "name": "Batch 1 (A-M)",
    "capacity": 30,
    "student_count": 23,
    "student_ids": ["usr_stu_001", "usr_stu_003"],
    "created_at": "2026-11-06T11:05:00Z"
  },
  {
    "id": "batch_gen_2",
    "section_id": "sec_bca_1a",
    "name": "Batch 2 (N-Z)",
    "capacity": 30,
    "student_count": 22,
    "student_ids": ["usr_stu_002", "usr_stu_004"],
    "created_at": "2026-11-06T11:05:00Z"
  }
]
```

---

### 8.4 Assign Student to Lab Batch
- **Method**: `POST`
- **Path**: `/api/v1/academics/sections/batches/assign-student`

**Request Body:**
```json
{
  "batch_id": "batch_gen_1",
  "student_id": "usr_stu_005"
}
```

**Response (HTTP 200 OK):**
```json
{
  "success": true,
  "batch_id": "batch_gen_1",
  "student_id": "usr_stu_005"
}
```

---

## 9. Faculty Subject Allocations & Workload Tracking

Assigns instructors to theory lectures, practical labs, and tutorials while enforcing institutional workload policies (standard maximum 16 weekly contact hours).

### 9.1 List Section Allocations
- **Method**: `GET`
- **Path**: `/api/v1/academics/allocations?section_id=sec_bca_1a`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "alloc_001",
    "section_id": "sec_bca_1a",
    "subject_id": "subj_c_prog",
    "teacher_id": "usr_emp_hod_cse",
    "batch_id": null,
    "component_type": "theory",
    "weekly_hours": 4,
    "teacher_name": "Dr. Ramesh Sharma",
    "subject_name": "Programming in C & Data Foundations",
    "section_name": "BCA-1A",
    "batch_name": "",
    "created_at": "2026-11-01T00:00:00Z"
  }
]
```

---

### 9.2 Assign Faculty Subject Allocation
- **Method**: `POST`
- **Path**: `/api/v1/academics/allocations`

**Request Body:**
```json
{
  "section_id": "sec_bca_1a",
  "subject_id": "subj_c_prog",
  "teacher_id": "usr_emp_hod_cse",
  "batch_id": "batch_gen_1",
  "component_type": "practical",
  "weekly_hours": 2
}
```

**Response (HTTP 201 Created):**
```json
{
  "id": "alloc_002",
  "section_id": "sec_bca_1a",
  "subject_id": "subj_c_prog",
  "teacher_id": "usr_emp_hod_cse",
  "batch_id": "batch_gen_1",
  "component_type": "practical",
  "weekly_hours": 2,
  "teacher_name": "Dr. Ramesh Sharma",
  "subject_name": "Programming in C & Data Foundations",
  "section_name": "BCA-1A",
  "batch_name": "Batch 1 (A-M)",
  "created_at": "2026-11-06T11:15:00Z"
}
```

---

### 9.3 Remove Faculty Subject Allocation
- **Method**: `DELETE`
- **Path**: `/api/v1/academics/allocations?id=alloc_002`

**Response (HTTP 200 OK):**
```json
{
  "success": true,
  "id": "alloc_002"
}
```

---

### 9.4 Query Faculty Workload Summaries
Retrieves workload metrics across all faculty or for an individual teacher, flagging overloaded faculty whose commitments exceed 16 weekly hours.

- **Method**: `GET`
- **Path**: `/api/v1/academics/faculty/workload` (or `?teacher_id={teacher_id}`)

**Response (HTTP 200 OK):**
```json
[
  {
    "teacher_id": "usr_emp_hod_cse",
    "teacher_name": "Dr. Ramesh Sharma",
    "email": "ramesh.sharma@campus.edu",
    "total_weekly_hours": 14,
    "max_hours_limit": 16,
    "is_overloaded": false,
    "allocations": [
      {
        "id": "alloc_001",
        "subject_name": "Programming in C & Data Foundations",
        "section_name": "BCA-1A",
        "component_type": "theory",
        "weekly_hours": 4
      }
    ]
  }
]
```

---

## 10. Fee & Fine Subsystems

### 10.1 Fee Summary
- **Method**: `GET`
- **Path**: `/api/v1/fees/summary?student_id={student_id}`

**Response (HTTP 200 OK):**
```json
{
  "student_id": "usr-harish_2025_l_btech_1",
  "total_dues": 45000.0,
  "total_paid": 95000.0,
  "pending_invoices_count": 1,
  "unpaid_fines_count": 0,
  "unpaid_fines_amount": 0.0
}
```

---

### 10.2 List Fee Invoices
- **Method**: `GET`
- **Path**: `/api/v1/fees/invoices?student_id={student_id}&status={status}`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "inv-sem-2026-01",
    "invoice_number": "INV-2026-00129",
    "student_id": "usr-harish_2025_l_btech_1",
    "student_name": "Harish Kumar",
    "title": "Semester 4 Tuition & Lab Infrastructure",
    "total_amount": 45000.0,
    "paid_amount": 0.0,
    "due_amount": 45000.0,
    "status": "unpaid",
    "due_date": "2026-11-30T23:59:59Z"
  }
]
```

---

### 10.3 Process Invoice Payment
- **Method**: `POST`
- **Path**: `/api/v1/fees/pay`

**Request Body:**
```json
{
  "invoice_id": "inv-sem-2026-01",
  "student_id": "usr-harish_2025_l_btech_1",
  "amount": 45000.0,
  "payment_method": "upi"
}
```

**Response (HTTP 200 OK):**
```json
{
  "success": true,
  "payment": {
    "id": "pay-98124",
    "amount": 45000.0,
    "payment_method": "upi",
    "receipt_number": "RCP-2026-88192"
  },
  "receipt": {
    "receipt_number": "RCP-2026-88192",
    "amount": 45000.0,
    "status": "success"
  }
}
```

---

### 10.4 Download Invoice PDF
- **Method**: `GET`
- **Path**: `/api/v1/fees/invoices/pdf?id={id}`
- **Response**: `Content-Type: application/pdf` binary stream (PDF 1.4 specification).

---

### 10.5 Fine Management (List, Pay, Appeal, Waive)
- `GET /api/v1/fees/fines?student_id={id}&status={status}`: Query institutional disciplinary and library fines.
- `POST /api/v1/fees/fines/pay`: Settle fine amount via payment gateway or ledger adjustment.
- `POST /api/v1/fees/fines/appeal`: Submit official appeal justification.
- `POST /api/v1/fees/fines/waive`: Administrator waiver authorization.

---

## 11. Institutional Library Subsystem

### 11.1 Library Summary
- **Method**: `GET`
- **Path**: `/api/v1/library/summary?student_id={student_id}`

**Response (HTTP 200 OK):**
```json
{
  "student_id": "usr-harish_2025_l_btech_1",
  "active_loans_count": 1,
  "overdue_loans_count": 0,
  "max_borrow_quota": 4,
  "total_fines_accrued": 0.0,
  "books_borrowed_lifetime": 8
}
```

---

### 11.2 Physical Books Catalog
- **Method**: `GET`
- **Path**: `/api/v1/library/books?q={query}&category={category}`

**Response (HTTP 200 OK):**
```json
[
  {
    "id": "bk-os-01",
    "isbn": "978-1118063330",
    "title": "Operating System Concepts",
    "author": "Silberschatz, Galvin, Gagne",
    "total_copies": 5,
    "available_copies": 4,
    "shelf_location": "Rack A-1"
  }
]
```

---

### 11.3 Borrow Request & In-Charge Authorization
- **Submit Checkout Request**: `POST /api/v1/library/borrow`
  - Body: `{"student_id": "usr-1", "book_id": "bk-os-01"}`
  - Status becomes `pending_approval` (available catalog copy decrements).
- **In-Charge Approve Loan**: `POST /api/v1/library/borrow/approve`
  - Body: `{"borrow_id": "brw-01", "approved_by": "usr-admin", "approved_by_name": "Librarian"}`
  - Status transitions to `active` (activates 14-day checkout loan).
- **In-Charge Reject Request**: `POST /api/v1/library/borrow/reject`
  - Body: `{"borrow_id": "brw-01", "rejected_by": "usr-admin", "rejection_reason": "Allowance exceeded"}`
  - Status transitions to `rejected` (restores inventory copy).

---

### 11.4 Loan Renewal & Return Authorization
- **Submit Return Request**: `POST /api/v1/library/return`
  - Body: `{"borrow_id": "brw-01", "student_id": "usr-1"}`
  - Sets status to `pending_return` awaiting counter check-in inspection.
- **In-Charge Approve Return**: `POST /api/v1/library/return/approve`
  - Body: `{"borrow_id": "brw-01", "approved_by": "usr-admin", "approved_by_name": "Librarian"}`
  - Marks status `returned`, increments catalog available copies, and syncs any overdue fines.
- **In-Charge Reject Return**: `POST /api/v1/library/return/reject`
  - Body: `{"borrow_id": "brw-01", "rejected_by": "usr-admin", "rejection_reason": "Damaged cover"}`
- **Submit Renewal Request**: `POST /api/v1/library/renew`
  - Sets status to `pending_renewal`.
- **In-Charge Approve Renewal**: `POST /api/v1/library/renew/approve`
  - Extends loan deadline by +14 calendar days and increments renewal count.
- **In-Charge Reject Renewal**: `POST /api/v1/library/renew/reject`
  - Preserves original due date with rejection notes.

---

### 11.5 Infinite Concurrent E-Books
- **Method**: `GET`
- **Path**: `/api/v1/library/ebooks?q={query}&category={category}`
- Returns digital text assets supporting unlimited concurrent readers with built-in reader modals.

---

## 12. Complaints & Dispute System

### 12.1 Submit Formal Dispute or Grievance
- **Method**: `POST`
- **Path**: `/api/v1/complaints`

**Request Body (Dispute Mode):**
```json
{
  "title": "Dispute against Late Return Fine on Algorithms Textbook",
  "category": "academic",
  "description": "Book returned before deadline at circulation desk; counter check-in delayed.",
  "is_anonymous": false,
  "is_dispute": true,
  "dispute_type": "fine",
  "dispute_record_id": "fine-lib-01",
  "desired_resolution": "Full waiver of late fine"
}
```

**Response (HTTP 201 Created):**
```json
{
  "id": "cmp-98104",
  "ticket_number": "CMP-2026-00412",
  "title": "Dispute against Late Return Fine on Algorithms Textbook",
  "status": "open",
  "is_dispute": true,
  "dispute_type": "fine",
  "dispute_record_id": "fine-lib-01",
  "desired_resolution": "Full waiver of late fine",
  "created_at": "2026-11-10T09:30:00Z"
}
```

---

## 13. AKTU Sessional & Continuous Internal Evaluation

Under Dr. A.P.J. Abdul Kalam Technical University (AKTU) guidelines, affiliated colleges do not evaluate final university end-semester theory papers. The college conducts continuous internal evaluations (CT-1, CT-2, PUT, Teacher Assessment, and Lab Practicals) and submits frozen award lists to the university portal.

### 13.1 Fetch Student Sessional Records
- **Method**: `GET`
- **Path**: `/api/v1/sessional/records?student_id={id}&subject_code={code}&semester={sem}`
- **Response**: Array of `InternalAssessmentRecord` objects with full itemized breakdowns (CT1, CT2, PUT, TA, Sessional Scaled /20, Total Internal /30 for Theory; Lab Continuous /20, Viva /20, Lab Attendance /10, Total Internal /50 for Practical).

### 13.2 Update Faculty Marks
- **Method**: `POST`
- **Path**: `/api/v1/sessional/marks`
- **Request Body**:
```json
{
  "subject_code": "CS301",
  "student_id": "usr-harish_2025_l_btech_1",
  "ct1_score": 28.0,
  "ct2_score": 27.0,
  "put_score": 85.0,
  "ta_score": 9.0,
  "entered_by": "dr_arun_kumar"
}
```
- **Validation**: Enforces strict AKTU range bounds (CT1/CT2 <= 30, PUT <= 100, TA <= 10, Lab Continuous <= 20, Lab Viva <= 20, Lab Attendance <= 10). Rejects mutations if records have been officially frozen by HOD with `HTTP 409 Conflict`.

### 13.3 Freeze & Digitally Sign Marks (HOD / Exam Controller)
- **Method**: `POST`
- **Path**: `/api/v1/sessional/freeze`
- **Request Body**:
```json
{
  "subject_code": "CS301",
  "semester": 5,
  "frozen_by": "dr_arun_kumar",
  "remarks": "Approved and signed for AKTU portal upload"
}
```
- Generates a tamper-proof SHA-256 digital signature over all student marks in the cohort and locks the cohort.

### 13.4 Fetch Datesheet & Seating Layout
- **Schedule**: `GET /api/v1/sessional/schedule?semester={sem}&exam_type={CT-1|CT-2|PUT}`
- **Seating**: `GET /api/v1/sessional/seating?hall_number={hall}&exam_type={CT-1|CT-2|PUT}`

### 13.5 Fetch AKTU Award List & Class Analytics
- **Method**: `GET`
- **Path**: `/api/v1/sessional/award-list?subject_code={code}&semester={sem}`
- Returns class statistical KPIs: Average Score, Pass %, Top Score, Lowest Score, Deficit Count (<40%), HOD digital signature, and export-ready CSV records.

---

## 14. DigiLocker & APAAR / ABC ID Subsystem

Integrated with India's National Academic Depository (NAD) and Ministry of Electronics and Information Technology (MeitY) DigiLocker infrastructure.

### 14.1 Sync Credentials
- **Method**: `POST` or `GET /api/v1/user/profile?id={userId}`
- Returns verified student profile containing:
  - 12-Digit APAAR / Academic Bank of Credits (ABC) ID (e.g. `8912-3456-7890`)
  - DigiLocker verification badge with MeitY / NAD verification timestamp
  - Government educational and identity credentials:
    1. Secondary School Certificate (Class X - CBSE)
    2. Senior School Certificate (Class XII - CBSE PCM)
    3. Aadhaar Identity Verification (Masked: `XXXX-XXXX-4091`)
    4. APAAR / ABC Depository Certificate
    5. State Domicile Certificate
  - SHA-256 cryptographic hashes for each credential guaranteeing tamper-evidence.
