-- Campus Management Initial Schema: Users, Canonical Handles, and Scoped RBAC/ReBAC

-- 1. Atomic Sequence Tracking for Campus Handles
CREATE TABLE IF NOT EXISTS handle_sequences (
    prefix VARCHAR(128) PRIMARY KEY,
    last_val INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Atomic handle generator stored procedure
CREATE OR REPLACE FUNCTION generate_campus_handle(p_prefix TEXT)
RETURNS TEXT AS $$
DECLARE
    v_next_val INT;
BEGIN
    INSERT INTO handle_sequences (prefix, last_val, updated_at)
    VALUES (p_prefix, 1, NOW())
    ON CONFLICT (prefix)
    DO UPDATE SET last_val = handle_sequences.last_val + 1, updated_at = NOW()
    RETURNING last_val INTO v_next_val;

    RETURN p_prefix || '_' || v_next_val;
END;
$$ LANGUAGE plpgsql;

-- 2. Core User Identity Table
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    campus_handle VARCHAR(128) UNIQUE NOT NULL, -- e.g. harish_2025_l_btech_1, priya_2024_emp_1
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    personal_email VARCHAR(255),
    phone VARCHAR(32),
    archetype VARCHAR(32) NOT NULL, -- 'student', 'employee', 'external'
    
    -- Late-binding official IDs (nullable on day 1)
    admission_application_no VARCHAR(64),
    university_roll_no VARCHAR(64) UNIQUE,
    university_reg_no VARCHAR(64) UNIQUE,

    is_active BOOLEAN DEFAULT TRUE,
    status VARCHAR(32) DEFAULT 'active', -- 'active', 'graduated', 'discontinued', 'suspended', 'resigned', 'retired'
    password_hash VARCHAR(255),
    must_change_password BOOLEAN DEFAULT TRUE,
    discontinuation_reason TEXT,
    discontinued_at TIMESTAMPTZ,
    discontinued_by VARCHAR(128),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR(32);
ALTER TABLE users ADD COLUMN IF NOT EXISTS academic_name VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_users_campus_handle ON users(campus_handle);
CREATE INDEX IF NOT EXISTS idx_users_archetype ON users(archetype);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- 3. Scope Hierarchy Table (Institutions, Depts, Hostels, Clubs, Gates)
CREATE TABLE IF NOT EXISTS scopes (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(64) UNIQUE NOT NULL, -- e.g. 'global', 'dept:cse', 'sec:cse-3a', 'hostel:block-a'
    name VARCHAR(255) NOT NULL,
    scope_type VARCHAR(64) NOT NULL,  -- 'global', 'department', 'section', 'hostel', 'club', 'facility'
    parent_scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_scopes_code ON scopes(code);

-- 4. Granular Permissions (Action:Resource)
CREATE TABLE IF NOT EXISTS permissions (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(128) UNIQUE NOT NULL, -- 'attendance:mark', 'notice:publish', 'gatepass:approve'
    description TEXT,
    module VARCHAR(64) NOT NULL       -- 'academic', 'hostel', 'security', 'canteen'
);

-- 5. Roles (Bundle of Permissions)
CREATE TABLE IF NOT EXISTS roles (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(64) UNIQUE NOT NULL, -- 'student_base', 'class_rep', 'hod', 'warden', 'canteen_cashier'
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Role-to-Permission Mapping
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id VARCHAR(64) REFERENCES roles(id) ON DELETE CASCADE,
    permission_id VARCHAR(64) REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- 7. Scoped User Role Assignments
CREATE TABLE IF NOT EXISTS user_role_assignments (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    role_id VARCHAR(64) REFERENCES roles(id) ON DELETE CASCADE,
    scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE CASCADE, -- NULL means Global / Campus-wide
    valid_from TIMESTAMPTZ DEFAULT NOW(),
    valid_until TIMESTAMPTZ, -- Optional expiration for temporary positions
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_user_assignments ON user_role_assignments(user_id, is_active, is_deleted);

-- 8. Archetype Specific Profiles

-- Student Profile (Academic admission facts)
CREATE TABLE IF NOT EXISTS student_profiles (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    admission_year INT NOT NULL,
    entry_type VARCHAR(16) NOT NULL, -- 'regular', 'lateral', 'transfer'
    program VARCHAR(64) NOT NULL,    -- 'btech', 'mtech', 'phd'
    current_semester INT DEFAULT 1,
    batch_year INT NOT NULL
);

ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS academic_name VARCHAR(255);
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS academic_name_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS academic_name_source VARCHAR(64);
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS class_x_document_ref VARCHAR(255);

-- Unified Employee Record (HR & Payroll anchor for both Faculty and Staff)
CREATE TABLE IF NOT EXISTS employee_records (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    joining_date DATE NOT NULL,
    employee_code VARCHAR(64) UNIQUE,
    employment_type VARCHAR(32) NOT NULL, -- 'permanent', 'contract', 'visiting'
    is_academic BOOLEAN DEFAULT FALSE,    -- Participates in teaching/research
    is_administrative BOOLEAN DEFAULT FALSE -- Participates in campus/unit administration
);

-- Academic Profile (Attached if employee has teaching/research duties)
CREATE TABLE IF NOT EXISTS academic_profiles (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    academic_rank VARCHAR(64) NOT NULL,   -- 'Assistant Professor', 'Associate Professor', 'Professor'
    cabin_location VARCHAR(128),
    google_scholar_id VARCHAR(64),
    research_areas TEXT[]
);

-- Department affiliations for academic staff
CREATE TABLE IF NOT EXISTS employee_department_affiliations (
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    department_scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE CASCADE,
    is_primary BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, department_scope_id)
);

-- Administrative Profile (Attached if employee has administrative/operational duties)
CREATE TABLE IF NOT EXISTS administrative_profiles (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    primary_unit VARCHAR(64) NOT NULL,    -- 'registrar', 'library', 'security', 'it_center', 'examination'
    designation VARCHAR(64) NOT NULL,     -- 'Registrar', 'Chief Security Officer', 'Lab Incharge'
    office_location VARCHAR(128)
);

-- Contractor / External Profile
CREATE TABLE IF NOT EXISTS contractor_profiles (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    onboarding_year INT NOT NULL,
    vendor_organization VARCHAR(128) NOT NULL,
    service_type VARCHAR(64) NOT NULL,    -- 'canteen', 'mess', 'cleaning', 'transport'
    contract_expires_at TIMESTAMPTZ
);

-- ==========================================
-- PHASE 1: ACADEMICS, TIMETABLE & ATTENDANCE
-- ==========================================

-- 9. Courses / Subjects Catalog
CREATE TABLE IF NOT EXISTS courses (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(32) UNIQUE NOT NULL,      -- e.g. 'CS301'
    name VARCHAR(255) NOT NULL,            -- 'Operating Systems'
    department_scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE SET NULL,
    credits INT NOT NULL DEFAULT 3,
    semester INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_courses_code ON courses(code);
CREATE INDEX IF NOT EXISTS idx_courses_updated ON courses(updated_at);

-- 10. Timetable Slots
CREATE TABLE IF NOT EXISTS timetable_slots (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    course_id VARCHAR(64) REFERENCES courses(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE CASCADE,
    scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE CASCADE, -- Target cohort/section (e.g. sec:cse-3a)
    instructor_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    day_of_week INT NOT NULL,              -- 1 = Monday ... 7 = Sunday
    start_time VARCHAR(8) NOT NULL,        -- '09:00'
    end_time VARCHAR(8) NOT NULL,          -- '10:00'
    room_number VARCHAR(64) NOT NULL,      -- 'LH-201'
    slot_type VARCHAR(32) NOT NULL DEFAULT 'lecture', -- 'lecture', 'lab', 'tutorial'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

ALTER TABLE timetable_slots ADD COLUMN IF NOT EXISTS subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_timetable_scope ON timetable_slots(scope_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_timetable_instructor ON timetable_slots(instructor_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_timetable_subject ON timetable_slots(subject_id);
CREATE INDEX IF NOT EXISTS idx_timetable_updated ON timetable_slots(updated_at);

-- 11. Attendance Sessions (A marked class instance)
CREATE TABLE IF NOT EXISTS attendance_sessions (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    timetable_slot_id VARCHAR(64) REFERENCES timetable_slots(id) ON DELETE SET NULL,
    course_id VARCHAR(64) REFERENCES courses(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE CASCADE,
    scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE CASCADE,
    marked_by_user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    session_date DATE NOT NULL,
    topic VARCHAR(255),
    is_finalized BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

ALTER TABLE attendance_sessions ADD COLUMN IF NOT EXISTS subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_scope_date ON attendance_sessions(scope_id, session_date);
CREATE INDEX IF NOT EXISTS idx_attendance_subject ON attendance_sessions(subject_id);
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_updated ON attendance_sessions(updated_at);

-- 12. Attendance Student Records
CREATE TABLE IF NOT EXISTS attendance_records (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    session_id VARCHAR(64) REFERENCES attendance_sessions(id) ON DELETE CASCADE,
    student_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(16) NOT NULL,           -- 'present', 'absent', 'late', 'excused'
    remarks VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    CONSTRAINT uq_session_student UNIQUE(session_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_attendance_records_student ON attendance_records(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_records_session ON attendance_records(session_id);
CREATE INDEX IF NOT EXISTS idx_attendance_records_updated ON attendance_records(updated_at);

-- 13. Scoped Targeted Notices
CREATE TABLE IF NOT EXISTS notices (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(64) NOT NULL,         -- 'academic', 'exam', 'urgent', 'event', 'hostel'
    publisher_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    target_scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE CASCADE, -- NULL = Campus-wide (Global)
    priority VARCHAR(16) NOT NULL DEFAULT 'normal', -- 'normal', 'high', 'urgent'
    published_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_notices_scope ON notices(target_scope_id);
CREATE INDEX IF NOT EXISTS idx_notices_published ON notices(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_notices_updated ON notices(updated_at);


-- ========================================================
-- PHASE 2: DEPARTMENTS, PROGRAMS, SEMESTERS & SUBJECTS M:N
-- ========================================================

-- 14. Academic Departments
CREATE TABLE IF NOT EXISTS departments (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(32) UNIQUE NOT NULL,      -- e.g. 'CSE', 'ECE', 'MATH'
    name VARCHAR(255) NOT NULL,            -- e.g. 'Computer Science & Engineering'
    description TEXT,
    hod_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE SET NULL, -- Canonical organizational scope anchor
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

ALTER TABLE departments ADD COLUMN IF NOT EXISTS scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE SET NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_departments_scope_active ON departments(scope_id) WHERE scope_id IS NOT NULL AND is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_departments_code ON departments(code);

-- 15. Degree Programs (Overarching degree courses)
CREATE TABLE IF NOT EXISTS programs (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(32) UNIQUE NOT NULL,      -- e.g. 'BTECH-CSE', 'MBA'
    name VARCHAR(255) NOT NULL,            -- e.g. 'Bachelor of Technology in Computer Science'
    degree_level VARCHAR(32) NOT NULL,     -- 'undergraduate', 'postgraduate', 'doctoral'
    total_semesters INT NOT NULL DEFAULT 8,
    has_branches BOOLEAN DEFAULT FALSE,
    branch VARCHAR(255) DEFAULT '',
    duration_years INT DEFAULT 4,
    branches JSONB DEFAULT '[]'::jsonb,
    is_retired BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_programs_code ON programs(code);

-- 16. Subjects (Course modules)
CREATE TABLE IF NOT EXISTS subjects (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(32) UNIQUE NOT NULL,      -- e.g. 'CS301'
    name VARCHAR(255) NOT NULL,            -- e.g. 'Operating Systems'
    credits INT NOT NULL DEFAULT 4,
    odd_sem_code VARCHAR(32),
    even_sem_code VARCHAR(32),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_subjects_code ON subjects(code);

-- 17. Semesters (from a Program, e.g. B.Tech CSE Semester 5, Sec 3A)
CREATE TABLE IF NOT EXISTS semesters (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    program_id VARCHAR(64) REFERENCES programs(id) ON DELETE CASCADE,
    semester_number INT NOT NULL,
    academic_year VARCHAR(32) NOT NULL,    -- '2025-2026'
    section VARCHAR(16) NOT NULL,          -- '3A'
    display_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_semesters_program ON semesters(program_id);

-- 18. Department <-> Subject Many-to-Many
CREATE TABLE IF NOT EXISTS department_subjects (
    department_id VARCHAR(64) REFERENCES departments(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE CASCADE,
    PRIMARY KEY (department_id, subject_id)
);

-- 19. Department <-> Teacher Many-to-Many
CREATE TABLE IF NOT EXISTS department_teachers (
    department_id VARCHAR(64) REFERENCES departments(id) ON DELETE CASCADE,
    teacher_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (department_id, teacher_id)
);

-- 20. Department <-> Semester Many-to-Many
CREATE TABLE IF NOT EXISTS department_semesters (
    department_id VARCHAR(64) REFERENCES departments(id) ON DELETE CASCADE,
    semester_id VARCHAR(64) REFERENCES semesters(id) ON DELETE CASCADE,
    PRIMARY KEY (department_id, semester_id)
);

-- 21. Semester <-> Subject Many-to-Many (within the department)
CREATE TABLE IF NOT EXISTS semester_subjects (
    semester_id VARCHAR(64) REFERENCES semesters(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE CASCADE,
    PRIMARY KEY (semester_id, subject_id)
);

-- 22. Semester <-> Teacher Many-to-Many
CREATE TABLE IF NOT EXISTS semester_teachers (
    semester_id VARCHAR(64) REFERENCES semesters(id) ON DELETE CASCADE,
    teacher_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (semester_id, teacher_id)
);

-- Note: Students have a Many-to-One relationship with Semester (not directly to Department)
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS semester_id VARCHAR(64) REFERENCES semesters(id) ON DELETE SET NULL;

-- 23. Academic Sections (Cross-program cohorts/divisions within a semester)
CREATE TABLE IF NOT EXISTS sections (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name VARCHAR(32) NOT NULL,             -- e.g. 'Section B'
    semester_number INT NOT NULL,          -- e.g. 1, 2, 3, 5
    academic_year VARCHAR(32) NOT NULL,    -- '2025-2026'
    display_name VARCHAR(255) NOT NULL,    -- e.g. 'Semester 3 - Section B'
    department_id VARCHAR(64) REFERENCES departments(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_sections_term ON sections(semester_number, academic_year);

-- 24. Section <-> Program Many-to-Many (Section shared across multiple programs e.g. CSE, AI/ML, DS)
CREATE TABLE IF NOT EXISTS section_programs (
    section_id VARCHAR(64) REFERENCES sections(id) ON DELETE CASCADE,
    program_id VARCHAR(64) REFERENCES programs(id) ON DELETE CASCADE,
    PRIMARY KEY (section_id, program_id)
);

-- 25. Section <-> Subject Many-to-Many (with optional program specialization)
CREATE TABLE IF NOT EXISTS section_subjects (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    section_id VARCHAR(64) NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    program_id VARCHAR(64) REFERENCES programs(id) ON DELETE CASCADE, -- NULL = common core; non-NULL = program-specific
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_sec_sub_core ON section_subjects(section_id, subject_id) WHERE program_id IS NULL AND is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_sec_sub_prog ON section_subjects(section_id, subject_id, program_id) WHERE program_id IS NOT NULL AND is_deleted = FALSE;

-- 26. Section <-> Teacher Many-to-Many
CREATE TABLE IF NOT EXISTS section_teachers (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    section_id VARCHAR(64) NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
    teacher_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_sec_teacher_general ON section_teachers(section_id, teacher_id) WHERE subject_id IS NULL AND is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_sec_teacher_subject ON section_teachers(section_id, teacher_id, subject_id) WHERE subject_id IS NOT NULL AND is_deleted = FALSE;

-- Note: Students belong to their Degree Program and active Section cohort
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS section_id VARCHAR(64) REFERENCES sections(id) ON DELETE SET NULL;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS program_id VARCHAR(64) REFERENCES programs(id) ON DELETE SET NULL;

-- 27. Student Term Enrollments (Historical academic ledger tracking semester progression and section assignments)
CREATE TABLE IF NOT EXISTS student_term_enrollments (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    program_id VARCHAR(64) REFERENCES programs(id) ON DELETE SET NULL,
    semester_id VARCHAR(64) REFERENCES semesters(id) ON DELETE SET NULL,
    section_id VARCHAR(64) REFERENCES sections(id) ON DELETE SET NULL,
    academic_year VARCHAR(32) NOT NULL,    -- '2024-2025'
    semester_number INT NOT NULL CHECK (semester_number >= 1),
    status VARCHAR(32) NOT NULL DEFAULT 'enrolled' CHECK (status IN ('enrolled', 'promoted', 'completed', 'detained', 'withdrawn', 'dropped')),
    enrolled_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    UNIQUE (student_id, academic_year, semester_number)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_student ON student_term_enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_section ON student_term_enrollments(section_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_term ON student_term_enrollments(academic_year, semester_number);

-- 28. Syllabus Versions (Immutable audit trail of past and active curricula)
CREATE TABLE IF NOT EXISTS syllabus_versions (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE CASCADE,
    revision_code VARCHAR(64) NOT NULL,       -- e.g. 'Reg-2024', 'v1.0', 'Scheme 2021'
    effective_from_year VARCHAR(32) NOT NULL, -- e.g. '2024-2025'
    effective_to_year VARCHAR(32),            -- NULL if currently active
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    content TEXT NOT NULL,
    change_summary TEXT,
    approved_by VARCHAR(128),                 -- e.g. 'Academic Council / Board of Studies (BoS)'
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_syllabus_subject ON syllabus_versions(subject_id);
CREATE INDEX IF NOT EXISTS idx_syllabus_active ON syllabus_versions(subject_id, is_active);
CREATE UNIQUE INDEX IF NOT EXISTS uq_syllabus_active_per_subject ON syllabus_versions(subject_id) WHERE is_active = TRUE AND is_deleted = FALSE;

-- 29. Lab Batches (Sub-division of a section cohort for practical lab sessions e.g. Batch B1, Batch B2)
CREATE TABLE IF NOT EXISTS lab_batches (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    section_id VARCHAR(64) REFERENCES sections(id) ON DELETE CASCADE,
    name VARCHAR(64) NOT NULL,
    student_ids TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_lab_batches_section ON lab_batches(section_id);

-- 29b. Lab Batch Students (Normalized junction table replacing unconstrained TEXT[] array)
CREATE TABLE IF NOT EXISTS lab_batch_students (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    batch_id VARCHAR(64) NOT NULL REFERENCES lab_batches(id) ON DELETE CASCADE,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    UNIQUE (batch_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_lab_batch_students_batch ON lab_batch_students(batch_id);
CREATE INDEX IF NOT EXISTS idx_lab_batch_students_student ON lab_batch_students(student_id);

-- 30. Faculty Subject Allocations (Instructor assignment to Theory, Practical/Lab Batches, Tutorials with Weekly Contact Hours)
CREATE TABLE IF NOT EXISTS faculty_subject_allocations (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    section_id VARCHAR(64) REFERENCES sections(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE CASCADE,
    teacher_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    component_type VARCHAR(32) NOT NULL DEFAULT 'theory', -- 'theory', 'practical', 'tutorial'
    batch_id VARCHAR(64) REFERENCES lab_batches(id) ON DELETE CASCADE, -- NULL = whole section (theory); non-NULL = specific lab batch
    weekly_hours INT NOT NULL DEFAULT 3,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_faculty_alloc_sec ON faculty_subject_allocations(section_id);
CREATE INDEX IF NOT EXISTS idx_faculty_alloc_teacher ON faculty_subject_allocations(teacher_id);
CREATE INDEX IF NOT EXISTS idx_faculty_alloc_subject ON faculty_subject_allocations(subject_id);

-- 31. Hostel Rooms (Bounded room numbers 100 to 999 with 3 beds, 3 tables, 3 chairs, 2 tubelights, 2 fans, 3 lockers, and 3 occupants max)
CREATE TABLE IF NOT EXISTS hostel_rooms (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    room_number INT NOT NULL CHECK (room_number >= 100 AND room_number <= 999),
    block_name VARCHAR(64) NOT NULL DEFAULT 'Block 1',
    floor INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    UNIQUE (room_number, block_name)
);

CREATE INDEX IF NOT EXISTS idx_hostel_rooms_number ON hostel_rooms(room_number);

-- 32. Hostel Assets (Beds, tables, chairs, tubelights, fans, lockers with alphanumeric serial number <= 14 characters)
CREATE TABLE IF NOT EXISTS hostel_assets (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    room_id VARCHAR(64) REFERENCES hostel_rooms(id) ON DELETE CASCADE,
    room_number INT NOT NULL,
    asset_type VARCHAR(32) NOT NULL, -- 'bed', 'table', 'chair', 'tubelight', 'fan', 'locker'
    serial_number VARCHAR(14) NOT NULL UNIQUE,
    condition VARCHAR(32) NOT NULL DEFAULT 'operational',
    installed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_hostel_assets_room ON hostel_assets(room_number);
CREATE INDEX IF NOT EXISTS idx_hostel_assets_serial ON hostel_assets(serial_number);

-- 33. Hostel Occupants (Students allocated to a room, up to 3 residents max with discrete bed tracking)
CREATE TABLE IF NOT EXISTS hostel_occupants (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    room_id VARCHAR(64) NOT NULL REFERENCES hostel_rooms(id) ON DELETE CASCADE,
    room_number INT NOT NULL,
    bed_number INT CHECK (bed_number IS NULL OR (bed_number >= 1 AND bed_number <= 3)),
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    campus_handle VARCHAR(128) NOT NULL,
    name VARCHAR(128) NOT NULL,
    allotted_at TIMESTAMPTZ DEFAULT NOW(),
    vacated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

ALTER TABLE hostel_occupants ADD COLUMN IF NOT EXISTS bed_number INT;
ALTER TABLE hostel_occupants ADD COLUMN IF NOT EXISTS vacated_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_hostel_occupants_room ON hostel_occupants(room_number);
CREATE INDEX IF NOT EXISTS idx_hostel_occupants_room_id ON hostel_occupants(room_id);
CREATE INDEX IF NOT EXISTS idx_hostel_occupants_user ON hostel_occupants(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_occupant_active_bed ON hostel_occupants(room_id, bed_number) 
    WHERE is_deleted = FALSE AND vacated_at IS NULL AND bed_number IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_occupant_active_user ON hostel_occupants(user_id) 
    WHERE is_deleted = FALSE AND vacated_at IS NULL;

-- 34. Mess Meal Schedule (3 meals/day Mon-Sat, Sunday Brunch replaces Breakfast & Lunch)
CREATE TABLE IF NOT EXISTS mess_meals (
    id VARCHAR(64) PRIMARY KEY,
    day_of_week VARCHAR(16) NOT NULL,       -- 'monday', 'tuesday', ..., 'sunday'
    meal_type VARCHAR(16) NOT NULL,         -- 'breakfast', 'lunch', 'dinner', 'brunch'
    start_time VARCHAR(8) NOT NULL,         -- '07:30', '10:00', '12:30', '19:30'
    end_time VARCHAR(8) NOT NULL,           -- '09:30', '13:00', '14:30', '21:30'
    title VARCHAR(128) NOT NULL,
    menu_summary TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_mess_meals_day ON mess_meals(day_of_week);

-- 35. Mess Ratings and Feedback Messages (compulsory for very_poor, poor, average; optional for rest)
CREATE TABLE IF NOT EXISTS mess_ratings (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    meal_id VARCHAR(64) REFERENCES mess_meals(id) ON DELETE CASCADE,
    day_of_week VARCHAR(16) NOT NULL,
    meal_type VARCHAR(16) NOT NULL,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    user_name VARCHAR(128) NOT NULL,
    campus_handle VARCHAR(128) NOT NULL,
    rating VARCHAR(16) NOT NULL,            -- 'very_poor', 'poor', 'average', 'good', 'very_good', 'abstained'
    message TEXT,                           -- Compulsory when rating is very_poor, poor, average
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_mess_ratings_meal ON mess_ratings(meal_id);
CREATE INDEX IF NOT EXISTS idx_mess_ratings_rating ON mess_ratings(rating);
CREATE INDEX IF NOT EXISTS idx_mess_ratings_created ON mess_ratings(created_at);

-- ==============================================================================
-- PHASE 1 AUDIT REMEDIATION: INTEGRITY CONSTRAINTS & SOFT DELETION INDEXES
-- ==============================================================================

-- 36. Idempotent Migration for Existing Schemas (Composite PKs & Soft Deletion Uniqueness)
DO $$
BEGIN
    -- Fix section_subjects composite PK
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'section_subjects' AND constraint_type = 'PRIMARY KEY' AND constraint_name = 'section_subjects_pkey'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'section_subjects' AND column_name = 'id'
        ) THEN
            ALTER TABLE section_subjects DROP CONSTRAINT section_subjects_pkey;
            ALTER TABLE section_subjects ADD COLUMN id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text;
            ALTER TABLE section_subjects ALTER COLUMN program_id DROP NOT NULL;
            ALTER TABLE section_subjects ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
            ALTER TABLE section_subjects ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
            ALTER TABLE section_subjects ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
        END IF;
    END IF;

    -- Fix section_teachers composite PK
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'section_teachers' AND constraint_type = 'PRIMARY KEY' AND constraint_name = 'section_teachers_pkey'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'section_teachers' AND column_name = 'id'
        ) THEN
            ALTER TABLE section_teachers DROP CONSTRAINT section_teachers_pkey;
            ALTER TABLE section_teachers ADD COLUMN id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text;
            ALTER TABLE section_teachers ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
            ALTER TABLE section_teachers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
            ALTER TABLE section_teachers ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
        END IF;
    END IF;

    -- Drop unconditional unique constraints in favor of partial active unique indexes (DB-004)
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'programs_code_key') THEN
        ALTER TABLE programs DROP CONSTRAINT programs_code_key;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'departments_code_key') THEN
        ALTER TABLE departments DROP CONSTRAINT departments_code_key;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'subjects_code_key') THEN
        ALTER TABLE subjects DROP CONSTRAINT subjects_code_key;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'courses_code_key') THEN
        ALTER TABLE courses DROP CONSTRAINT courses_code_key;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'scopes_code_key') THEN
        ALTER TABLE scopes DROP CONSTRAINT scopes_code_key;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hostel_rooms_room_number_block_name_key') THEN
        ALTER TABLE hostel_rooms DROP CONSTRAINT hostel_rooms_room_number_block_name_key;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hostel_assets_serial_number_key') THEN
        ALTER TABLE hostel_assets DROP CONSTRAINT hostel_assets_serial_number_key;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hostel_occupants_room_number_user_id_key') THEN
        ALTER TABLE hostel_occupants DROP CONSTRAINT hostel_occupants_room_number_user_id_key;
    END IF;
END $$;

-- Active Partial Unique Indexes for Soft-Deletable Entities (DB-004)
CREATE UNIQUE INDEX IF NOT EXISTS uq_programs_code_active ON programs(code) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_departments_code_active ON departments(code) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_subjects_code_active ON subjects(code) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_courses_code_active ON courses(code) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_scopes_code_active ON scopes(code) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_rooms_number_block_active ON hostel_rooms(room_number, block_name) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_assets_serial_active ON hostel_assets(serial_number) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_occupants_room_user_active ON hostel_occupants(room_number, user_id) WHERE is_deleted = FALSE;

-- 37. Domain-Level Check Constraints (DB-010 & Integrity Rules)
DO $$
BEGIN
    -- users constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_users_archetype') THEN
        ALTER TABLE users ADD CONSTRAINT chk_users_archetype CHECK (archetype IN ('student', 'employee', 'external'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_users_status') THEN
        ALTER TABLE users ADD CONSTRAINT chk_users_status CHECK (status IN ('active', 'graduated', 'discontinued', 'suspended', 'resigned', 'retired'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_users_gender') THEN
        ALTER TABLE users ADD CONSTRAINT chk_users_gender CHECK (gender IS NULL OR gender IN ('male', 'female', 'other', 'prefer_not_to_say'));
    END IF;

    -- student_profiles constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_student_entry_type') THEN
        ALTER TABLE student_profiles ADD CONSTRAINT chk_student_entry_type CHECK (entry_type IN ('regular', 'lateral', 'transfer'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_student_semester') THEN
        ALTER TABLE student_profiles ADD CONSTRAINT chk_student_semester CHECK (current_semester >= 1);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_student_batch_year') THEN
        ALTER TABLE student_profiles ADD CONSTRAINT chk_student_batch_year CHECK (batch_year >= admission_year);
    END IF;

    -- employee_records constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_employee_type') THEN
        ALTER TABLE employee_records ADD CONSTRAINT chk_employee_type CHECK (employment_type IN ('permanent', 'contract', 'visiting'));
    END IF;

    -- programs constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_programs_degree_level') THEN
        ALTER TABLE programs ADD CONSTRAINT chk_programs_degree_level CHECK (degree_level IN ('undergraduate', 'postgraduate', 'doctoral'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_programs_total_semesters') THEN
        ALTER TABLE programs ADD CONSTRAINT chk_programs_total_semesters CHECK (total_semesters >= 1 AND total_semesters <= 16);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_programs_duration_years') THEN
        ALTER TABLE programs ADD CONSTRAINT chk_programs_duration_years CHECK (duration_years >= 1 AND duration_years <= 8);
    END IF;

    -- semesters constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_semesters_number') THEN
        ALTER TABLE semesters ADD CONSTRAINT chk_semesters_number CHECK (semester_number >= 1 AND semester_number <= 16);
    END IF;

    -- sections constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_sections_semester_number') THEN
        ALTER TABLE sections ADD CONSTRAINT chk_sections_semester_number CHECK (semester_number >= 1 AND semester_number <= 16);
    END IF;

    -- courses constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_courses_credits') THEN
        ALTER TABLE courses ADD CONSTRAINT chk_courses_credits CHECK (credits >= 0 AND credits <= 30);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_courses_semester') THEN
        ALTER TABLE courses ADD CONSTRAINT chk_courses_semester CHECK (semester >= 1 AND semester <= 16);
    END IF;

    -- subjects constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_subjects_credits') THEN
        ALTER TABLE subjects ADD CONSTRAINT chk_subjects_credits CHECK (credits >= 0 AND credits <= 30);
    END IF;

    -- timetable_slots constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_timetable_day') THEN
        ALTER TABLE timetable_slots ADD CONSTRAINT chk_timetable_day CHECK (day_of_week BETWEEN 1 AND 7);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_timetable_slot_type') THEN
        ALTER TABLE timetable_slots ADD CONSTRAINT chk_timetable_slot_type CHECK (slot_type IN ('lecture', 'lab', 'tutorial'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_timetable_times') THEN
        ALTER TABLE timetable_slots ADD CONSTRAINT chk_timetable_times CHECK (start_time < end_time);
    END IF;

    -- attendance_records constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_attendance_status') THEN
        ALTER TABLE attendance_records ADD CONSTRAINT chk_attendance_status CHECK (status IN ('present', 'absent', 'late', 'excused'));
    END IF;

    -- notices constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_notices_priority') THEN
        ALTER TABLE notices ADD CONSTRAINT chk_notices_priority CHECK (priority IN ('normal', 'high', 'urgent'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_notices_category') THEN
        ALTER TABLE notices ADD CONSTRAINT chk_notices_category CHECK (category IN ('academic', 'exam', 'urgent', 'event', 'hostel'));
    END IF;

    -- mess_meals constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_mess_meal_type') THEN
        ALTER TABLE mess_meals ADD CONSTRAINT chk_mess_meal_type CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'brunch'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_mess_meal_day') THEN
        ALTER TABLE mess_meals ADD CONSTRAINT chk_mess_meal_day CHECK (day_of_week IN ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_mess_meal_times') THEN
        ALTER TABLE mess_meals ADD CONSTRAINT chk_mess_meal_times CHECK (start_time < end_time);
    END IF;

    -- mess_ratings constraints (Mandatory feedback on poor ratings)
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_mess_rating_value') THEN
        ALTER TABLE mess_ratings ADD CONSTRAINT chk_mess_rating_value CHECK (rating IN ('very_poor', 'poor', 'average', 'good', 'very_good', 'abstained'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_mess_rating_feedback') THEN
        ALTER TABLE mess_ratings ADD CONSTRAINT chk_mess_rating_feedback CHECK (
            rating NOT IN ('very_poor', 'poor', 'average') OR (message IS NOT NULL AND length(trim(message)) > 0)
        );
    END IF;

    -- hostel_rooms constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_hostel_room_number') THEN
        ALTER TABLE hostel_rooms ADD CONSTRAINT chk_hostel_room_number CHECK (room_number >= 100 AND room_number <= 999);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_hostel_floor') THEN
        ALTER TABLE hostel_rooms ADD CONSTRAINT chk_hostel_floor CHECK (floor >= 0 AND floor <= 20);
    END IF;

    -- hostel_assets constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_hostel_asset_type') THEN
        ALTER TABLE hostel_assets ADD CONSTRAINT chk_hostel_asset_type CHECK (asset_type IN ('bed', 'table', 'chair', 'tubelight', 'fan', 'locker'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_hostel_asset_condition') THEN
        ALTER TABLE hostel_assets ADD CONSTRAINT chk_hostel_asset_condition CHECK (condition IN ('operational', 'damaged', 'under_repair', 'decommissioned'));
    END IF;
END $$;

-- 38. Cross-Table Archetype Validation Triggers (Section 3 Integrity Enforcement)

-- Trigger: Ensure attendance records are only logged for users with archetype = 'student'
CREATE OR REPLACE FUNCTION check_attendance_student_archetype()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM users WHERE id = NEW.student_id AND archetype = 'student'
    ) THEN
        RAISE EXCEPTION 'attendance can only be recorded for users with archetype student (user_id: %)', NEW.student_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_attendance_student ON attendance_records;
CREATE TRIGGER trg_check_attendance_student
    BEFORE INSERT OR UPDATE OF student_id ON attendance_records
    FOR EACH ROW EXECUTE FUNCTION check_attendance_student_archetype();

-- Trigger: Ensure faculty subject allocations are assigned to employees
CREATE OR REPLACE FUNCTION check_faculty_allocation_academic()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM users WHERE id = NEW.teacher_id AND archetype = 'employee'
    ) THEN
        RAISE EXCEPTION 'faculty subject allocation requires an employee (teacher_id: %)', NEW.teacher_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_faculty_allocation_academic ON faculty_subject_allocations;
CREATE TRIGGER trg_check_faculty_allocation_academic
    BEFORE INSERT OR UPDATE OF teacher_id ON faculty_subject_allocations
    FOR EACH ROW EXECUTE FUNCTION check_faculty_allocation_academic();
