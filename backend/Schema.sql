-- Motorcycle Training Management System - Complete Database Schema
-- SQLite Database

-- ============================================================================
-- TRAINING COMPANY & USERS
-- ============================================================================

CREATE TABLE IF NOT EXISTS training_company (
    company_id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_name TEXT NOT NULL,
    training_body_reference TEXT NOT NULL UNIQUE,
    address_line_1 TEXT,
    address_line_2 TEXT,
    city TEXT,
    county TEXT,
    postcode TEXT,
    phone TEXT,
    email TEXT,
    official_stamp_image_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    is_admin BOOLEAN NOT NULL DEFAULT 0,
    is_instructor BOOLEAN NOT NULL DEFAULT 0,
    instructor_certificate_number TEXT,
    phone TEXT,
    signature_image_path TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_login TEXT,
    FOREIGN KEY (company_id) REFERENCES training_company(company_id)
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_company ON users(company_id);

-- ============================================================================
-- SESSION TYPES & TASK CONFIGURATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS session_types (
    session_type TEXT PRIMARY KEY,
    description TEXT NOT NULL,
    duration_hours REAL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS task_configuration (
    config_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_type TEXT NOT NULL,
    sequence INTEGER NOT NULL,
    task_id TEXT NOT NULL,
    task_description TEXT NOT NULL,
    mandatory BOOLEAN NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (session_type) REFERENCES session_types(session_type),
    UNIQUE(session_type, sequence),
    UNIQUE(session_type, task_id)
);

CREATE INDEX idx_task_config_session ON task_configuration(session_type);

-- ============================================================================
-- TRAINING SESSIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS training_sessions (
    session_id INTEGER PRIMARY KEY AUTOINCREMENT,
    instructor_id INTEGER NOT NULL,
    company_id INTEGER NOT NULL,
    session_type TEXT NOT NULL,
    session_date TEXT NOT NULL,
    location TEXT,
    site_code TEXT,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'IN_PROGRESS' CHECK(status IN ('PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    completed_at TEXT,
    FOREIGN KEY (instructor_id) REFERENCES users(user_id),
    FOREIGN KEY (company_id) REFERENCES training_company(company_id),
    FOREIGN KEY (session_type) REFERENCES session_types(session_type)
);

CREATE INDEX idx_sessions_instructor ON training_sessions(instructor_id);
CREATE INDEX idx_sessions_date ON training_sessions(session_date);
CREATE INDEX idx_sessions_status ON training_sessions(status);

-- ============================================================================
-- STUDENTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS students (
    student_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    license_number TEXT NOT NULL,
    license_surname TEXT,
    license_given_names TEXT,
    date_of_birth TEXT,
    license_issue_date TEXT,
    license_expiry_date TEXT,
    license_categories TEXT,
    address TEXT,
    postcode TEXT,
    email TEXT,
    phone TEXT,
    student_photo_path TEXT,
    license_photo_path TEXT,
    match_score REAL,
    verified BOOLEAN DEFAULT 0,
    verification_status TEXT,
    bike_type TEXT CHECK(bike_type IN ('Manual', 'Automatic', NULL)),
    bike_description TEXT,
    student_signature_path TEXT,
    training_outcome TEXT CHECK(training_outcome IN ('PASS', 'FAIL', 'INCOMPLETE', NULL)),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (session_id) REFERENCES training_sessions(session_id)
);

CREATE INDEX idx_students_session ON students(session_id);
CREATE INDEX idx_students_license ON students(license_number);

-- ============================================================================
-- STUDENT TASKS
-- ============================================================================

CREATE TABLE IF NOT EXISTS student_tasks (
    student_task_id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    session_type TEXT NOT NULL,
    task_id TEXT NOT NULL,
    task_description TEXT NOT NULL,
    sequence INTEGER NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT 0,
    completed_at TEXT,
    notes TEXT,
    override_reason TEXT,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (session_type) REFERENCES session_types(session_type),
    UNIQUE(student_id, task_id)
);

CREATE INDEX idx_student_tasks_student ON student_tasks(student_id);
CREATE INDEX idx_student_tasks_session_type ON student_tasks(session_type);

-- ============================================================================
-- CERTIFICATES
-- ============================================================================

CREATE TABLE IF NOT EXISTS certificate_batches (
    batch_id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id INTEGER NOT NULL,
    session_type TEXT NOT NULL,
    start_certificate_number INTEGER NOT NULL,
    end_certificate_number INTEGER NOT NULL,
    batch_size INTEGER NOT NULL DEFAULT 25,
    current_certificate_number INTEGER NOT NULL,
    certificates_remaining INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE', 'EXHAUSTED', 'CANCELLED')),
    ordered_by INTEGER,
    received_by INTEGER,
    ordered_date TEXT,
    received_date TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (company_id) REFERENCES training_company(company_id),
    FOREIGN KEY (session_type) REFERENCES session_types(session_type),
    FOREIGN KEY (ordered_by) REFERENCES users(user_id),
    FOREIGN KEY (received_by) REFERENCES users(user_id)
);

CREATE INDEX idx_cert_batches_company ON certificate_batches(company_id);
CREATE INDEX idx_cert_batches_status ON certificate_batches(status);

CREATE TABLE IF NOT EXISTS certificates (
    certificate_id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id INTEGER NOT NULL,
    certificate_number INTEGER NOT NULL UNIQUE,
    session_type TEXT NOT NULL,
    student_id INTEGER,
    session_id INTEGER,
    issue_date TEXT,
    completion_date TEXT,
    completion_time TEXT,
    instructor_id INTEGER,
    status TEXT NOT NULL DEFAULT 'AVAILABLE' CHECK(status IN ('AVAILABLE', 'ISSUED', 'VOID', 'CANCELLED')),
    pdf_file_path TEXT,
    verification_code TEXT UNIQUE,
    qr_code_image_path TEXT,
    void_reason TEXT,
    voided_by INTEGER,
    voided_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (batch_id) REFERENCES certificate_batches(batch_id),
    FOREIGN KEY (session_type) REFERENCES session_types(session_type),
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (session_id) REFERENCES training_sessions(session_id),
    FOREIGN KEY (instructor_id) REFERENCES users(user_id),
    FOREIGN KEY (voided_by) REFERENCES users(user_id)
);

CREATE INDEX idx_certificates_batch ON certificates(batch_id);
CREATE INDEX idx_certificates_number ON certificates(certificate_number);
CREATE INDEX idx_certificates_student ON certificates(student_id);
CREATE INDEX idx_certificates_status ON certificates(status);

-- ============================================================================
-- CERTIFICATE EMAILS
-- ============================================================================

CREATE TABLE IF NOT EXISTS certificate_emails (
    email_id INTEGER PRIMARY KEY AUTOINCREMENT,
    certificate_id INTEGER NOT NULL,
    student_email TEXT NOT NULL,
    sent_at TEXT NOT NULL DEFAULT (datetime('now')),
    delivery_status TEXT NOT NULL DEFAULT 'SENT' CHECK(delivery_status IN ('SENT', 'DELIVERED', 'FAILED', 'BOUNCED')),
    opened_at TEXT,
    error_message TEXT,
    FOREIGN KEY (certificate_id) REFERENCES certificates(certificate_id)
);

CREATE INDEX idx_cert_emails_certificate ON certificate_emails(certificate_id);

-- ============================================================================
-- AUDIT LOG
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_log (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    action TEXT NOT NULL,
    table_name TEXT NOT NULL,
    record_id INTEGER,
    old_values TEXT,
    new_values TEXT,
    ip_address TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE INDEX idx_audit_user ON audit_log(user_id);
CREATE INDEX idx_audit_table ON audit_log(table_name);
CREATE INDEX idx_audit_created ON audit_log(created_at);

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- Default Company (will be updated by admin)
INSERT INTO training_company (company_name, training_body_reference) 
VALUES ('Default Training Company', 'TBD001');

-- Session Types
INSERT INTO session_types (session_type, description, duration_hours) VALUES
('CBT', 'Compulsory Basic Training', 7),
('MODULE_1', 'Module 1 - Off-road riding test', 1),
('MODULE_2', 'Module 2 - On-road riding test', 1),
('DAS', 'Direct Access Scheme', 5),
('A2', 'A2 License Training', 5);

-- Default CBT Task Configuration
INSERT INTO task_configuration (session_type, sequence, task_id, task_description, mandatory) VALUES
('CBT', 1, 'EYESIGHT_CHECK', 'Eyesight checked', 1),
('CBT', 2, 'LICENCE_CHECK', 'Licence photo checked', 1),
('CBT', 3, 'PART_A_PPE', 'Part A (PPE) completed', 1),
('CBT', 4, 'PART_B_CONTROLS', 'Part B (Controls/Stands/Maintenance) completed', 1),
('CBT', 5, 'PART_C_WALK_STOP', 'Part C - Walk and Stop completed', 1),
('CBT', 6, 'PART_C_CENTRE_STAND', 'Part C - On/Off Centre Stand completed', 1),
('CBT', 7, 'PART_C_CLUTCH', 'Part C - Clutch biting point checked', 1),
('CBT', 8, 'PART_C_BACK_BRAKE', 'Part C - Straight line back brake checked', 1),
('CBT', 9, 'PART_C_FRONT_BRAKE', 'Part C - Use of front brake checked', 1);

-- Default Admin User (password: admin123)
-- Password hash generated with bcrypt
INSERT INTO users (company_id, name, email, password_hash, is_admin, is_instructor, status) 
VALUES (1, 'System Administrator', 'admin@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeewY5NU7kU4fK3iqa', 1, 0, 'ACTIVE');

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: Active sessions with instructor details
CREATE VIEW IF NOT EXISTS v_active_sessions AS
SELECT 
    s.session_id,
    s.session_date,
    s.session_type,
    s.location,
    s.status,
    u.name as instructor_name,
    u.email as instructor_email,
    COUNT(DISTINCT st.student_id) as student_count
FROM training_sessions s
JOIN users u ON s.instructor_id = u.user_id
LEFT JOIN students st ON s.session_id = st.session_id
WHERE s.status IN ('IN_PROGRESS', 'PLANNED')
GROUP BY s.session_id;

-- View: Certificate inventory
CREATE VIEW IF NOT EXISTS v_certificate_inventory AS
SELECT 
    cb.batch_id,
    cb.session_type,
    cb.start_certificate_number,
    cb.end_certificate_number,
    cb.current_certificate_number,
    cb.certificates_remaining,
    cb.status,
    tc.company_name
FROM certificate_batches cb
JOIN training_company tc ON cb.company_id = tc.company_id
WHERE cb.status = 'ACTIVE'
ORDER BY cb.session_type, cb.start_certificate_number;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Update training_company updated_at timestamp
CREATE TRIGGER IF NOT EXISTS update_company_timestamp 
AFTER UPDATE ON training_company
BEGIN
    UPDATE training_company SET updated_at = datetime('now') WHERE company_id = NEW.company_id;
END;

-- Auto-decrement certificates_remaining when a certificate is issued
CREATE TRIGGER IF NOT EXISTS decrement_certificate_count
AFTER UPDATE ON certificates
WHEN NEW.status = 'ISSUED' AND OLD.status = 'AVAILABLE'
BEGIN
    UPDATE certificate_batches 
    SET certificates_remaining = certificates_remaining - 1,
        current_certificate_number = NEW.certificate_number
    WHERE batch_id = NEW.batch_id;
    
    -- Mark batch as exhausted if no certificates remaining
    UPDATE certificate_batches
    SET status = 'EXHAUSTED'
    WHERE batch_id = NEW.batch_id AND certificates_remaining = 0;
END;