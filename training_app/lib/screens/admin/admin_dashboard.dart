import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import 'register_user_screen.dart';
import 'add_certificate_batch_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'manage_tasks_screen.dart';
import 'company_settings_screen.dart';

class AdminDashboard extends StatefulWidget {
  final AuthService authService;

  const AdminDashboard({super.key, required this.authService});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late ApiService _apiService;

  // Data
  List<dynamic> _users = [];
  List<dynamic> _certificateBatches = [];
  Map<String, List<dynamic>> _tasksByType = {};

  // Loading states
  bool _isLoadingUsers = false;
  bool _isLoadingCerts = false;
  bool _isLoadingTasks = false;

  // Expansion states
  bool _usersExpanded = false;
  bool _certsExpanded = false;
  bool _tasksExpanded = false;
  final Map<String, bool> _taskTypeExpanded = {};

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.authService);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    _loadUsers();
    _loadCertificates();
    _loadTasks();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/admin/users'),
        headers: widget.authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _users = data['users'] ?? [];
          _isLoadingUsers = false;
        });
      } else {
        setState(() => _isLoadingUsers = false);
      }
    } catch (e) {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _loadCertificates() async {
    setState(() => _isLoadingCerts = true);

    final result = await _apiService.getCertificateInventory();

    if (result['success']) {
      setState(() {
        _certificateBatches = result['data']['batches'] ?? [];
        _isLoadingCerts = false;
      });
    } else {
      setState(() => _isLoadingCerts = false);
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoadingTasks = true);

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/admin/tasks'),
        headers: widget.authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tasks = data['tasks'] as List<dynamic>? ?? [];

        // Group by session type
        final Map<String, List<dynamic>> grouped = {};
        for (var task in tasks) {
          final type = task['session_type'] ?? 'Unknown';
          if (!grouped.containsKey(type)) {
            grouped[type] = [];
          }
          grouped[type]!.add(task);
        }

        setState(() {
          _tasksByType = grouped;
          _isLoadingTasks = false;
        });
      } else {
        setState(() => _isLoadingTasks = false);
      }
    } catch (e) {
      setState(() => _isLoadingTasks = false);
    }
  }

  int get _activeUserCount =>
      _users.where((u) => u['status'] == 'ACTIVE').length;

  int get _activeBatchCount =>
      _certificateBatches.where((b) => b['status'] == 'ACTIVE').length;

  int get _totalCertsRemaining => _certificateBatches
      .where((b) => b['status'] == 'ACTIVE')
      .fold<int>(
        0,
        (sum, b) => sum + ((b['certificates_remaining'] ?? 0) as int),
      );

  void _logout() {
    widget.authService.logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => LoginScreen(authService: widget.authService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        child: Icon(Icons.admin_panel_settings, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${user?.name ?? 'Admin'}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user?.email ?? '',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Begin insertion
              const SizedBox(height: 24),

              // Quick Settings
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CompanySettingsScreen(
                              authService: widget.authService,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.business),
                      label: const Text('Company Settings'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              //End insertion
              const SizedBox(height: 24),

              // Users Expansion Panel
              _buildUsersPanel(),
              const SizedBox(height: 12),

              // Certificates Expansion Panel
              _buildCertificatesPanel(),
              const SizedBox(height: 12),

              // Tasks Expansion Panel
              _buildTasksPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersPanel() {
    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.people, color: Colors.blue),
            const SizedBox(width: 12),
            const Text(
              'Users',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (!_isLoadingUsers)
              Chip(
                label: Text(
                  '$_activeUserCount Active',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.blue.shade100,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        trailing: _isLoadingUsers
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        initiallyExpanded: _usersExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _usersExpanded = expanded);
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._users
                    .where((u) => u['status'] == 'ACTIVE')
                    .map((user) => _buildUserTile(user)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RegisterUserScreen(authService: widget.authService),
                      ),
                    );
                    _loadUsers();
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final isAdmin = user['is_admin'] == 1 || user['is_admin'] == true;
    final isInstructor =
        user['is_instructor'] == 1 || user['is_instructor'] == true;

    String role = '';
    Color roleColor = Colors.grey;
    if (isAdmin && isInstructor) {
      role = 'Admin + Instructor';
      roleColor = Colors.purple;
    } else if (isAdmin) {
      role = 'Admin';
      roleColor = Colors.red;
    } else if (isInstructor) {
      role = 'Instructor';
      roleColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor,
          child: Text(
            user['name'][0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(user['name']),
        subtitle: Text(user['email']),
        trailing: Chip(
          label: Text(
            role,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
          backgroundColor: roleColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildCertificatesPanel() {
    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.confirmation_number, color: Colors.green),
            const SizedBox(width: 12),
            const Text(
              'Certificates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (!_isLoadingCerts)
              Chip(
                label: Text(
                  '$_activeBatchCount Batches, $_totalCertsRemaining Certs',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.green.shade100,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        trailing: _isLoadingCerts
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        initiallyExpanded: _certsExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _certsExpanded = expanded);
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._certificateBatches
                    .where((b) => b['status'] == 'ACTIVE')
                    .map((batch) => _buildCertBatchTile(batch)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddCertificateBatchScreen(
                          authService: widget.authService,
                        ),
                      ),
                    );
                    _loadCertificates();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Certificate Batch'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertBatchTile(Map<String, dynamic> batch) {
    final remaining = batch['certificates_remaining'] ?? 0;
    final total = batch['batch_size'] ?? 25;
    final percentage = total > 0 ? remaining / total : 0.0;

    Color statusColor = Colors.green;
    if (percentage < 0.2) {
      statusColor = Colors.red;
    } else if (percentage < 0.5) {
      statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  batch['session_type'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    '$remaining left',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  backgroundColor: statusColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Range: ${batch['start_certificate_number']} - ${batch['end_certificate_number']}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksPanel() {
    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.checklist, color: Colors.orange),
            const SizedBox(width: 12),
            const Text(
              'Task Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (!_isLoadingTasks)
              Chip(
                label: Text(
                  '${_tasksByType.length} Course Types',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.orange.shade100,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        trailing: _isLoadingTasks
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        initiallyExpanded: _tasksExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _tasksExpanded = expanded);
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_tasksByType.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No tasks configured yet'),
                    ),
                  )
                else
                  ..._tasksByType.entries.map(
                    (entry) => _buildTaskTypePanel(entry.key, entry.value),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Add/Edit Tasks - Coming soon'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Configure Tasks'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTypePanel(String sessionType, List<dynamic> tasks) {
    final isExpanded = _taskTypeExpanded[sessionType] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final needsRefresh = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManageTasksScreen(
                authService: widget.authService,
                sessionType: sessionType,
                tasks: tasks,
              ),
            ),
          );
          if (needsRefresh == true) {
            _loadTasks();
          }
        },
        child: ExpansionTile(
          title: Text(
            sessionType,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${tasks.length} tasks'),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _taskTypeExpanded[sessionType] = expanded;
            });
          },
          children: tasks.map((task) {
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 12,
                child: Text(
                  '${task['sequence'] ?? 0}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              title: Text(
                task['task_description'] ?? 'Unknown',
                style: const TextStyle(fontSize: 14),
              ),
              trailing: task['mandatory'] == true || task['mandatory'] == 1
                  ? const Icon(Icons.star, size: 16, color: Colors.orange)
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }
}
