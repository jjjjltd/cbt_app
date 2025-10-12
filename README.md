# Motorcycle Training Management System

A complete multi-user mobile and web application for UK motorcycle training companies to manage instructors, students, training sessions, and certificate issuance with AI-powered identity verification.

---

## 📋 Table of Contents

- [Current Status](#current-status)
- [System Overview](#system-overview)
- [Features Completed](#features-completed)
- [Features In Progress](#features-in-progress)
- [Installation Guide](#installation-guide)
- [Database Schema](#database-schema)
- [API Documentation](#api-documentation)
- [Usage Guide](#usage-guide)
- [Roadmap](#roadmap)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Current Status

### ✅ **Completed:**
1. **Database Schema** - Complete SQL schema with all tables, relationships, indexes, and seed data
2. **Flutter App (Basic)** - Working Chrome web version with:
   - Photo capture/upload functionality
   - Student verification interface
   - Task checklist with timestamps
   - Basic navigation flow
3. **Python Backend (Basic)** - Initial API structure with face verification endpoint

### 🔨 **In Progress:**
1. User authentication system (Admin & Instructor login)
2. Certificate batch management
3. Session management with multi-student support
4. Group task completion with override capability

### 📅 **Planned:**
1. PDF certificate generation with digital signatures
2. Email delivery system
3. Android/iOS mobile deployment
4. Advanced reporting and analytics

---

## 🏗️ System Overview

### **Architecture:**
```
Flutter App (Mobile + Web)
    ↓
FastAPI Backend (Python)
    ↓
SQLite Database
```

### **User Roles:**
- **Admin:** Manage company details, certificate batches, instructors, configure session types
- **Instructor:** Create sessions, verify students, complete training, issue certificates
- **System:** Automated certificate tracking, verification, email delivery

### **Core Workflow:**
```
1. Admin sets up company & certificate batches
2. Instructor starts training session
3. Students added to session with photo verification
4. Tasks completed (group or individual)
5. Certificates issued automatically
6. PDFs emailed to successful students
```

---

## ✨ Features Completed

### **Student Identity Verification**
- ✅ Photo capture (student + license)
- ✅ AI face matching with confidence scores
- ✅ Automatic pass/fail/manual-check thresholds:
  - **>90%** = Automatic pass
  - **50-89%** = Manual verification required
  - **<50%** = Fail (manual override available)

### **Task Management**
- ✅ Configurable task lists by session type
- ✅ 9 default CBT tasks pre-configured
- ✅ Individual task completion with timestamps
- ✅ Progress tracking

### **Web Compatibility**
- ✅ Works in Chrome browser
- ✅ File upload for testing
- ✅ Cross-platform image handling

---

## 🔨 Features In Progress

### **Multi-User Authentication**
- User registration (Admin & Instructor)
- Secure login with JWT tokens
- Role-based access control
- Session management

### **Certificate Batch Management**
- Admin can add certificate batches
- Enter first certificate number → auto-generates 25 sequential certificates
- Automatic tracking of available/issued certificates
- Low inventory alerts

### **Training Session Management**
- Quick session start (dropdown + Start button)
- Multiple sessions per day support
- Session-level task completion (applies to all students)
- Individual student override capability

### **Student Management**
- Add multiple students to a session
- License data extraction and validation
- Group operations with individual exceptions
- Training outcome tracking (Pass/Fail/Incomplete)

---

## 🚀 Installation Guide

### **Prerequisites**
- **Python 3.8+** with pip
- **Flutter SDK 3.0+**
- **VSCode** with Flutter extension
- **Chrome browser** (for web testing)

---

### **Part 1: Database Setup**

1. **Create project structure:**
```bash
mkdir motorcycle-training
cd motorcycle-training
mkdir backend
```

2. **Save the database schema:**
- Copy `schema.sql` artifact to `backend/schema.sql`

3. **Initialize database:**
```bash
cd backend
sqlite3 training.db < schema.sql
```

This creates `training.db` with all tables and seed data.

---

### **Part 2: Python Backend Setup**

1. **Create `requirements.txt` in the backend folder:**
```txt
fastapi==0.104.1
uvicorn==0.24.0
face-recognition==1.3.0
Pillow==10.1.0
numpy==1.24.3
python-multipart==0.0.6
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-dateutil==2.8.2
```

2. **Install dependencies:**
```bash
# Windows
pip install -r requirements.txt

# Mac/Linux
pip3 install -r requirements.txt
```

**Mac M1/M2 users:**
```bash
brew install cmake
pip3 install dlib
pip3 install face-recognition
```

3. **Save Python backend code:**
- Copy `main.py` artifact to `backend/main.py`

4. **Run the backend:**
```bash
# Windows
python main.py

# Mac/Linux
python3 main.py
```

**You should see:**
```
Starting Motorcycle Training Backend API...
Access API at: http://localhost:8000
API docs at: http://localhost:8000/docs
```

**Keep this terminal running!**

---

### **Part 3: Flutter App Setup**

1. **Create Flutter project:**
```bash
cd ..  # Back to motorcycle-training folder
flutter create training_app
cd training_app
```

2. **Update `pubspec.yaml`:**

Add these dependencies:
```yaml
dependencies:
  flutter:
    sdk: flutter
  image_picker: ^1.0.4
  http: ^1.1.0
```

3. **Install dependencies:**
```bash
flutter pub get
```

4. **Replace `lib/main.dart`:**
- Delete contents of `lib/main.dart`
- Copy Flutter app code from artifact
- Save file

5. **Update backend URL (if needed):**

In `lib/main.dart`, find and update these lines:
```dart
const backendUrl = 'http://localhost:8000/verify-face';  // Line ~162
const backendUrl = 'http://localhost:8000/save-assessment';  // Line ~386
```

**For Android emulator:** Use `http://10.0.2.2:8000`
**For iOS simulator:** Use your Mac's IP address
**For physical device:** Use your computer's IP on same WiFi

6. **Run the app:**
```bash
flutter run -d chrome
```

The app will open in Chrome!

---

## 💾 Database Schema

### **Key Tables:**

#### **training_company**
Stores company information, training body reference, official stamp image

#### **users**
Combined table for admins and instructors with boolean flags:
- `is_admin` - Can manage company, certificates, instructors
- `is_instructor` - Can create sessions, verify students, issue certificates

#### **session_types**
Pre-defined training types: CBT, MODULE_1, MODULE_2, DAS, A2

#### **task_configuration**
Configurable tasks per session type with sequence order

#### **training_sessions**
Individual training sessions with date, instructor, type, status

#### **students**
Student records with license details, photos, verification results

#### **student_tasks**
Task completion tracking with timestamps and override capability

#### **certificate_batches**
Certificate inventory management (batches of 25)

#### **certificates**
Individual certificate tracking from available → issued

#### **certificate_emails**
Email delivery tracking for sent certificates

#### **audit_log**
Complete audit trail of system changes

### **Default Login:**
- **Email:** admin@example.com
- **Password:** admin123
- ⚠️ **CHANGE IMMEDIATELY!**

---

## 📡 API Documentation

### **Current Endpoints:**

#### **Identity Verification**
```
POST /verify-face
- Uploads: student_photo, license_photo
- Returns: match_score (0-100%)
```

#### **Assessment Storage**
```
POST /save-assessment
- Body: student data + completed tasks
- Returns: success status
```

#### **Statistics**
```
GET /stats
- Returns: student counts, average match scores
```

### **Coming Soon:**

- `POST /auth/register` - User registration
- `POST /auth/login` - User login (returns JWT)
- `GET /auth/me` - Current user info
- `POST /certificates/batch` - Add certificate batch
- `GET /certificates/next` - Get next available certificate
- `POST /sessions` - Create training session
- `POST /sessions/{id}/students` - Add student to session
- `PUT /sessions/{id}/tasks/complete` - Complete task for all students
- `PUT /students/{id}/tasks/{task_id}` - Override individual task

Full API docs available at: `http://localhost:8000/docs`

---

## 📱 Usage Guide

### **Current Demo Flow (Chrome):**

1. **Open the app** in Chrome
2. **Click "+ New Student"**
3. **Upload photos:**
   - Click "Take Photo" under Student Photo (choose file)
   - Click "Take Photo" under License Photo (choose file)
4. **Verify identity:**
   - Click "Verify Photos"
   - See match score and status
5. **Enter details:**
   - Student name
   - License number
6. **Click "Proceed to Checklist"**
7. **Complete tasks:**
   - Check off each task as completed
   - See progress bar update
8. **Click "Save Assessment"**

### **Coming Soon - Full Workflow:**

#### **Admin First-Time Setup:**
1. Login as admin
2. Update company details
3. Upload official stamp image
4. Add certificate batch (enter first number)
5. Create/invite instructors

#### **Instructor Daily Use:**
1. Login
2. Start training session (select type, location)
3. Add students to session
4. Verify each student's identity
5. Complete tasks (applies to all students)
6. Override individual student tasks if needed
7. Review and finalize session
8. Certificates auto-issued and emailed

---

## 🗺️ Roadmap

### **Phase 1: Authentication & Users** (Next)
- [ ] User registration/login screens
- [ ] JWT token authentication
- [ ] Admin dashboard
- [ ] Instructor dashboard
- [ ] Role-based routing

### **Phase 2: Certificate Management**
- [ ] Add certificate batch interface
- [ ] Certificate inventory display
- [ ] Low stock alerts
- [ ] Certificate assignment to students

### **Phase 3: Session Management**
- [ ] Quick session start screen
- [ ] Multi-student addition
- [ ] Group task completion
- [ ] Individual task override
- [ ] Session completion workflow

### **Phase 4: Certificate Generation**
- [ ] PDF generation from DL196 template
- [ ] Digital signature integration
- [ ] QR code generation
- [ ] Verification page

### **Phase 5: Email & Delivery**
- [ ] Email configuration
- [ ] Automated certificate sending
- [ ] Delivery tracking
- [ ] Resend capability

### **Phase 6: Mobile Deployment**
- [ ] Android build configuration
- [ ] iOS build configuration
- [ ] App store preparation
- [ ] Mobile-specific optimizations

### **Phase 7: Advanced Features**
- [ ] Advanced reporting
- [ ] Data export (Excel, PDF)
- [ ] Instructor performance analytics
- [ ] Cloud database migration option
- [ ] Offline mode with sync
- [ ] Push notifications

---

## 🐛 Troubleshooting

### **Backend Won't Start**

**Issue:** `ModuleNotFoundError` or import errors
**Fix:**
```bash
pip install -r requirements.txt --upgrade
```

**Issue:** Face recognition installation fails (Mac M1/M2)
**Fix:**
```bash
brew install cmake
pip3 install dlib
pip3 install face-recognition
```

### **Flutter Build Errors**

**Issue:** `Flutter failed to delete directory at "build\flutter_assets"`
**Fix:**
```bash
# Close all Chrome windows
# Stop Flutter (Ctrl+C)
flutter clean
flutter pub get
flutter run -d chrome
```

**Issue:** Project in OneDrive causing issues
**Fix:** Move project to `C:\Projects\` or similar non-synced location

**Issue:** `Image.file is not supported on Flutter Web`
**Fix:** This is already handled in the latest artifact code using `kIsWeb` checks

### **Cannot Connect to Backend**

**Issue:** Flutter app can't reach `http://localhost:8000`

**For Web (Chrome):** Should work as-is

**For Android Emulator:**
```dart
const backendUrl = 'http://10.0.2.2:8000/verify-face';
```

**For iOS Simulator:** Use your Mac's IP:
```dart
const backendUrl = 'http://192.168.1.XXX:8000/verify-face';
```

**For Physical Device:** Use computer's IP on same WiFi network

### **Face Verification Not Accurate**

**Current Status:** Without backend running, demo mode generates random scores.

**To get real verification:**
1. Ensure Python backend is running
2. Check backend URL in Flutter code is correct
3. Backend must have `face-recognition` library installed
4. Test with clear, well-lit photos

---

## 📊 Database Management

### **View Database:**
```bash
cd backend
sqlite3 training.db
```

**Useful commands:**
```sql
-- List all tables
.tables

-- See table structure
.schema users

-- Query data
SELECT * FROM users;
SELECT * FROM session_types;
SELECT * FROM task_configuration WHERE session_type = 'CBT';

-- Exit
.quit
```

### **Backup Database:**
```bash
cp training.db training.db.backup
```

### **Reset Database:**
```bash
rm training.db
sqlite3 training.db < schema.sql
```

---

## 🔒 Security Notes

### **Current Implementation:**
- ⚠️ Default admin password must be changed
- ⚠️ SSL/TLS not configured (use HTTPS in production)
- ⚠️ JWT secret key should be environment variable
- ⚠️ File uploads need validation
- ⚠️ Rate limiting not implemented

### **Production Recommendations:**
- Use environment variables for secrets
- Enable HTTPS/SSL certificates
- Implement rate limiting
- Add request validation
- Set up proper file storage (S3, etc.)
- Use PostgreSQL instead of SQLite
- Enable database backups
- Implement logging and monitoring
- Add CORS restrictions
- Use secure password policies

---

## 📞 Support & Development

### **Getting Help:**
1. Check this README
2. Review terminal error messages
3. Check browser console (F12)
4. Verify backend is running
5. Check database schema matches code

### **Current Development Environment:**
- **OS:** Windows 10/11
- **IDE:** VSCode with Flutter extension
- **Testing:** Chrome web browser
- **Database:** SQLite 3
- **Python:** 3.8+
- **Flutter:** 3.0+

---

## 📝 Version History

### **v0.2.0 (Current - In Progress)**
- Complete database schema with all tables
- Multi-user authentication system
- Certificate batch management
- Session and student management
- Group task completion

### **v0.1.0 (Completed)**
- Basic Flutter web app
- Photo upload and verification UI
- Individual student assessment
- Task checklist with timestamps
- Basic Python backend
- Face recognition integration

---

## 🤝 Contributing

This is a custom application built for UK motorcycle instructor training assessment. 

**Development approach:** Incremental builds with testing at each stage.

**Current focus:** Building core authentication and session management features.

---

## 📄 License

Custom application for motorcycle training management.

---

## 🙏 Acknowledgments

- Built with Flutter for cross-platform support
- FastAPI for high-performance backend
- face-recognition library for AI verification
- SQLite for reliable data storage

---

**Last Updated:** December 2024
**Status:** Active Development
**Next Milestone:** User Authentication & Certificate Batch Management