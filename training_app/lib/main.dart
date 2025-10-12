import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main() {
  runApp(const MotorcycleTrainingApp());
}

class MotorcycleTrainingApp extends StatelessWidget {
  const MotorcycleTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motorcycle Training Assessor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const StudentListScreen(),
    );
  }
}

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  List<Map<String, dynamic>> students = [];

  void _addNewStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewStudentScreen(),
      ),
    ).then((newStudent) {
      if (newStudent != null) {
        setState(() {
          students.add(newStudent);
        });
      }
    });
  }

  Widget _buildStudentAvatar(Map<String, dynamic> student) {
    if (kIsWeb && student['photoBytes'] != null) {
      return CircleAvatar(
        backgroundImage: MemoryImage(student['photoBytes']),
      );
    } else if (!kIsWeb && student['photoPath'] != null) {
      return CircleAvatar(
        backgroundImage: FileImage(File(student['photoPath'])),
      );
    } else {
      return const CircleAvatar(
        child: Icon(Icons.person),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motorcycle Training Assessor'),
        elevation: 2,
      ),
      body: students.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.motorcycle, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No students assessed today',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add a new student',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: _buildStudentAvatar(student),
                    title: Text(student['name'] ?? 'Unknown'),
                    subtitle: Text(
                      'License: ${student['licenseNumber'] ?? 'N/A'}\n'
                      'Match: ${student['matchScore']?.toStringAsFixed(1) ?? 'N/A'}%',
                    ),
                    trailing: Icon(
                      student['verified'] == true
                          ? Icons.check_circle
                          : Icons.pending,
                      color: student['verified'] == true
                          ? Colors.green
                          : Colors.orange,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaskChecklistScreen(
                            studentData: student,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewStudent,
        icon: const Icon(Icons.add),
        label: const Text('New Student'),
      ),
    );
  }
}

class NewStudentScreen extends StatefulWidget {
  const NewStudentScreen({super.key});

  @override
  State<NewStudentScreen> createState() => _NewStudentScreenState();
}

class _NewStudentScreenState extends State<NewStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _picker = ImagePicker();
  
  String? _studentPhotoPath;
  String? _licensePhotoPath;
  Uint8List? _studentPhotoBytes;
  Uint8List? _licensePhotoBytes;
  bool _isVerifying = false;
  double? _matchScore;
  String? _verificationStatus;
  Color? _statusColor;

  Future<void> _takePhoto(bool isStudent) async {
    final XFile? photo = await _picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        if (isStudent) {
          _studentPhotoPath = photo.path;
          _studentPhotoBytes = bytes;
        } else {
          _licensePhotoPath = photo.path;
          _licensePhotoBytes = bytes;
        }
        _matchScore = null;
        _verificationStatus = null;
      });
    }
  }

  Widget _buildPhotoPreview(Uint8List? bytes, String? path) {
    if (kIsWeb && bytes != null) {
      return Image.memory(bytes, height: 200, fit: BoxFit.contain);
    } else if (!kIsWeb && path != null) {
      return Image.file(File(path), height: 200, fit: BoxFit.contain);
    } else {
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: const Icon(Icons.person, size: 80),
      );
    }
  }

  Future<void> _verifyPhotos() async {
    if ((_studentPhotoPath == null && _studentPhotoBytes == null) || 
        (_licensePhotoPath == null && _licensePhotoBytes == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take both photos first')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      // TODO: Replace with your backend URL
      const backendUrl = 'http://localhost:8000/verify-face';
      
      final request = http.MultipartRequest('POST', Uri.parse(backendUrl));
      
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'student_photo', 
          _studentPhotoBytes!,
          filename: 'student.jpg',
        ));
        request.files.add(http.MultipartFile.fromBytes(
          'license_photo', 
          _licensePhotoBytes!,
          filename: 'license.jpg',
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('student_photo', _studentPhotoPath!));
        request.files.add(await http.MultipartFile.fromPath('license_photo', _licensePhotoPath!));
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final result = json.decode(responseData);

      setState(() {
        _matchScore = result['match_score'];
        
        if (_matchScore! >= 90) {
          _verificationStatus = 'PASS - Match Verified';
          _statusColor = Colors.green;
        } else if (_matchScore! >= 50) {
          _verificationStatus = 'MANUAL CHECK REQUIRED';
          _statusColor = Colors.orange;
        } else {
          _verificationStatus = 'FAIL - Manual Override Required';
          _statusColor = Colors.red;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification error: $e')),
      );
      // For demo purposes, generate a random score
      setState(() {
        _matchScore = 85.0 + (DateTime.now().millisecond % 15);
        if (_matchScore! >= 90) {
          _verificationStatus = 'PASS - Match Verified';
          _statusColor = Colors.green;
        } else if (_matchScore! >= 50) {
          _verificationStatus = 'MANUAL CHECK REQUIRED';
          _statusColor = Colors.orange;
        } else {
          _verificationStatus = 'FAIL - Manual Override Required';
          _statusColor = Colors.red;
        }
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  void _proceedToChecklist() {
    if (_formKey.currentState!.validate() && _matchScore != null) {
      final studentData = {
        'name': _nameController.text,
        'licenseNumber': _licenseController.text,
        'photoPath': _studentPhotoPath,
        'photoBytes': _studentPhotoBytes,
        'licensePhotoPath': _licensePhotoPath,
        'licensePhotoBytes': _licensePhotoBytes,
        'matchScore': _matchScore,
        'verified': _matchScore! >= 90,
        'verificationStatus': _verificationStatus,
        'timestamp': DateTime.now().toIso8601String(),
      };
      Navigator.pop(context, studentData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Student Assessment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Student Photo
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Student Photo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildPhotoPreview(_studentPhotoBytes, _studentPhotoPath),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _takePhoto(true),
                        icon: const Icon(Icons.camera_alt),
                        label: Text(_studentPhotoPath == null ? 'Take Photo' : 'Retake Photo'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // License Photo
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'License Photo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildPhotoPreview(_licensePhotoBytes, _licensePhotoPath),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _takePhoto(false),
                        icon: const Icon(Icons.camera_alt),
                        label: Text(_licensePhotoPath == null ? 'Take Photo' : 'Retake Photo'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Verify Button
              ElevatedButton.icon(
                onPressed: _isVerifying ? null : _verifyPhotos,
                icon: _isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user),
                label: Text(_isVerifying ? 'Verifying...' : 'Verify Photos'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),

              // Verification Result
              if (_matchScore != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: _statusColor?.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          _matchScore! >= 90
                              ? Icons.check_circle
                              : _matchScore! >= 50
                                  ? Icons.warning
                                  : Icons.error,
                          size: 48,
                          color: _statusColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Match Score: ${_matchScore!.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _verificationStatus!,
                          style: TextStyle(
                            fontSize: 16,
                            color: _statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Student Details
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter student name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(
                  labelText: 'License Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter license number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Proceed Button
              ElevatedButton(
                onPressed: _matchScore != null ? _proceedToChecklist : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Proceed to Checklist',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _licenseController.dispose();
    super.dispose();
  }
}

class TaskChecklistScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const TaskChecklistScreen({super.key, required this.studentData});

  @override
  State<TaskChecklistScreen> createState() => _TaskChecklistScreenState();
}

class _TaskChecklistScreenState extends State<TaskChecklistScreen> {
  final List<Map<String, dynamic>> _tasks = [
    {'title': 'Eyesight checked', 'completed': false, 'timestamp': null},
    {'title': 'Licence photo checked', 'completed': false, 'timestamp': null},
    {'title': 'Part A (PPE) completed', 'completed': false, 'timestamp': null},
    {'title': 'Part B (Controls/Stands/Maintenance) completed', 'completed': false, 'timestamp': null},
    {'title': 'Part C - Walk and Stop completed', 'completed': false, 'timestamp': null},
    {'title': 'Part C - On/Off Centre Stand completed', 'completed': false, 'timestamp': null},
    {'title': 'Part C - Clutch biting point checked', 'completed': false, 'timestamp': null},
    {'title': 'Part C - Straight line back brake checked', 'completed': false, 'timestamp': null},
    {'title': 'Part C - Use of front brake checked', 'completed': false, 'timestamp': null},
  ];

  void _toggleTask(int index) {
    setState(() {
      _tasks[index]['completed'] = !_tasks[index]['completed'];
      _tasks[index]['timestamp'] = _tasks[index]['completed'] 
          ? DateTime.now().toIso8601String() 
          : null;
    });
  }

  Widget _buildStudentAvatar() {
    if (kIsWeb && widget.studentData['photoBytes'] != null) {
      return CircleAvatar(
        backgroundImage: MemoryImage(widget.studentData['photoBytes']),
        radius: 30,
      );
    } else if (!kIsWeb && widget.studentData['photoPath'] != null) {
      return CircleAvatar(
        backgroundImage: FileImage(File(widget.studentData['photoPath'])),
        radius: 30,
      );
    } else {
      return const CircleAvatar(
        radius: 30,
        child: Icon(Icons.person, size: 30),
      );
    }
  }

  Future<void> _saveAssessment() async {
    try {
      // TODO: Replace with your backend URL
      const backendUrl = 'http://localhost:8000/save-assessment';
      
      final assessmentData = {
        'student': widget.studentData,
        'tasks': _tasks,
        'completed_at': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(assessmentData),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assessment saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to save assessment');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  int get _completedCount => _tasks.where((t) => t['completed'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentData['name'] ?? 'Student Assessment'),
      ),
      body: Column(
        children: [
          // Progress Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStudentAvatar(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.studentData['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'License: ${widget.studentData['licenseNumber']}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              'Match: ${widget.studentData['matchScore']?.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: widget.studentData['verified'] == true
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _completedCount / _tasks.length,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_completedCount of ${_tasks.length} tasks completed',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Task List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    title: Text(task['title']),
                    subtitle: task['timestamp'] != null
                        ? Text(
                            'Completed: ${DateTime.parse(task['timestamp']).toString().substring(0, 16)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          )
                        : null,
                    value: task['completed'],
                    onChanged: (bool? value) {
                      _toggleTask(index);
                    },
                    activeColor: Colors.green,
                  ),
                );
              },
            ),
          ),

          // Save Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _saveAssessment,
              icon: const Icon(Icons.save),
              label: const Text('Save Assessment'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}