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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_users_campus_handle ON users(campus_handle);
CREATE INDEX IF NOT EXISTS idx_users_archetype ON users(archetype);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- 3. Scope Hierarchy Table (Institutions, Depts, Hostels, Clubs, Gates)
CREATE TABLE IF NOT EXISTS scopes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(64) UNIQUE NOT NULL, -- e.g. 'global', 'dept:cse', 'sec:cse-3a', 'hostel:block-a'
    name VARCHAR(255) NOT NULL,
    scope_type VARCHAR(64) NOT NULL,  -- 'global', 'department', 'section', 'hostel', 'club', 'facility'
    parent_scope_id UUID REFERENCES scopes(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_scopes_code ON scopes(code);

-- 4. Granular Permissions (Action:Resource)
CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(128) UNIQUE NOT NULL, -- 'attendance:mark', 'notice:publish', 'gatepass:approve'
    description TEXT,
    module VARCHAR(64) NOT NULL       -- 'academic', 'hostel', 'security', 'canteen'
);

-- 5. Roles (Bundle of Permissions)
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(64) UNIQUE NOT NULL, -- 'student_base', 'class_rep', 'hod', 'warden', 'canteen_cashier'
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Role-to-Permission Mapping
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- 7. Scoped User Role Assignments
CREATE TABLE IF NOT EXISTS user_role_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
    scope_id UUID REFERENCES scopes(id) ON DELETE CASCADE, -- NULL means Global / Campus-wide
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
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    admission_year INT NOT NULL,
    entry_type VARCHAR(16) NOT NULL, -- 'regular', 'lateral', 'transfer'
    program VARCHAR(64) NOT NULL,    -- 'btech', 'mtech', 'phd'
    current_semester INT DEFAULT 1,
    batch_year INT NOT NULL
);

-- Unified Employee Record (HR & Payroll anchor for both Faculty and Staff)
CREATE TABLE IF NOT EXISTS employee_records (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    joining_date DATE NOT NULL,
    employee_code VARCHAR(64) UNIQUE,
    employment_type VARCHAR(32) NOT NULL, -- 'permanent', 'contract', 'visiting'
    is_academic BOOLEAN DEFAULT FALSE,    -- Participates in teaching/research
    is_administrative BOOLEAN DEFAULT FALSE -- Participates in campus/unit administration
);

-- Academic Profile (Attached if employee has teaching/research duties)
CREATE TABLE IF NOT EXISTS academic_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    academic_rank VARCHAR(64) NOT NULL,   -- 'Assistant Professor', 'Associate Professor', 'Professor'
    cabin_location VARCHAR(128),
    google_scholar_id VARCHAR(64),
    research_areas TEXT[]
);

-- Department affiliations for academic staff
CREATE TABLE IF NOT EXISTS employee_department_affiliations (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    department_scope_id UUID REFERENCES scopes(id) ON DELETE CASCADE,
    is_primary BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, department_scope_id)
);

-- Administrative Profile (Attached if employee has administrative/operational duties)
CREATE TABLE IF NOT EXISTS administrative_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    primary_unit VARCHAR(64) NOT NULL,    -- 'registrar', 'library', 'security', 'it_center', 'examination'
    designation VARCHAR(64) NOT NULL,     -- 'Registrar', 'Chief Security Officer', 'Lab Incharge'
    office_location VARCHAR(128)
);

-- Contractor / External Profile
CREATE TABLE IF NOT EXISTS contractor_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(32) UNIQUE NOT NULL,      -- e.g. 'CS301'
    name VARCHAR(255) NOT NULL,            -- 'Operating Systems'
    department_scope_id UUID REFERENCES scopes(id) ON DELETE SET NULL,
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    scope_id UUID REFERENCES scopes(id) ON DELETE CASCADE, -- Target cohort/section (e.g. sec:cse-3a)
    instructor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    day_of_week INT NOT NULL,              -- 1 = Monday ... 7 = Sunday
    start_time VARCHAR(8) NOT NULL,        -- '09:00'
    end_time VARCHAR(8) NOT NULL,          -- '10:00'
    room_number VARCHAR(64) NOT NULL,      -- 'LH-201'
    slot_type VARCHAR(32) NOT NULL DEFAULT 'lecture', -- 'lecture', 'lab', 'tutorial'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_timetable_scope ON timetable_slots(scope_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_timetable_instructor ON timetable_slots(instructor_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_timetable_updated ON timetable_slots(updated_at);

-- 11. Attendance Sessions (A marked class instance)
CREATE TABLE IF NOT EXISTS attendance_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timetable_slot_id UUID REFERENCES timetable_slots(id) ON DELETE SET NULL,
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    scope_id UUID REFERENCES scopes(id) ON DELETE CASCADE,
    marked_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    session_date DATE NOT NULL,
    topic VARCHAR(255),
    is_finalized BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_scope_date ON attendance_sessions(scope_id, session_date);
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_updated ON attendance_sessions(updated_at);

-- 12. Attendance Student Records
CREATE TABLE IF NOT EXISTS attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES attendance_sessions(id) ON DELETE CASCADE,
    student_id UUID REFERENCES users(id) ON DELETE CASCADE,
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(64) NOT NULL,         -- 'academic', 'exam', 'urgent', 'event', 'hostel'
    publisher_id UUID REFERENCES users(id) ON DELETE SET NULL,
    target_scope_id UUID REFERENCES scopes(id) ON DELETE CASCADE, -- NULL = Campus-wide (Global)
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

