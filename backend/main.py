from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from typing import List, Optional
import face_recognition
import numpy as np
from PIL import Image
import io
import sqlite3
from datetime import datetime, timedelta
import json
from jose import jwt, JWTError
from passlib.context import CryptContext
import secrets
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
import qrcode
import os
from datetime import datetime
from dotenv import load_dotenv
import os

load_dotenv

app = FastAPI(title="Motorcycle Training Backend")

# Security
SECRET_KEY = os.getenv('SECRET_KEY', secrets.token_urlsafe(32))
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# ============================================================================
# DATABASE HELPERS
# ============================================================================

def get_db():
    """Get database connection"""
    conn = sqlite3.connect('training.db')
    conn.row_factory = sqlite3.Row
    return conn

# ============================================================================
# AUTHENTICATION MODELS
# ============================================================================

class UserRegister(BaseModel):
    name: str
    email: EmailStr
    password: str
    is_admin: bool = False
    is_instructor: bool = True
    instructor_certificate_number: Optional[str] = None
    phone: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
    user: dict

# ============================================================================
# CERTIFICATE MODELS
# ============================================================================

class CertificateBatch(BaseModel):
    session_type: str
    start_certificate_number: int
    batch_size: int = 25

# ============================================================================
# SESSION MODELS
# ============================================================================

class SessionCreate(BaseModel):
    session_type: str
    location: Optional[str] = None
    site_code: Optional[str] = None
    notes: Optional[str] = None

class StudentCreate(BaseModel):
    name: str
    license_number: str
    email: Optional[str] = None
    phone: Optional[str] = None
    date_of_birth: Optional[str] = None
    bike_type: Optional[str] = None

class TaskComplete(BaseModel):
    task_id: str
    completed: bool
    notes: Optional[str] = None

# ============================================================================
# AUTH HELPERS
# ============================================================================

def verify_password(plain_password, hashed_password):
    # Bcrypt has 72 byte limit, truncate if needed
    if len(plain_password.encode('utf-8')) > 72:
        plain_password = plain_password[:72]
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    # Bcrypt has 72 byte limit, truncate if needed
    if len(password.encode('utf-8')) > 72:
        password = password[:72]
    return pwd_context.hash(password)

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid authentication")
        
        conn = get_db()
        c = conn.cursor()
        c.execute("SELECT * FROM users WHERE user_id = ?", (user_id,))
        user = c.fetchone()
        conn.close()
        
        if user is None:
            raise HTTPException(status_code=401, detail="User not found")
        
        return dict(user)
    except jwt.ExpiredSignatureError as e:
        print(f"=== TOKEN EXPIRED: {e} ===")
        raise HTTPException(status_code=401, detail="Token expired")
    except JWTError as e:
        print(f"=== JWT ERROR hit point: {e} ===")
        raise HTTPException(status_code=401, detail="Invalid authentication")
    except Exception as e:
        print(f"=== UNEXPECTED ERROR: {e} ===")
        raise HTTPException(status_code=401, detail=f"Auth error: {str(e)}")

def require_admin(current_user: dict = Depends(get_current_user)):
    if not current_user.get('is_admin'):
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user

def require_instructor(current_user: dict = Depends(get_current_user)):
    if not current_user.get('is_instructor'):
        raise HTTPException(status_code=403, detail="Instructor access required")
    return current_user

# ============================================================================
# ROOT & HEALTH
# ============================================================================

@app.get("/")
async def root():
    return {
        "message": "Motorcycle Training Backend API",
        "status": "running",
        "version": "2.0.0"
    }

@app.get("/health")
async def health():
    try:
        conn = get_db()
        c = conn.cursor()
        c.execute("SELECT 1")
        conn.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}

# ============================================================================
# AUTHENTICATION ENDPOINTS
# ============================================================================

@app.post("/auth/register", response_model=Token)
async def register(user: UserRegister, current_admin: dict = Depends(require_admin)):
    """Register a new user (admin or instructor). Requires admin access."""
    try:
        conn = get_db()
        c = conn.cursor()
        
        # Check if email already exists
        c.execute("SELECT email FROM users WHERE email = ?", (user.email,))
        if c.fetchone():
            raise HTTPException(status_code=400, detail="Email already registered")
        
        # Get company_id (assuming first company for now)
        c.execute("SELECT company_id FROM training_company LIMIT 1")
        company = c.fetchone()
        if not company:
            raise HTTPException(status_code=500, detail="No company configured")
        
        company_id = company['company_id']
        
        # Hash password
        hashed_password = get_password_hash(user.password)
        
        # Insert user
        c.execute("""INSERT INTO users 
                     (company_id, name, email, password_hash, is_admin, is_instructor,
                      instructor_certificate_number, phone, status)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'ACTIVE')""",
                  (company_id, user.name, user.email, hashed_password,
                   user.is_admin, user.is_instructor, user.instructor_certificate_number,
                   user.phone))
        
        user_id = c.lastrowid
        conn.commit()
        
        # Get created user
        c.execute("SELECT * FROM users WHERE user_id = ?", (user_id,))
        new_user = dict(c.fetchone())
        conn.close()
        
        # Create token
        access_token = create_access_token({"sub": str(user_id)})
        
        # Remove password hash from response
        new_user.pop('password_hash', None)
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": new_user
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Registration error: {str(e)}")

@app.post("/auth/login", response_model=Token)
async def login(credentials: UserLogin):
    """Login with email and password"""
    # In the login function, add these lines:
    try:
        conn = get_db()
        c = conn.cursor()
        
        # Get user by email
        c.execute("SELECT * FROM users WHERE email = ? AND status = 'ACTIVE'", 
                  (credentials.email,))
        user = c.fetchone()
        
        if not user or not verify_password(credentials.password, user['password_hash']):
            raise HTTPException(
                status_code=401,
                detail="Incorrect email or password"
            )
        
        # Update last login
        c.execute("UPDATE users SET last_login = ? WHERE user_id = ?",
                  (datetime.now().isoformat(), user['user_id']))
        conn.commit()
        conn.close()
        
        # Create token
        access_token = create_access_token({"sub": str(user['user_id'])})
        
        # Convert to dict and remove password
        user_dict = dict(user)
        user_dict.pop('password_hash', None)
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": user_dict
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Login error: {str(e)}")

@app.get("/auth/me")
async def get_current_user_info(current_user: dict = Depends(get_current_user)):
    """Get current user information"""
    user = current_user.copy()
    user.pop('password_hash', None)
    return user

# ============================================================================
# COMPANY MANAGEMENT (ADMIN ONLY)
# ============================================================================

@app.get("/company")
async def get_company(current_user: dict = Depends(get_current_user)):
    """Get company information"""
    try:
        conn = get_db()
        c = conn.cursor()
        c.execute("SELECT * FROM training_company WHERE company_id = ?", 
                  (current_user['company_id'],))
        company = c.fetchone()
        conn.close()
        
        if not company:
            raise HTTPException(status_code=404, detail="Company not found")
        
        return dict(company)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/company")
async def update_company(company_data: dict, current_admin: dict = Depends(require_admin)):
    """Update company information (admin only)"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        # Build update query dynamically
        allowed_fields = ['company_name', 'training_body_reference', 'address_line_1',
                         'address_line_2', 'city', 'county', 'postcode', 'phone', 'email']
        
        updates = []
        values = []
        for field in allowed_fields:
            if field in company_data:
                updates.append(f"{field} = ?")
                values.append(company_data[field])
        
        if updates:
            values.append(current_admin['company_id'])
            query = f"UPDATE training_company SET {', '.join(updates)} WHERE company_id = ?"
            c.execute(query, values)
            conn.commit()
        
        # Get updated company
        c.execute("SELECT * FROM training_company WHERE company_id = ?", 
                  (current_admin['company_id'],))
        company = dict(c.fetchone())
        conn.close()
        
        return company
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# CERTIFICATE BATCH MANAGEMENT
# ============================================================================

@app.post("/certificates/batch")
async def create_certificate_batch(batch: CertificateBatch, 
                                   current_admin: dict = Depends(require_admin)):
    """Create a new certificate batch (admin only)"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        end_number = batch.start_certificate_number + batch.batch_size - 1
        
        # Insert batch
        c.execute("""INSERT INTO certificate_batches 
                     (company_id, session_type, start_certificate_number, end_certificate_number,
                      batch_size, current_certificate_number, certificates_remaining, status,
                      received_by, received_date)
                     VALUES (?, ?, ?, ?, ?, ?, ?, 'ACTIVE', ?, ?)""",
                  (current_admin['company_id'], batch.session_type,
                   batch.start_certificate_number, end_number, batch.batch_size,
                   batch.start_certificate_number, batch.batch_size,
                   current_admin['user_id'], datetime.now().isoformat()))
        
        batch_id = c.lastrowid
        
        # Create individual certificates
        for cert_num in range(batch.start_certificate_number, end_number + 1):
            c.execute("""INSERT INTO certificates 
                         (batch_id, certificate_number, session_type, status)
                         VALUES (?, ?, ?, 'AVAILABLE')""",
                      (batch_id, cert_num, batch.session_type))
        
        conn.commit()
        conn.close()
        
        return {
            "batch_id": batch_id,
            "start_number": batch.start_certificate_number,
            "end_number": end_number,
            "total_certificates": batch.batch_size,
            "status": "success"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/certificates/inventory")
async def get_certificate_inventory(current_user: dict = Depends(get_current_user)):
    """Get certificate inventory status"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        c.execute("""SELECT cb.*, st.description as session_type_description
                     FROM certificate_batches cb
                     JOIN session_types st ON cb.session_type = st.session_type
                     WHERE cb.company_id = ? AND cb.status = 'ACTIVE'
                     ORDER BY cb.session_type, cb.start_certificate_number""",
                  (current_user['company_id'],))
        
        batches = [dict(row) for row in c.fetchall()]
        conn.close()
        
        return {"batches": batches}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/certificates/next/{session_type}")
async def get_next_certificate(session_type: str, 
                               current_instructor: dict = Depends(require_instructor)):
    """Get next available certificate for a session type"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        # Get next available certificate
        c.execute("""SELECT c.*, cb.certificates_remaining
                     FROM certificates c
                     JOIN certificate_batches cb ON c.batch_id = cb.batch_id
                     WHERE c.session_type = ? AND c.status = 'AVAILABLE'
                     AND cb.company_id = ? AND cb.status = 'ACTIVE'
                     ORDER BY c.certificate_number
                     LIMIT 1""",
                  (session_type, current_instructor['company_id']))
        
        cert = c.fetchone()
        conn.close()
        
        if not cert:
            raise HTTPException(status_code=404, 
                              detail=f"No available certificates for {session_type}")
        
        return dict(cert)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# SESSION MANAGEMENT
# ============================================================================

@app.post("/sessions")
async def create_session(session: SessionCreate,
                        current_instructor: dict = Depends(require_instructor)):
    """Create a new training session"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        c.execute("""INSERT INTO training_sessions
                     (instructor_id, company_id, session_type, session_date,
                      location, site_code, notes, status)
                     VALUES (?, ?, ?, ?, ?, ?, ?, 'IN_PROGRESS')""",
                  (current_instructor['user_id'], current_instructor['company_id'],
                   session.session_type, datetime.now().date().isoformat(),
                   session.location, session.site_code, session.notes))
        
        session_id = c.lastrowid
        conn.commit()
        
        # Get created session
        c.execute("""SELECT s.*, u.name as instructor_name
                     FROM training_sessions s
                     JOIN users u ON s.instructor_id = u.user_id
                     WHERE s.session_id = ?""", (session_id,))
        
        new_session = dict(c.fetchone())
        conn.close()
        
        return new_session
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/sessions/active")
async def get_active_sessions(current_instructor: dict = Depends(require_instructor)):
    """Get instructor's active sessions"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        c.execute("""SELECT s.*, u.name as instructor_name,
                     COUNT(DISTINCT st.student_id) as student_count
                     FROM training_sessions s
                     JOIN users u ON s.instructor_id = u.user_id
                     LEFT JOIN students st ON s.session_id = st.session_id
                     WHERE s.instructor_id = ? AND s.status = 'IN_PROGRESS'
                     GROUP BY s.session_id
                     ORDER BY s.created_at DESC""",
                  (current_instructor['user_id'],))
        
        sessions = [dict(row) for row in c.fetchall()]
        conn.close()
        
        return {"sessions": sessions}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/sessions/{session_id}")
async def get_session(session_id: int, current_user: dict = Depends(get_current_user)):
    """Get session details"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        c.execute("""SELECT s.*, u.name as instructor_name
                     FROM training_sessions s
                     JOIN users u ON s.instructor_id = u.user_id
                     WHERE s.session_id = ?""", (session_id,))
        
        session = c.fetchone()
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
        
        session_dict = dict(session)
        
        # Get students in session
        c.execute("""SELECT * FROM students WHERE session_id = ?
                     ORDER BY created_at""", (session_id,))
        students = [dict(row) for row in c.fetchall()]
        
        session_dict['students'] = students
        conn.close()
        
        return session_dict
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# STUDENT MANAGEMENT
# ============================================================================

@app.post("/sessions/{session_id}/students")
async def add_student_to_session(session_id: int, student: StudentCreate,
                                 current_instructor: dict = Depends(require_instructor)):
    """Add a student to a session"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        # Verify session exists and belongs to instructor
        c.execute("SELECT * FROM training_sessions WHERE session_id = ? AND instructor_id = ?",
                  (session_id, current_instructor['user_id']))
        session = c.fetchone()
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
        
        # Insert student
        c.execute("""INSERT INTO students
                     (session_id, name, license_number, email, phone, date_of_birth, bike_type)
                     VALUES (?, ?, ?, ?, ?, ?, ?)""",
                  (session_id, student.name, student.license_number, student.email,
                   student.phone, student.date_of_birth, student.bike_type))
        
        student_id = c.lastrowid
        
        # Get task configuration for this session type
        session_type = session['session_type']
        c.execute("""SELECT * FROM task_configuration
                     WHERE session_type = ? ORDER BY sequence""", (session_type,))
        tasks = c.fetchall()
        
        # Create student tasks
        for task in tasks:
            c.execute("""INSERT INTO student_tasks
                         (student_id, session_type, task_id, task_description, sequence, completed)
                         VALUES (?, ?, ?, ?, ?, 0)""",
                      (student_id, session_type, task['task_id'],
                       task['task_description'], task['sequence']))
        
        conn.commit()
        
        # Get created student with tasks
        c.execute("SELECT * FROM students WHERE student_id = ?", (student_id,))
        new_student = dict(c.fetchone())
        
        c.execute("SELECT * FROM student_tasks WHERE student_id = ? ORDER BY sequence",
                  (student_id,))
        new_student['tasks'] = [dict(row) for row in c.fetchall()]
        
        conn.close()
        
        return new_student
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# FACE VERIFICATION (existing)
# ============================================================================

@app.post("/verify-face")
async def verify_face(student_photo: UploadFile = File(...),
                     license_photo: UploadFile = File(...)):
    """Verify if student photo matches license photo using face cropping for better accuracy"""
    try:
        student_img_data = await student_photo.read()
        license_img_data = await license_photo.read()
        
        student_image = Image.open(io.BytesIO(student_img_data))
        license_image = Image.open(io.BytesIO(license_img_data))
        
        if student_image.mode != 'RGB':
            student_image = student_image.convert('RGB')
        if license_image.mode != 'RGB':
            license_image = license_image.convert('RGB')
        
        student_np = np.array(student_image)
        license_np = np.array(license_image)
        
        # Detect face locations first
        student_face_locations = face_recognition.face_locations(student_np)
        license_face_locations = face_recognition.face_locations(license_np)
        
        if len(student_face_locations) == 0:
            raise HTTPException(status_code=400, detail="No face detected in student photo")
        if len(license_face_locations) == 0:
            raise HTTPException(status_code=400, detail="No face detected in license photo")
        
        # Crop to face area with 20% padding for context
        def crop_face_with_padding(image_np, face_location, padding=0.2):
            top, right, bottom, left = face_location
            height = bottom - top
            width = right - left
            
            # Add padding
            pad_h = int(height * padding)
            pad_w = int(width * padding)
            
            # Calculate padded bounds (ensure within image)
            img_height, img_width = image_np.shape[:2]
            top_padded = max(0, top - pad_h)
            bottom_padded = min(img_height, bottom + pad_h)
            left_padded = max(0, left - pad_w)
            right_padded = min(img_width, right + pad_w)
            
            return image_np[top_padded:bottom_padded, left_padded:right_padded]
        
        # Crop both images to just the face area
        student_face = crop_face_with_padding(student_np, student_face_locations[0])
        license_face = crop_face_with_padding(license_np, license_face_locations[0])
        
        # Get encodings from cropped faces
        student_encodings = face_recognition.face_encodings(student_face)
        license_encodings = face_recognition.face_encodings(license_face)
        
        if len(student_encodings) == 0:
            raise HTTPException(status_code=400, detail="Could not encode student face")
        if len(license_encodings) == 0:
            raise HTTPException(status_code=400, detail="Could not encode license face")
        
        student_encoding = student_encodings[0]
        license_encoding = license_encodings[0]
        
        # Calculate face distance (lower is better match)
        face_distance = face_recognition.face_distance([license_encoding], student_encoding)[0]
        
        # Convert to percentage match
        #face_distance typically 0.0 (perfect) to 1.0 (very different)
        # We use a slightly adjusted scale for better discrimination
        match_score = max(0, min(100, (1 - face_distance) * 100))
        
        # Additional quality metrics
        tolerance = 0.6  # Default tolerance for face_recognition
        is_match = face_distance < tolerance
        
        return {
            "match_score": round(match_score, 2),
            "face_distance": round(face_distance, 3),
            "is_match": is_match,
            "confidence": "high" if face_distance < 0.4 else "medium" if face_distance < 0.6 else "low",
            "status": "success"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Face verification error: {str(e)}")

# ============================================================================
# TASK COMPLETION
# ============================================================================

@app.put("/sessions/{session_id}/tasks/complete")
async def complete_task_for_all(session_id: int, task_data: TaskComplete,
                               current_instructor: dict = Depends(require_instructor)):
    """Complete a task for all students in the session"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        # Verify session
        c.execute("SELECT * FROM training_sessions WHERE session_id = ? AND instructor_id = ?",
                  (session_id, current_instructor['user_id']))
        if not c.fetchone():
            raise HTTPException(status_code=404, detail="Session not found")
        
        # Get all students in session
        c.execute("SELECT student_id FROM students WHERE session_id = ?", (session_id,))
        students = c.fetchall()
        
        timestamp = datetime.now().isoformat() if task_data.completed else None
        
        # Update task for all students
        for student in students:
            c.execute("""UPDATE student_tasks
                         SET completed = ?, completed_at = ?, notes = ?
                         WHERE student_id = ? AND task_id = ?""",
                      (task_data.completed, timestamp, task_data.notes,
                       student['student_id'], task_data.task_id))
        
        conn.commit()
        conn.close()
        
        return {
            "status": "success",
            "students_updated": len(students),
            "task_id": task_data.task_id,
            "completed": task_data.completed
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/students/{student_id}/tasks/{task_id}")
async def update_student_task(student_id: int, task_id: str, task_data: TaskComplete,
                             current_instructor: dict = Depends(require_instructor)):
    """Update a specific student's task (override)"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        timestamp = datetime.now().isoformat() if task_data.completed else None
        
        c.execute("""UPDATE student_tasks
                     SET completed = ?, completed_at = ?, notes = ?, override_reason = ?
                     WHERE student_id = ? AND task_id = ?""",
                  (task_data.completed, timestamp, task_data.notes, task_data.notes,
                   student_id, task_id))
        
        if c.rowcount == 0:
            raise HTTPException(status_code=404, detail="Task not found")
        
        conn.commit()
        
        # Get updated task
        c.execute("SELECT * FROM student_tasks WHERE student_id = ? AND task_id = ?",
                  (student_id, task_id))
        updated_task = dict(c.fetchone())
        conn.close()
        
        return updated_task
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# CERTIFICATE GENERATION (Phase 4)
# ============================================================================

@app.post("/sessions/{session_id}/complete")
async def complete_session(session_id: int,
                          current_instructor: dict = Depends(require_instructor)):
    """Complete a session and generate certificates for passing students"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        # Verify session
        c.execute("""SELECT * FROM training_sessions
                     WHERE session_id = ? AND instructor_id = ?""",
                  (session_id, current_instructor['user_id']))
        session = c.fetchone()
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
        
        # Get all students and their task completion
        c.execute("""SELECT s.*, 
                     COUNT(st.student_task_id) as total_tasks,
                     SUM(CASE WHEN st.completed = 1 THEN 1 ELSE 0 END) as completed_tasks
                     FROM students s
                     LEFT JOIN student_tasks st ON s.student_id = st.student_id
                     WHERE s.session_id = ?
                     GROUP BY s.student_id""", (session_id,))
        
        students = c.fetchall()
        certificates_issued = 0
        
        for student in students:
            # Check if all tasks completed
            if student['total_tasks'] == student['completed_tasks'] and student['total_tasks'] > 0:
                # Get next certificate
                c.execute("""SELECT c.*, cb.certificates_remaining
                             FROM certificates c
                             JOIN certificate_batches cb ON c.batch_id = cb.batch_id
                             WHERE c.session_type = ? AND c.status = 'AVAILABLE'
                             AND cb.company_id = ? AND cb.status = 'ACTIVE'
                             ORDER BY c.certificate_number
                             LIMIT 1""",
                          (session['session_type'], current_instructor['company_id']))
                
                cert = c.fetchone()
                if cert:
                    # Issue certificate
                    c.execute("""UPDATE certificates
                                 SET student_id = ?, session_id = ?, instructor_id = ?,
                                 issue_date = ?, status = 'ISSUED'
                                 WHERE certificate_id = ?""",
                              (student['student_id'], session_id,
                               current_instructor['user_id'],
                               datetime.now().isoformat(), cert['certificate_id']))
                    
                    # Update student outcome
                    c.execute("UPDATE students SET training_outcome = 'PASS' WHERE student_id = ?",
                              (student['student_id'],))
                    
                    certificates_issued += 1
                else:
                    # No certificates available
                    c.execute("UPDATE students SET training_outcome = 'INCOMPLETE' WHERE student_id = ?",
                              (student['student_id'],))
            else:
                # Not all tasks completed
                c.execute("UPDATE students SET training_outcome = 'INCOMPLETE' WHERE student_id = ?",
                          (student['student_id'],))
        
        # Mark session as completed
        c.execute("""UPDATE training_sessions
                     SET status = 'COMPLETED', completed_at = ?
                     WHERE session_id = ?""",
                  (datetime.now().isoformat(), session_id))
        
        conn.commit()
        conn.close()
        
        return {
            "status": "success",
            "session_id": session_id,
            "total_students": len(students),
            "certificates_issued": certificates_issued
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# STATISTICS & REPORTS
# ============================================================================

@app.get("/stats")
async def get_statistics(current_user: dict = Depends(get_current_user)):
    """Get training statistics"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        # Total students
        c.execute('SELECT COUNT(*) as count FROM students')
        total_students = c.fetchone()['count']
        
        # Verified students
        c.execute('SELECT COUNT(*) as count FROM students WHERE verified = 1')
        verified_students = c.fetchone()['count']
        
        # Students today
        today = datetime.now().strftime('%Y-%m-%d')
        c.execute('SELECT COUNT(*) as count FROM students WHERE created_at LIKE ?', (f'{today}%',))
        students_today = c.fetchone()['count']
        
        # Average match score
        c.execute('SELECT AVG(match_score) as avg FROM students WHERE match_score IS NOT NULL')
        avg_result = c.fetchone()
        avg_match = avg_result['avg'] if avg_result['avg'] is not None else 0
        
        # Certificates issued
        c.execute('SELECT COUNT(*) as count FROM certificates WHERE status = "ISSUED"')
        certs_issued = c.fetchone()['count']
        
        # Active sessions
        c.execute('SELECT COUNT(*) as count FROM training_sessions WHERE status = "IN_PROGRESS"')
        active_sessions = c.fetchone()['count']
        
        conn.close()
        
        return {
            "total_students": total_students,
            "verified_students": verified_students,
            "students_today": students_today,
            "average_match_score": round(avg_match, 2),
            "certificates_issued": certs_issued,
            "active_sessions": active_sessions
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Statistics error: {str(e)}")

@app.get("/admin/users")
async def get_all_users(current_admin: dict = Depends(require_admin)):
    """Get all users (admin only)"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        c.execute("""SELECT user_id, name, email, is_admin, is_instructor, 
                     instructor_certificate_number, phone, status, created_at, last_login
                     FROM users WHERE company_id = ?
                     ORDER BY created_at DESC""",
                  (current_admin['company_id'],))
        
        users = [dict(row) for row in c.fetchall()]
        conn.close()
        
        return {"users": users}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin/sessions/all")
async def get_all_sessions(current_admin: dict = Depends(require_admin)):
    """Get all sessions across all instructors (admin only)"""
    try:
        conn = get_db()
        c = conn.cursor()
        
        c.execute("""SELECT s.*, u.name as instructor_name,
                     COUNT(DISTINCT st.student_id) as student_count
                     FROM training_sessions s
                     JOIN users u ON s.instructor_id = u.user_id
                     LEFT JOIN students st ON s.session_id = st.session_id
                     WHERE s.company_id = ?
                     GROUP BY s.session_id
                     ORDER BY s.created_at DESC""",
                  (current_admin['company_id'],))
        
        sessions = [dict(row) for row in c.fetchall()]
        conn.close()
        
        return {"sessions": sessions}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    print("Starting Motorcycle Training Backend API...")
    print("Access API at: http://localhost:8000")
    print("API docs at: http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000)