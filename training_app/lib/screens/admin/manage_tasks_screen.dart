import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ManageTasksScreen extends StatefulWidget {
  final AuthService authService;
  final String sessionType;
  final List<dynamic> tasks;

  const ManageTasksScreen({
    super.key,
    required this.authService,
    required this.sessionType,
    required this.tasks,
  });

  @override
  State<ManageTasksScreen> createState() => _ManageTasksScreenState();
}

class _ManageTasksScreenState extends State<ManageTasksScreen> {
  late List<Map<String, dynamic>> _tasks;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tasks = List<Map<String, dynamic>>.from(widget.tasks);
    _tasks.sort((a, b) => (a['sequence'] ?? 0).compareTo(b['sequence'] ?? 0));
  }

  void _markChanged() {
    setState(() => _hasChanges = true);
  }

  void _addTask() {
    final taskIdController = TextEditingController();
    final descriptionController = TextEditingController();
    bool mandatory = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: taskIdController,
                  decoration: const InputDecoration(
                    labelText: 'Task ID *',
                    hintText: 'e.g., EYESIGHT_CHECK',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'e.g., Eyesight checked',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Mandatory'),
                  subtitle: const Text('Must be completed'),
                  value: mandatory,
                  onChanged: (value) {
                    setDialogState(() {
                      mandatory = value!;
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
              onPressed: () {
                if (taskIdController.text.isEmpty ||
                    descriptionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task ID and Description required'),
                    ),
                  );
                  return;
                }

                setState(() {
                  _tasks.add({
                    'task_id': taskIdController.text.toUpperCase(),
                    'task_description': descriptionController.text,
                    'sequence': _tasks.isEmpty ? 1 : _tasks.length + 1,
                    'mandatory': mandatory ? 1 : 0,
                    'session_type': widget.sessionType,
                    'config_id': null, // New task, no ID yet
                  });
                  _markChanged();
                });

                Navigator.pop(context);
              },
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }

  void _editTask(int index) {
    final task = _tasks[index];
    final descriptionController = TextEditingController(
      text: task['task_description'],
    );
    bool mandatory = task['mandatory'] == 1 || task['mandatory'] == true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: task['task_id']),
                decoration: const InputDecoration(
                  labelText: 'Task ID (read-only)',
                  border: OutlineInputBorder(),
                ),
                enabled: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Mandatory'),
                subtitle: const Text('Must be completed'),
                value: mandatory,
                onChanged: (value) {
                  setDialogState(() {
                    mandatory = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _tasks[index]['task_description'] =
                      descriptionController.text;
                  _tasks[index]['mandatory'] = mandatory ? 1 : 0;
                  _markChanged();
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTask(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text(
          'Are you sure you want to delete:\n\n${_tasks[index]['task_description']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _tasks.removeAt(index);
        _resequenceTasks();
        _markChanged();
      });
    }
  }

  void _resequenceTasks() {
    for (int i = 0; i < _tasks.length; i++) {
      _tasks[i]['sequence'] = i + 1;
    }
  }

  void _moveTask(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final task = _tasks.removeAt(oldIndex);
      _tasks.insert(newIndex, task);
      _resequenceTasks();
      _markChanged();
    });
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    setState(() => _hasChanges = false);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/admin/tasks/${widget.sessionType}'),
        headers: widget.authService.getAuthHeaders(),
        body: json.encode({'tasks': _tasks}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tasks saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate refresh needed
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error['detail'] ?? 'Failed to save tasks'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _hasChanges = true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unsaved Changes'),
              content: const Text('You have unsaved changes. Discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.sessionType} Tasks'),
          actions: [
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveChanges,
                tooltip: 'Save Changes',
              ),
          ],
        ),
        body: Column(
          children: [
            // Info Banner
            if (_hasChanges)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade100,
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You have unsaved changes. Tap Save to apply.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Instructions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Management',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Drag to reorder tasks\n'
                    '• Tap to edit\n'
                    '• Swipe left to delete',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            // Task List
            Expanded(
              child: _tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.checklist,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks configured',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _addTask,
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Task'),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tasks.length,
                      onReorder: _moveTask,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return Dismissible(
                          key: Key('${task['task_id']}_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Task'),
                                content: Text(
                                  'Delete "${task['task_description']}"?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) {
                            setState(() {
                              _tasks.removeAt(index);
                              _resequenceTasks();
                              _markChanged();
                            });
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.drag_handle,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    radius: 16,
                                    child: Text(
                                      '${task['sequence']}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                task['task_description'] ?? 'Unknown',
                              ),
                              subtitle: Text(
                                task['task_id'] ?? '',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (task['mandatory'] == 1 ||
                                      task['mandatory'] == true)
                                    const Icon(
                                      Icons.star,
                                      size: 20,
                                      color: Colors.orange,
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _editTask(index),
                                  ),
                                ],
                              ),
                              onTap: () => _editTask(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_hasChanges)
              FloatingActionButton(
                heroTag: 'save',
                onPressed: _saveChanges,
                backgroundColor: Colors.green,
                child: const Icon(Icons.save),
              ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'add',
              onPressed: _addTask,
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }
}
