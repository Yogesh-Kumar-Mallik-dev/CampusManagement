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
    status VARCHAR(32) DEFAULT 'active', -- 'active', 'graduated', 'discontinued', 'suspended', 'resigned', 'retired'
    discontinuation_reason TEXT,
    discontinued_at TIMESTAMPTZ,
    discontinued_by VARCHAR(128),
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


-- ========================================================
-- PHASE 2: DEPARTMENTS, PROGRAMS, SEMESTERS & SUBJECTS M:N
-- ========================================================

-- 14. Academic Departments
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(32) UNIQUE NOT NULL,      -- e.g. 'CSE', 'ECE', 'MATH'
    name VARCHAR(255) NOT NULL,            -- e.g. 'Computer Science & Engineering'
    description TEXT,
    hod_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_departments_code ON departments(code);

-- 15. Degree Programs (Overarching degree courses)
CREATE TABLE IF NOT EXISTS programs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(32) UNIQUE NOT NULL,      -- e.g. 'BTECH-CSE', 'MBA'
    name VARCHAR(255) NOT NULL,            -- e.g. 'Bachelor of Technology in Computer Science'
    degree_level VARCHAR(32) NOT NULL,     -- 'undergraduate', 'postgraduate', 'doctoral'
    total_semesters INT NOT NULL DEFAULT 8,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_programs_code ON programs(code);

-- 16. Subjects (Course modules)
CREATE TABLE IF NOT EXISTS subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(32) UNIQUE NOT NULL,      -- e.g. 'CS301'
    name VARCHAR(255) NOT NULL,            -- e.g. 'Operating Systems'
    credits INT NOT NULL DEFAULT 4,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_subjects_code ON subjects(code);

-- 17. Semesters (from a Program, e.g. B.Tech CSE Semester 5, Sec 3A)
CREATE TABLE IF NOT EXISTS semesters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID REFERENCES programs(id) ON DELETE CASCADE,
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
    department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    PRIMARY KEY (department_id, subject_id)
);

-- 19. Department <-> Teacher Many-to-Many
CREATE TABLE IF NOT EXISTS department_teachers (
    department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (department_id, teacher_id)
);

-- 20. Department <-> Semester Many-to-Many
CREATE TABLE IF NOT EXISTS department_semesters (
    department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
    semester_id UUID REFERENCES semesters(id) ON DELETE CASCADE,
    PRIMARY KEY (department_id, semester_id)
);

-- 21. Semester <-> Subject Many-to-Many (within the department)
CREATE TABLE IF NOT EXISTS semester_subjects (
    semester_id UUID REFERENCES semesters(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    PRIMARY KEY (semester_id, subject_id)
);

-- 22. Semester <-> Teacher Many-to-Many
CREATE TABLE IF NOT EXISTS semester_teachers (
    semester_id UUID REFERENCES semesters(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (semester_id, teacher_id)
);

-- Note: Students have a Many-to-One relationship with Semester (not directly to Department)
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS semester_id UUID REFERENCES semesters(id) ON DELETE SET NULL;

-- 23. Academic Sections (Cross-program cohorts/divisions within a semester)
CREATE TABLE IF NOT EXISTS sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(32) NOT NULL,             -- e.g. 'Section B'
    semester_number INT NOT NULL,          -- e.g. 1, 2, 3, 5
    academic_year VARCHAR(32) NOT NULL,    -- '2025-2026'
    display_name VARCHAR(255) NOT NULL,    -- e.g. 'Semester 3 - Section B'
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_sections_term ON sections(semester_number, academic_year);

-- 24. Section <-> Program Many-to-Many (Section shared across multiple programs e.g. CSE, AI/ML, DS)
CREATE TABLE IF NOT EXISTS section_programs (
    section_id UUID REFERENCES sections(id) ON DELETE CASCADE,
    program_id UUID REFERENCES programs(id) ON DELETE CASCADE,
    PRIMARY KEY (section_id, program_id)
);

-- 25. Section <-> Subject Many-to-Many (with optional program specialization)
CREATE TABLE IF NOT EXISTS section_subjects (
    section_id UUID REFERENCES sections(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    program_id UUID REFERENCES programs(id) ON DELETE CASCADE, -- NULL = common core; non-NULL = program-specific
    PRIMARY KEY (section_id, subject_id, program_id)
);

-- 26. Section <-> Teacher Many-to-Many
CREATE TABLE IF NOT EXISTS section_teachers (
    section_id UUID REFERENCES sections(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES users(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
    PRIMARY KEY (section_id, teacher_id)
);

-- Note: Students belong to their Degree Program and active Section cohort
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS section_id UUID REFERENCES sections(id) ON DELETE SET NULL;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS program_id UUID REFERENCES programs(id) ON DELETE SET NULL;

-- 27. Subject Term Codes (Odd vs Even Semester Codes e.g. BCA 102/202)
ALTER TABLE subjects ADD COLUMN IF NOT EXISTS odd_sem_code VARCHAR(32);
ALTER TABLE subjects ADD COLUMN IF NOT EXISTS even_sem_code VARCHAR(32);

-- 28. Syllabus Versions (Immutable audit trail of past and active curricula)
CREATE TABLE IF NOT EXISTS syllabus_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
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

-- 29. Lab Batches (Sub-division of a section cohort for practical lab sessions e.g. Batch B1, Batch B2)
CREATE TABLE IF NOT EXISTS lab_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    section_id UUID REFERENCES sections(id) ON DELETE CASCADE,
    name VARCHAR(64) NOT NULL,
    student_ids UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_lab_batches_section ON lab_batches(section_id);

-- 30. Faculty Subject Allocations (Instructor assignment to Theory, Practical/Lab Batches, Tutorials with Weekly Contact Hours)
CREATE TABLE IF NOT EXISTS faculty_subject_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    section_id UUID REFERENCES sections(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES users(id) ON DELETE CASCADE,
    component_type VARCHAR(32) NOT NULL DEFAULT 'theory', -- 'theory', 'practical', 'tutorial'
    batch_id UUID REFERENCES lab_batches(id) ON DELETE CASCADE, -- NULL = whole section (theory); non-NULL = specific lab batch
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_number INT NOT NULL CHECK (room_number >= 100 AND room_number <= 999),
    block_name VARCHAR(64) NOT NULL DEFAULT 'Aryabhatta Block',
    floor INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    UNIQUE (room_number, block_name)
);

CREATE INDEX IF NOT EXISTS idx_hostel_rooms_number ON hostel_rooms(room_number);

-- 32. Hostel Assets (Beds, tables, chairs, tubelights, fans, lockers with alphanumeric serial number <= 14 characters)
CREATE TABLE IF NOT EXISTS hostel_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES hostel_rooms(id) ON DELETE CASCADE,
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

-- 33. Hostel Occupants (Students allocated to a room, up to 3 residents max)
CREATE TABLE IF NOT EXISTS hostel_occupants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES hostel_rooms(id) ON DELETE CASCADE,
    room_number INT NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    campus_handle VARCHAR(128) NOT NULL,
    name VARCHAR(128) NOT NULL,
    allotted_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    UNIQUE (room_number, user_id)
);

CREATE INDEX IF NOT EXISTS idx_hostel_occupants_room ON hostel_occupants(room_number);
CREATE INDEX IF NOT EXISTS idx_hostel_occupants_user ON hostel_occupants(user_id);

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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meal_id VARCHAR(64) REFERENCES mess_meals(id) ON DELETE CASCADE,
    day_of_week VARCHAR(16) NOT NULL,
    meal_type VARCHAR(16) NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
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




