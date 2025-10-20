import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'student_tasks_screen.dart';
import 'student_photo_capture_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  final AuthService authService;
  final int sessionId;

  const SessionDetailScreen({
    super.key,
    required this.authService,
    required this.sessionId,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late ApiService _apiService;
  Map<String, dynamic>? _session;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.authService);
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() => _isLoading = true);

    final result = await _apiService.getSession(widget.sessionId);

    if (result['success']) {
      setState(() {
        _session = result['data'];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'])),
        );
      }
    }
  }

  Future<void> _navigateToPhotoCaptureScreen() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => StudentPhotoCaptureScreen(
        sessionId: widget.sessionId,
      ),
    ),
  );

  if (result != null) {
    // Photos captured and verified, now show data entry dialog
    _showDataEntryDialog(result);
  }
}

void _showDataEntryDialog(Map<String, dynamic> photoData) {
  final nameController = TextEditingController();
  final licenseController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  String bikeType = 'Manual';

  // TODO: Run OCR here and pre-fill controllers
  // For now, show empty form

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Confirm Student Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show verification status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Face Match: ${photoData['match_score'].toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter or verify name from OCR',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: licenseController,
                decoration: const InputDecoration(
                  labelText: 'License Number *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter or verify from OCR',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: bikeType,
                decoration: const InputDecoration(
                  labelText: 'Bike Type',
                  border: OutlineInputBorder(),
                ),
                items: ['Manual', 'Automatic'].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    bikeType = value!;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  licenseController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Name and License Number required')),
                );
                return;
              }

              Navigator.pop(context);

              final result = await _apiService.addStudentToSession(
                sessionId: widget.sessionId,
                name: nameController.text,
                licenseNumber: licenseController.text,
                email: emailController.text.isEmpty
                    ? null
                    : emailController.text,
                phone: phoneController.text.isEmpty
                    ? null
                    : phoneController.text,
                bikeType: bikeType,
              );

              if (result['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadSession();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['error']),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Add Student'),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _completeSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Session'),
        content: const Text(
          'Are you sure you want to complete this session? '
          'Certificates will be automatically issued to students who passed all tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete Session'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await _apiService.completeSession(widget.sessionId);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session completed! ${result['data']['certificates_issued']} certificates issued.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final students = _session!['students'] as List<dynamic>? ?? [];
    final sessionType = _session!['session_type'] ?? 'Unknown';
    final location = _session!['location'] ?? 'Not specified';

    return Scaffold(
      appBar: AppBar(
        title: Text(sessionType),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSession,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSession,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sessionType,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.location_on, location),
                      _buildInfoRow(Icons.calendar_today,
                          _session!['session_date'] ?? ''),
                      _buildInfoRow(
                          Icons.person, _session!['instructor_name'] ?? ''),
                      if (_session!['site_code'] != null)
                        _buildInfoRow(
                            Icons.tag, 'Site: ${_session!['site_code']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Students Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Students (${students.length})',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _navigateToPhotoCaptureScreen,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (students.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.people_outline,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No students added yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...(students.map((student) => _buildStudentCard(student))),

              const SizedBox(height: 24),

              // Task Management Button
              if (students.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentTasksScreen(
                            authService: widget.authService,
                            sessionId: widget.sessionId,
                            students: students,
                          ),
                        ),
                      );
                      _loadSession();
                    },
                    icon: const Icon(Icons.checklist),
                    label: const Text('Manage Tasks'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Complete Session Button
              if (students.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _completeSession,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete Session'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final tasks = student['tasks'] as List<dynamic>? ?? [];
    final completedCount = tasks.where((t) => t['completed'] == true).length;
    final totalTasks = tasks.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(student['name'][0].toUpperCase()),
        ),
        title: Text(student['name']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('License: ${student['license_number']}'),
            if (totalTasks > 0)
              Text(
                'Tasks: $completedCount / $totalTasks completed',
                style: TextStyle(
                  color: completedCount == totalTasks
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Icon(
          completedCount == totalTasks && totalTasks > 0
              ? Icons.check_circle
              : Icons.pending,
          color: completedCount == totalTasks && totalTasks > 0
              ? Colors.green
              : Colors.orange,
        ),
      ),
    );
  }
}