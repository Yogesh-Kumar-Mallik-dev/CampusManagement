-- ==============================================================================
-- CampusManagement Canonical Relational Database Schema
-- Normalized 3NF Architecture: Identity, RBAC, Academics, Hostel, Mess & CIE
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. EXTENSIONS & COMMON FUNCTIONS
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE OR REPLACE FUNCTION set_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- 2. ATOMIC SEQUENCE TRACKING FOR CAMPUS HANDLES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS handle_sequences (
    prefix VARCHAR(128) PRIMARY KEY,
    last_val INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

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

-- ------------------------------------------------------------------------------
-- 3. CORE USER IDENTITY & SECURITY
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    campus_handle VARCHAR(128) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    personal_email VARCHAR(255),
    phone VARCHAR(32),
    archetype VARCHAR(32) NOT NULL CHECK (archetype IN ('student', 'employee', 'external')),
    gender VARCHAR(32) CHECK (gender IS NULL OR gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
    academic_name VARCHAR(255),
    emergency_contact_name VARCHAR(128),
    emergency_contact_phone VARCHAR(32),
    blood_group VARCHAR(8),
    address TEXT,
    
    -- Official University Identifiers
    admission_application_no VARCHAR(64),
    university_roll_no VARCHAR(64),
    university_reg_no VARCHAR(64),

    -- Authentication, First-Login & Account Recovery State
    password_hash VARCHAR(255),
    must_change_password BOOLEAN DEFAULT TRUE,
    is_first_login BOOLEAN DEFAULT TRUE,
    security_question VARCHAR(255),
    security_answer_hash VARCHAR(255),
    whatsapp_phone VARCHAR(32),
    is_active BOOLEAN DEFAULT TRUE,
    status VARCHAR(32) DEFAULT 'active' CHECK (status IN ('active', 'graduated', 'discontinued', 'suspended', 'resigned', 'retired')),
    discontinuation_reason TEXT,
    discontinued_at TIMESTAMPTZ,
    discontinued_by VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_campus_handle ON users(campus_handle) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_email ON users(email) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_roll_no ON users(university_roll_no) WHERE university_roll_no IS NOT NULL AND is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_reg_no ON users(university_reg_no) WHERE university_reg_no IS NOT NULL AND is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_users_archetype ON users(archetype);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_whatsapp ON users(whatsapp_phone) WHERE whatsapp_phone IS NOT NULL AND is_deleted = FALSE;

-- Password Reset Helpdesk Escalations (Channel B)
CREATE TABLE IF NOT EXISTS password_reset_escalations (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    phone VARCHAR(32) NOT NULL,
    ticket_number VARCHAR(64) UNIQUE NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'resolved')),
    admin_token_hash VARCHAR(255),
    admin_token_expires_at TIMESTAMPTZ,
    escalation_reason TEXT NOT NULL,
    admin_notes TEXT DEFAULT '',
    resolved_by VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_reset_escalations_status ON password_reset_escalations(status);
CREATE INDEX IF NOT EXISTS idx_reset_escalations_user_id ON password_reset_escalations(user_id);
CREATE INDEX IF NOT EXISTS idx_reset_escalations_ticket ON password_reset_escalations(ticket_number);

-- ------------------------------------------------------------------------------
-- 4. INSTITUTIONAL SCOPES & RBAC ROLES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS scopes (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(64) NOT NULL,
    name VARCHAR(255) NOT NULL,
    scope_type VARCHAR(64) NOT NULL CHECK (scope_type IN ('global', 'department', 'section', 'hostel', 'club', 'facility')),
    parent_scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_scopes_code_active ON scopes(code) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_scopes_parent ON scopes(parent_scope_id);

CREATE TABLE IF NOT EXISTS permissions (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(128) UNIQUE NOT NULL,
    description TEXT,
    module VARCHAR(64) NOT NULL
);

CREATE TABLE IF NOT EXISTS roles (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(64) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id VARCHAR(64) NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id VARCHAR(64) NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS user_role_assignments (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id VARCHAR(64) NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    scope_id VARCHAR(64) NOT NULL REFERENCES scopes(id) ON DELETE CASCADE,
    valid_from TIMESTAMPTZ DEFAULT NOW(),
    valid_until TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_user_assignments ON user_role_assignments(user_id, is_active, is_deleted);
CREATE INDEX IF NOT EXISTS idx_user_role_scope ON user_role_assignments(scope_id);

-- ------------------------------------------------------------------------------
-- 5. ACADEMIC STRUCTURE: DEPARTMENTS, PROGRAMS & DEGREE COHORTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    hod_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_departments_code_active ON departments(code) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_departments_scope_active ON departments(scope_id) WHERE scope_id IS NOT NULL AND is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_departments_hod ON departments(hod_id);

CREATE TABLE IF NOT EXISTS programs (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    degree_level VARCHAR(32) NOT NULL CHECK (degree_level IN ('undergraduate', 'postgraduate', 'doctoral')),
    total_semesters INT NOT NULL DEFAULT 8 CHECK (total_semesters >= 1 AND total_semesters <= 16),
    has_branches BOOLEAN DEFAULT FALSE,
    branch VARCHAR(255) DEFAULT '',
    duration_years INT DEFAULT 4 CHECK (duration_years >= 1 AND duration_years <= 8),
    branches JSONB DEFAULT '[]'::jsonb,
    is_retired BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_programs_code_active ON programs(code) WHERE is_deleted = FALSE;

-- Normalized Program Branches (1NF/3NF)
CREATE TABLE IF NOT EXISTS program_branches (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    program_id VARCHAR(64) NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    branch_code VARCHAR(32) NOT NULL,
    branch_name VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_program_branch UNIQUE (program_id, branch_code)
);

CREATE INDEX IF NOT EXISTS idx_program_branches_prog ON program_branches(program_id);

CREATE TABLE IF NOT EXISTS semesters (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    program_id VARCHAR(64) NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    semester_number INT NOT NULL CHECK (semester_number >= 1 AND semester_number <= 16),
    academic_year VARCHAR(32) NOT NULL,
    section VARCHAR(16) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_semesters_program ON semesters(program_id);
CREATE INDEX IF NOT EXISTS idx_semesters_term ON semesters(academic_year, semester_number);

CREATE TABLE IF NOT EXISTS sections (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name VARCHAR(32) NOT NULL,
    semester_number INT NOT NULL CHECK (semester_number >= 1 AND semester_number <= 16),
    academic_year VARCHAR(32) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    department_id VARCHAR(64) REFERENCES departments(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_sections_term ON sections(semester_number, academic_year);
CREATE INDEX IF NOT EXISTS idx_sections_dept ON sections(department_id);

CREATE TABLE IF NOT EXISTS section_programs (
    section_id VARCHAR(64) NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
    program_id VARCHAR(64) NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    PRIMARY KEY (section_id, program_id)
);

-- ------------------------------------------------------------------------------
-- 6. ARCHETYPE PROFILES (Normalized Extensions of users)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS student_profiles (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    admission_year INT NOT NULL,
    entry_type VARCHAR(16) NOT NULL CHECK (entry_type IN ('regular', 'lateral', 'transfer')),
    program VARCHAR(64) NOT NULL,
    current_semester INT NOT NULL DEFAULT 1 CHECK (current_semester >= 1),
    batch_year INT NOT NULL,
    academic_name VARCHAR(255),
    academic_name_verified BOOLEAN DEFAULT FALSE,
    academic_name_source VARCHAR(64),
    class_x_document_ref VARCHAR(255),
    abc_id VARCHAR(32),
    digilocker_verified BOOLEAN DEFAULT FALSE,
    digilocker_verified_at TIMESTAMPTZ,
    program_id VARCHAR(64) REFERENCES programs(id) ON DELETE SET NULL,
    semester_id VARCHAR(64) REFERENCES semesters(id) ON DELETE SET NULL,
    section_id VARCHAR(64) REFERENCES sections(id) ON DELETE SET NULL,
    CONSTRAINT chk_student_batch_year CHECK (batch_year >= admission_year)
);

CREATE INDEX IF NOT EXISTS idx_student_profiles_program ON student_profiles(program_id);
CREATE INDEX IF NOT EXISTS idx_student_profiles_section ON student_profiles(section_id);

CREATE TABLE IF NOT EXISTS employee_records (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    joining_date DATE NOT NULL,
    employee_code VARCHAR(64) UNIQUE,
    employment_type VARCHAR(32) NOT NULL CHECK (employment_type IN ('permanent', 'contract', 'visiting')),
    is_academic BOOLEAN DEFAULT FALSE,
    is_administrative BOOLEAN DEFAULT FALSE,
    emergency_contact_name VARCHAR(128),
    emergency_contact_phone VARCHAR(32)
);

CREATE TABLE IF NOT EXISTS academic_profiles (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    academic_rank VARCHAR(64) NOT NULL,
    cabin_location VARCHAR(128),
    google_scholar_id VARCHAR(64),
    research_areas TEXT[] DEFAULT '{}'
);

-- Normalized Academic Research Areas (1NF)
CREATE TABLE IF NOT EXISTS academic_research_areas (
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    research_area VARCHAR(128) NOT NULL,
    PRIMARY KEY (user_id, research_area)
);

CREATE TABLE IF NOT EXISTS employee_department_affiliations (
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    department_scope_id VARCHAR(64) NOT NULL REFERENCES scopes(id) ON DELETE CASCADE,
    is_primary BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, department_scope_id)
);

CREATE TABLE IF NOT EXISTS administrative_profiles (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    primary_unit VARCHAR(64) NOT NULL,
    designation VARCHAR(64) NOT NULL,
    office_location VARCHAR(128)
);

CREATE TABLE IF NOT EXISTS contractor_profiles (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    onboarding_year INT NOT NULL,
    vendor_organization VARCHAR(128) NOT NULL,
    service_type VARCHAR(64) NOT NULL,
    contract_expires_at TIMESTAMPTZ,
    gate_pass_id VARCHAR(64),
    supervisor_name VARCHAR(128),
    supervisor_phone VARCHAR(32)
);

-- Normalized Contractor Scopes (1NF/3NF)
CREATE TABLE IF NOT EXISTS contractor_permitted_scopes (
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scope_id VARCHAR(64) NOT NULL REFERENCES scopes(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, scope_id)
);

-- ------------------------------------------------------------------------------
-- 7. HISTORICAL STUDENT TERM ENROLLMENTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS student_term_enrollments (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    program_id VARCHAR(64) REFERENCES programs(id) ON DELETE SET NULL,
    semester_id VARCHAR(64) REFERENCES semesters(id) ON DELETE SET NULL,
    section_id VARCHAR(64) REFERENCES sections(id) ON DELETE SET NULL,
    academic_year VARCHAR(32) NOT NULL,
    semester_number INT NOT NULL CHECK (semester_number >= 1),
    status VARCHAR(32) NOT NULL DEFAULT 'enrolled' CHECK (status IN ('enrolled', 'promoted', 'completed', 'detained', 'withdrawn', 'dropped')),
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (student_id, academic_year, semester_number)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_student ON student_term_enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_section ON student_term_enrollments(section_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_term ON student_term_enrollments(academic_year, semester_number);

-- ------------------------------------------------------------------------------
-- 8. SUBJECTS & CURRICULUM CATALOG
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subjects (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    credits INT NOT NULL DEFAULT 4 CHECK (credits >= 0 AND credits <= 30),
    odd_sem_code VARCHAR(32),
    even_sem_code VARCHAR(32),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_subjects_code_active ON subjects(code) WHERE is_deleted = FALSE;

CREATE TABLE IF NOT EXISTS courses (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    department_scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE SET NULL,
    subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE SET NULL,
    credits INT NOT NULL DEFAULT 3 CHECK (credits >= 0 AND credits <= 30),
    semester INT NOT NULL DEFAULT 1 CHECK (semester >= 1 AND semester <= 16),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_courses_code_active ON courses(code) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_courses_subject ON courses(subject_id);

CREATE TABLE IF NOT EXISTS syllabus_versions (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    revision_code VARCHAR(64) NOT NULL,
    effective_from_year VARCHAR(32) NOT NULL,
    effective_to_year VARCHAR(32),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    content TEXT NOT NULL,
    change_summary TEXT,
    approved_by VARCHAR(128),
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_syllabus_subject ON syllabus_versions(subject_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_syllabus_active_per_subject ON syllabus_versions(subject_id) WHERE is_active = TRUE AND is_deleted = FALSE;

-- ------------------------------------------------------------------------------
-- 9. ACADEMIC JUNCTION RELATIONSHIPS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS department_subjects (
    department_id VARCHAR(64) NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    PRIMARY KEY (department_id, subject_id)
);

CREATE TABLE IF NOT EXISTS department_teachers (
    department_id VARCHAR(64) NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
    teacher_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (department_id, teacher_id)
);

CREATE TABLE IF NOT EXISTS department_semesters (
    department_id VARCHAR(64) NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
    semester_id VARCHAR(64) NOT NULL REFERENCES semesters(id) ON DELETE CASCADE,
    PRIMARY KEY (department_id, semester_id)
);

CREATE TABLE IF NOT EXISTS semester_subjects (
    semester_id VARCHAR(64) NOT NULL REFERENCES semesters(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    PRIMARY KEY (semester_id, subject_id)
);

CREATE TABLE IF NOT EXISTS semester_teachers (
    semester_id VARCHAR(64) NOT NULL REFERENCES semesters(id) ON DELETE CASCADE,
    teacher_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (semester_id, teacher_id)
);

CREATE TABLE IF NOT EXISTS section_subjects (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    section_id VARCHAR(64) NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    program_id VARCHAR(64) REFERENCES programs(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_sec_sub_core ON section_subjects(section_id, subject_id) WHERE program_id IS NULL AND is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_sec_sub_prog ON section_subjects(section_id, subject_id, program_id) WHERE program_id IS NOT NULL AND is_deleted = FALSE;

CREATE TABLE IF NOT EXISTS section_teachers (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    section_id VARCHAR(64) NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
    teacher_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_sec_teacher_general ON section_teachers(section_id, teacher_id) WHERE subject_id IS NULL AND is_deleted = FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_sec_teacher_subject ON section_teachers(section_id, teacher_id, subject_id) WHERE subject_id IS NOT NULL AND is_deleted = FALSE;

-- ------------------------------------------------------------------------------
-- 10. LAB BATCHES & WORKLOAD ALLOCATIONS (1NF/3NF Normalized)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS lab_batches (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    section_id VARCHAR(64) NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
    name VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_lab_batches_section ON lab_batches(section_id);

CREATE TABLE IF NOT EXISTS lab_batch_students (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    batch_id VARCHAR(64) NOT NULL REFERENCES lab_batches(id) ON DELETE CASCADE,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (batch_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_lab_batch_students_batch ON lab_batch_students(batch_id);
CREATE INDEX IF NOT EXISTS idx_lab_batch_students_student ON lab_batch_students(student_id);

CREATE TABLE IF NOT EXISTS faculty_subject_allocations (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    section_id VARCHAR(64) NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    teacher_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    component_type VARCHAR(32) NOT NULL DEFAULT 'theory' CHECK (component_type IN ('theory', 'practical', 'tutorial')),
    batch_id VARCHAR(64) REFERENCES lab_batches(id) ON DELETE CASCADE,
    weekly_hours INT NOT NULL DEFAULT 3 CHECK (weekly_hours >= 1 AND weekly_hours <= 20),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_faculty_alloc_sec ON faculty_subject_allocations(section_id);
CREATE INDEX IF NOT EXISTS idx_faculty_alloc_teacher ON faculty_subject_allocations(teacher_id);
CREATE INDEX IF NOT EXISTS idx_faculty_alloc_subject ON faculty_subject_allocations(subject_id);

-- ------------------------------------------------------------------------------
-- 11. TIMETABLE & ATTENDANCE SUBSYSTEM
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS timetable_slots (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    course_id VARCHAR(64) REFERENCES courses(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) REFERENCES subjects(id) ON DELETE CASCADE,
    scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE CASCADE,
    instructor_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    start_time VARCHAR(8) NOT NULL,
    end_time VARCHAR(8) NOT NULL CHECK (start_time < end_time),
    room_number VARCHAR(64) NOT NULL,
    slot_type VARCHAR(32) NOT NULL DEFAULT 'lecture' CHECK (slot_type IN ('lecture', 'lab', 'tutorial')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_timetable_scope ON timetable_slots(scope_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_timetable_instructor ON timetable_slots(instructor_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_timetable_subject ON timetable_slots(subject_id);

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
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_scope_date ON attendance_sessions(scope_id, session_date);
CREATE INDEX IF NOT EXISTS idx_attendance_subject ON attendance_sessions(subject_id);

CREATE TABLE IF NOT EXISTS attendance_records (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    session_id VARCHAR(64) NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(16) NOT NULL CHECK (status IN ('present', 'absent', 'late', 'excused')),
    remarks VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_session_student UNIQUE(session_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_attendance_records_student ON attendance_records(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_records_session ON attendance_records(session_id);

-- ------------------------------------------------------------------------------
-- 12. NOTICES & COMMUNICATIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notices (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(64) NOT NULL CHECK (category IN ('academic', 'exam', 'urgent', 'event', 'hostel')),
    publisher_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    target_scope_id VARCHAR(64) REFERENCES scopes(id) ON DELETE CASCADE,
    priority VARCHAR(16) NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'high', 'urgent')),
    published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_notices_scope ON notices(target_scope_id);
CREATE INDEX IF NOT EXISTS idx_notices_published ON notices(published_at DESC);

-- ------------------------------------------------------------------------------
-- 13. HOSTEL RESIDENTIAL SUBSYSTEM (3NF Normalized)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hostel_rooms (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    room_number INT NOT NULL CHECK (room_number >= 100 AND room_number <= 999),
    block_name VARCHAR(64) NOT NULL DEFAULT 'Block 1',
    floor INT NOT NULL DEFAULT 0 CHECK (floor >= 0 AND floor <= 20),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_rooms_number_block_active ON hostel_rooms(room_number, block_name) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_hostel_rooms_number ON hostel_rooms(room_number);

-- Normalized Assets (Functional Dependency on room_id only)
CREATE TABLE IF NOT EXISTS hostel_assets (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    room_id VARCHAR(64) NOT NULL REFERENCES hostel_rooms(id) ON DELETE CASCADE,
    asset_type VARCHAR(32) NOT NULL CHECK (asset_type IN ('bed', 'table', 'chair', 'tubelight', 'fan', 'locker')),
    serial_number VARCHAR(14) NOT NULL,
    condition VARCHAR(32) NOT NULL DEFAULT 'operational' CHECK (condition IN ('operational', 'damaged', 'under_repair', 'decommissioned')),
    installed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_assets_serial_active ON hostel_assets(serial_number) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_hostel_assets_room_id ON hostel_assets(room_id);

-- Normalized Occupants (Functional Dependency on room_id and user_id only)
CREATE TABLE IF NOT EXISTS hostel_occupants (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    room_id VARCHAR(64) NOT NULL REFERENCES hostel_rooms(id) ON DELETE CASCADE,
    bed_number INT CHECK (bed_number IS NULL OR (bed_number BETWEEN 1 AND 3)),
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    allotted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    vacated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_hostel_occupants_room_id ON hostel_occupants(room_id);
CREATE INDEX IF NOT EXISTS idx_hostel_occupants_user ON hostel_occupants(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_occupant_active_bed ON hostel_occupants(room_id, bed_number) 
    WHERE is_deleted = FALSE AND vacated_at IS NULL AND bed_number IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_occupant_active_user ON hostel_occupants(user_id) 
    WHERE is_deleted = FALSE AND vacated_at IS NULL;

-- Relational Views for Denormalized Read Access
CREATE OR REPLACE VIEW v_hostel_assets AS
SELECT 
    ha.id,
    ha.room_id,
    hr.room_number,
    hr.block_name,
    ha.asset_type,
    ha.serial_number,
    ha.condition,
    ha.installed_at,
    ha.created_at,
    ha.updated_at,
    ha.is_deleted
FROM hostel_assets ha
JOIN hostel_rooms hr ON ha.room_id = hr.id;

CREATE OR REPLACE VIEW v_hostel_occupants AS
SELECT 
    ho.id,
    ho.room_id,
    hr.room_number,
    hr.block_name,
    ho.bed_number,
    ho.user_id,
    u.campus_handle,
    (u.first_name || ' ' || u.last_name) AS name,
    ho.allotted_at,
    ho.vacated_at,
    ho.created_at,
    ho.updated_at,
    ho.is_deleted
FROM hostel_occupants ho
JOIN hostel_rooms hr ON ho.room_id = hr.id
JOIN users u ON ho.user_id = u.id;

-- ------------------------------------------------------------------------------
-- 14. MESS DINING & FEEDBACK SUBSYSTEM (3NF Normalized)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mess_meals (
    id VARCHAR(64) PRIMARY KEY,
    day_of_week VARCHAR(16) NOT NULL CHECK (day_of_week IN ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday')),
    meal_type VARCHAR(16) NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'brunch')),
    start_time VARCHAR(8) NOT NULL,
    end_time VARCHAR(8) NOT NULL CHECK (start_time < end_time),
    title VARCHAR(128) NOT NULL,
    menu_summary TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_mess_meals_day ON mess_meals(day_of_week);

-- Normalized Ratings (Functional Dependency on meal_id and user_id only)
CREATE TABLE IF NOT EXISTS mess_ratings (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    meal_id VARCHAR(64) NOT NULL REFERENCES mess_meals(id) ON DELETE CASCADE,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating VARCHAR(16) NOT NULL CHECK (rating IN ('very_poor', 'poor', 'average', 'good', 'very_good', 'abstained')),
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_mess_rating_feedback CHECK (
        rating NOT IN ('very_poor', 'poor', 'average') OR (message IS NOT NULL AND length(trim(message)) > 0)
    )
);

CREATE INDEX IF NOT EXISTS idx_mess_ratings_meal ON mess_ratings(meal_id);
CREATE INDEX IF NOT EXISTS idx_mess_ratings_user ON mess_ratings(user_id);
CREATE INDEX IF NOT EXISTS idx_mess_ratings_rating ON mess_ratings(rating);
CREATE INDEX IF NOT EXISTS idx_mess_ratings_created ON mess_ratings(created_at);

-- Relational View for Mess Ratings with Dining Facts
CREATE OR REPLACE VIEW v_mess_ratings AS
SELECT 
    mr.id,
    mr.meal_id,
    mm.day_of_week,
    mm.meal_type,
    mm.title AS meal_title,
    mr.user_id,
    (u.first_name || ' ' || u.last_name) AS user_name,
    u.campus_handle,
    mr.rating,
    mr.message,
    mr.created_at,
    mr.updated_at,
    mr.is_deleted
FROM mess_ratings mr
JOIN mess_meals mm ON mr.meal_id = mm.id
JOIN users u ON mr.user_id = u.id;

-- ------------------------------------------------------------------------------
-- 15. LIBRARY MANAGEMENT SUBSYSTEM
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS library_books (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    isbn VARCHAR(32) NOT NULL,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    publisher VARCHAR(255),
    edition VARCHAR(64),
    category VARCHAR(64) NOT NULL,
    department_id VARCHAR(64) REFERENCES departments(id) ON DELETE SET NULL,
    total_copies INT NOT NULL DEFAULT 1 CHECK (total_copies >= 0),
    available_copies INT NOT NULL DEFAULT 1 CHECK (available_copies >= 0),
    shelf_location VARCHAR(64),
    cover_url TEXT,
    replacement_cost NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_lib_books_isbn ON library_books(isbn);
CREATE INDEX IF NOT EXISTS idx_lib_books_category ON library_books(category);

CREATE TABLE IF NOT EXISTS library_book_issues (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    book_id VARCHAR(64) NOT NULL REFERENCES library_books(id) ON DELETE CASCADE,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    due_date TIMESTAMPTZ NOT NULL,
    returned_at TIMESTAMPTZ,
    fine_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    status VARCHAR(32) NOT NULL DEFAULT 'issued' CHECK (status IN ('issued', 'returned', 'overdue', 'lost')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_lib_issues_user ON library_book_issues(user_id);
CREATE INDEX IF NOT EXISTS idx_lib_issues_book ON library_book_issues(book_id);

-- ------------------------------------------------------------------------------
-- 16. FEE MANAGEMENT SUBSYSTEM
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fee_invoices (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fee_type VARCHAR(32) NOT NULL CHECK (fee_type IN ('tuition', 'hostel', 'mess', 'transport', 'examination', 'laboratory', 'annual')),
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    paid_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (paid_amount >= 0),
    due_date DATE NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'partial', 'paid', 'overdue')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_fee_invoices_user ON fee_invoices(user_id);
CREATE INDEX IF NOT EXISTS idx_fee_invoices_status ON fee_invoices(status);

-- ------------------------------------------------------------------------------
-- 17. CONTINUOUS INTERNAL EVALUATION (CIE) / SESSIONAL RECORDS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sessional_records (
    id VARCHAR(64) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject_code VARCHAR(32) NOT NULL,
    subject_name VARCHAR(255) NOT NULL,
    semester_number INT NOT NULL CHECK (semester_number >= 1),
    section VARCHAR(32) NOT NULL,
    is_practical BOOLEAN NOT NULL DEFAULT FALSE,
    ct1_score NUMERIC(5,2) DEFAULT 0.00,
    ct2_score NUMERIC(5,2) DEFAULT 0.00,
    put_score NUMERIC(5,2) DEFAULT 0.00,
    ta_score NUMERIC(5,2) DEFAULT 0.00,
    lab_continuous_score NUMERIC(5,2) DEFAULT 0.00,
    lab_viva_score NUMERIC(5,2) DEFAULT 0.00,
    calculated_sessional NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    total_internal_marks NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    max_internal_marks NUMERIC(5,2) NOT NULL DEFAULT 30.00,
    formula_used VARCHAR(64) NOT NULL DEFAULT 'aktu_standard_average',
    is_frozen BOOLEAN NOT NULL DEFAULT FALSE,
    frozen_by VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (student_id, subject_code, semester_number)
);

CREATE INDEX IF NOT EXISTS idx_sessional_student ON sessional_records(student_id);
CREATE INDEX IF NOT EXISTS idx_sessional_subject ON sessional_records(subject_code);

-- ------------------------------------------------------------------------------
-- 18. CROSS-TABLE ARCHETYPE VALIDATION TRIGGERS
-- ------------------------------------------------------------------------------
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

-- ------------------------------------------------------------------------------
-- 19. AUTOMATIC TIMESTAMP TRIGGER ATTACHMENTS
-- ------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_set_updated_at_users ON users;
CREATE TRIGGER trg_set_updated_at_users BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_reset_esc ON password_reset_escalations;
CREATE TRIGGER trg_set_updated_at_reset_esc BEFORE UPDATE ON password_reset_escalations FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_scopes ON scopes;
CREATE TRIGGER trg_set_updated_at_scopes BEFORE UPDATE ON scopes FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_departments ON departments;
CREATE TRIGGER trg_set_updated_at_departments BEFORE UPDATE ON departments FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_programs ON programs;
CREATE TRIGGER trg_set_updated_at_programs BEFORE UPDATE ON programs FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_semesters ON semesters;
CREATE TRIGGER trg_set_updated_at_semesters BEFORE UPDATE ON semesters FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_sections ON sections;
CREATE TRIGGER trg_set_updated_at_sections BEFORE UPDATE ON sections FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_subjects ON subjects;
CREATE TRIGGER trg_set_updated_at_subjects BEFORE UPDATE ON subjects FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_courses ON courses;
CREATE TRIGGER trg_set_updated_at_courses BEFORE UPDATE ON courses FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_timetable ON timetable_slots;
CREATE TRIGGER trg_set_updated_at_timetable BEFORE UPDATE ON timetable_slots FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_att_sessions ON attendance_sessions;
CREATE TRIGGER trg_set_updated_at_att_sessions BEFORE UPDATE ON attendance_sessions FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_att_records ON attendance_records;
CREATE TRIGGER trg_set_updated_at_att_records BEFORE UPDATE ON attendance_records FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_notices ON notices;
CREATE TRIGGER trg_set_updated_at_notices BEFORE UPDATE ON notices FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_hostel_rooms ON hostel_rooms;
CREATE TRIGGER trg_set_updated_at_hostel_rooms BEFORE UPDATE ON hostel_rooms FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_hostel_assets ON hostel_assets;
CREATE TRIGGER trg_set_updated_at_hostel_assets BEFORE UPDATE ON hostel_assets FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_hostel_occupants ON hostel_occupants;
CREATE TRIGGER trg_set_updated_at_hostel_occupants BEFORE UPDATE ON hostel_occupants FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_mess_meals ON mess_meals;
CREATE TRIGGER trg_set_updated_at_mess_meals BEFORE UPDATE ON mess_meals FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_set_updated_at_mess_ratings ON mess_ratings;
CREATE TRIGGER trg_set_updated_at_mess_ratings BEFORE UPDATE ON mess_ratings FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

-- ------------------------------------------------------------------------------
-- 20. CANONICAL DAY-1 SYSTEM SEED (Institutional Root Administrator & Hierarchy)
-- ------------------------------------------------------------------------------
INSERT INTO scopes (id, code, name, scope_type)
VALUES ('scope-global', 'global', 'Global Institutional Scope', 'global')
ON CONFLICT (id) DO NOTHING;

INSERT INTO roles (id, code, name, description, is_system_role)
VALUES 
    ('role-admin', 'admin', 'Campus Administrator', 'Campus Administrator', true),
    ('role-campus_director', 'campus_director', 'Campus Director', 'Campus Director', true),
    ('role-hod', 'hod', 'Head of Department', 'Head of Department', true),
    ('role-faculty', 'faculty', 'Faculty Member', 'Faculty Member', true),
    ('role-warden', 'warden', 'Hostel Warden', 'Hostel Warden', true),
    ('role-canteen_manager', 'canteen_manager', 'Canteen Manager', 'Canteen Manager', true),
    ('role-staff', 'staff', 'Campus Staff', 'Campus Staff', true),
    ('role-student', 'student', 'Student', 'Student', true),
    ('role-contractor', 'contractor', 'External Contractor', 'External Contractor', true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO users (
    id, campus_handle, first_name, last_name, email, personal_email, phone, archetype,
    university_roll_no, password_hash, must_change_password, is_first_login, is_active, status, created_at, updated_at, is_deleted
) VALUES (
    'usr-campus_admin', 'campus_admin', 'Campus', 'Administrator', 'admin@campus.edu',
    'director@campus-governance.org', '+91 98000 00001', 'employee',
    'ADM-2023-0001', '8cae61c5f37e55fa392d1a1f17fc68df67707901e51ed637d1890e134cd6c8f5', false, false, true, 'active', NOW() - INTERVAL '1 year', NOW(), false
) ON CONFLICT (id) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    must_change_password = false,
    is_first_login = false,
    is_active = true,
    status = 'active';

INSERT INTO employee_records (user_id, joining_date, employee_code, employment_type, is_academic, is_administrative)
VALUES ('usr-campus_admin', CURRENT_DATE - INTERVAL '1 year', 'ADM-DIR-001', 'permanent', false, true)
ON CONFLICT (user_id) DO UPDATE SET is_administrative = true;

INSERT INTO administrative_profiles (user_id, primary_unit, designation, office_location)
VALUES ('usr-campus_admin', 'unit:administration', 'Campus Administrator', 'Central Admin Tower 501')
ON CONFLICT (user_id) DO UPDATE SET
    primary_unit = EXCLUDED.primary_unit,
    designation = EXCLUDED.designation,
    office_location = EXCLUDED.office_location;

INSERT INTO user_role_assignments (id, user_id, role_id, scope_id, is_active)
VALUES 
    ('assign-admin-1', 'usr-campus_admin', 'role-admin', 'scope-global', true),
    ('assign-admin-2', 'usr-campus_admin', 'role-campus_director', 'scope-global', true)
ON CONFLICT (id) DO NOTHING;
