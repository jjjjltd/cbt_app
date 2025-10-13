import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class StudentTasksScreen extends StatefulWidget {
  final AuthService authService;
  final int sessionId;
  final List<dynamic> students;

  const StudentTasksScreen({
    super.key,
    required this.authService,
    required this.sessionId,
    required this.students,
  });

  @override
  State<StudentTasksScreen> createState() => _StudentTasksScreenState();
}

class _StudentTasksScreenState extends State<StudentTasksScreen>
    with SingleTickerProviderStateMixin {
  late ApiService _apiService;
  late TabController _tabController;
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.authService);
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadTasks() {
    // Get tasks from first student (all students have same tasks)
    if (widget.students.isNotEmpty) {
      final firstStudent = widget.students[0];
      if (firstStudent['tasks'] != null) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(firstStudent['tasks']);
          _tasks.sort((a, b) =>
              (a['sequence'] ?? 0).compareTo(b['sequence'] ?? 0));
        });
      }
    }
  }

  Future<void> _toggleTaskForAll(int index) async {
    final task = _tasks[index];
    final newState = !(task['completed'] ?? false);

    setState(() => _isLoading = true);

    final result = await _apiService.completeTaskForAll(
      sessionId: widget.sessionId,
      taskId: task['task_id'],
      completed: newState,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      setState(() {
        _tasks[index]['completed'] = newState;
        _tasks[index]['completed_at'] =
            newState ? DateTime.now().toIso8601String() : null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task ${newState ? 'completed' : 'unchecked'} for all students',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleTaskForStudent(
      int studentId, String taskId, bool currentState) async {
    final result = await _apiService.updateStudentTask(
      studentId: studentId,
      taskId: taskId,
      completed: !currentState,
    );

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task updated'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Refresh parent screen
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.checklist), text: 'Group Tasks'),
            Tab(icon: Icon(Icons.person), text: 'Individual'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupTasksTab(),
          _buildIndividualTasksTab(),
        ],
      ),
    );
  }

  Widget _buildGroupTasksTab() {
    return Column(
      children: [
        // Info Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Checking tasks here applies to ALL ${widget.students.length} students',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // Progress Card
        if (_tasks.isNotEmpty)
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${_tasks.where((t) => t['completed'] == true).length} / ${_tasks.length} Tasks Completed',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _tasks.isEmpty
                        ? 0
                        : _tasks.where((t) => t['completed'] == true).length /
                            _tasks.length,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ],
              ),
            ),
          ),

        // Task List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks configured',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        final isCompleted = task['completed'] == true;
                        final completedAt = task['completed_at'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isCompleted
                              ? Colors.green.shade50
                              : Colors.white,
                          child: CheckboxListTile(
                            title: Text(
                              task['task_description'],
                              style: TextStyle(
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: isCompleted && completedAt != null
                                ? Text(
                                    'Completed: ${DateTime.parse(completedAt).toString().substring(0, 16)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  )
                                : null,
                            value: isCompleted,
                            activeColor: Colors.green,
                            onChanged: (_) => _toggleTaskForAll(index),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildIndividualTasksTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.students.length,
      itemBuilder: (context, index) {
        final student = widget.students[index];
        final tasks = student['tasks'] as List<dynamic>? ?? [];
        final completedCount =
            tasks.where((t) => t['completed'] == true).length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: completedCount == tasks.length && tasks.isNotEmpty
                  ? Colors.green
                  : Colors.orange,
              child: Text(
                student['name'][0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              student['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$completedCount / ${tasks.length} tasks completed',
              style: TextStyle(
                color: completedCount == tasks.length && tasks.isNotEmpty
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            children: tasks.map<Widget>((task) {
              final isCompleted = task['completed'] == true;
              final hasOverride = task['override_reason'] != null;

              return ListTile(
                leading: Checkbox(
                  value: isCompleted,
                  activeColor: Colors.green,
                  onChanged: (value) {
                    _toggleTaskForStudent(
                      student['student_id'],
                      task['task_id'],
                      isCompleted,
                    );
                  },
                ),
                title: Text(
                  task['task_description'],
                  style: TextStyle(
                    decoration:
                        isCompleted ? TextDecoration.lineThrough : null,
                    fontSize: 14,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task['completed_at'] != null)
                      Text(
                        DateTime.parse(task['completed_at'])
                            .toString()
                            .substring(0, 16),
                        style: const TextStyle(fontSize: 11),
                      ),
                    if (hasOverride)
                      Text(
                        'Override: ${task['override_reason']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                trailing: hasOverride
                    ? const Icon(Icons.warning, color: Colors.orange, size: 20)
                    : null,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}