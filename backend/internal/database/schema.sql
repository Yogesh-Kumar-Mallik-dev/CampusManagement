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
