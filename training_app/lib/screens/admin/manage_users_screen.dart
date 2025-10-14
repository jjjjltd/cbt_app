import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'register_user_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  final AuthService authService;

  const ManageUsersScreen({Key? key, required this.authService})
      : super(key: key);

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<dynamic> _users = [];
  bool _isLoading = false;
  String _filterRole = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/admin/users'),
        headers: widget.authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _users = data['users'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load users')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  List<dynamic> get _filteredUsers {
    if (_filterRole == 'ALL') return _users;
    if (_filterRole == 'ADMIN') {
      return _users.where((u) => u['is_admin'] == 1 || u['is_admin'] == true).toList();
    }
    if (_filterRole == 'INSTRUCTOR') {
      return _users.where((u) => u['is_instructor'] == 1 || u['is_instructor'] == true).toList();
    }
    return _users;
  }

  String _getRoleBadge(Map<String, dynamic> user) {
    final isAdmin = user['is_admin'] == 1 || user['is_admin'] == true;
    final isInstructor = user['is_instructor'] == 1 || user['is_instructor'] == true;
    
    if (isAdmin && isInstructor) return 'Admin + Instructor';
    if (isAdmin) return 'Admin';
    if (isInstructor) return 'Instructor';
    return 'No Role';
  }

  Color _getRoleColor(Map<String, dynamic> user) {
    final isAdmin = user['is_admin'] == 1 || user['is_admin'] == true;
    final isInstructor = user['is_instructor'] == 1 || user['is_instructor'] == true;
    
    if (isAdmin && isInstructor) return Colors.purple;
    if (isAdmin) return Colors.red;
    if (isInstructor) return Colors.blue;
    return Colors.grey;
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final currentStatus = user['status'];
    final newStatus = currentStatus == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${newStatus == 'ACTIVE' ? 'Activate' : 'Deactivate'} User'),
        content: Text(
          'Are you sure you want to ${newStatus == 'ACTIVE' ? 'activate' : 'deactivate'} ${user['name']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'ACTIVE' ? Colors.green : Colors.red,
            ),
            child: Text(newStatus == 'ACTIVE' ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // TODO: Implement update user status API endpoint
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User status update - API endpoint needed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user['email']),
              _buildDetailRow('Role', _getRoleBadge(user)),
              _buildDetailRow('Status', user['status']),
              if (user['instructor_certificate_number'] != null)
                _buildDetailRow('Cert Number', user['instructor_certificate_number']),
              if (user['phone'] != null)
                _buildDetailRow('Phone', user['phone']),
              _buildDetailRow('Created', user['created_at']?.substring(0, 10) ?? 'N/A'),
              if (user['last_login'] != null)
                _buildDetailRow('Last Login', user['last_login']?.substring(0, 16) ?? 'Never'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _filteredUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('All (${_users.length})'),
                  selected: _filterRole == 'ALL',
                  onSelected: (_) => setState(() => _filterRole = 'ALL'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Admins (${_users.where((u) => u['is_admin'] == 1 || u['is_admin'] == true).length})'),
                  selected: _filterRole == 'ADMIN',
                  onSelected: (_) => setState(() => _filterRole = 'ADMIN'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Instructors (${_users.where((u) => u['is_instructor'] == 1 || u['is_instructor'] == true).length})'),
                  selected: _filterRole == 'INSTRUCTOR',
                  onSelected: (_) => setState(() => _filterRole = 'INSTRUCTOR'),
                ),
              ],
            ),
          ),

          // User List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final isActive = user['status'] == 'ACTIVE';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getRoleColor(user),
                                  child: Text(
                                    user['name'][0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  user['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? Colors.black : Colors.grey,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user['email']),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      children: [
                                        Chip(
                                          label: Text(
                                            _getRoleBadge(user),
                                            style: const TextStyle(fontSize: 11, color: Colors.white),
                                          ),
                                          backgroundColor: _getRoleColor(user),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          padding: EdgeInsets.zero,
                                        ),
                                        Chip(
                                          label: Text(
                                            user['status'],
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          backgroundColor: isActive ? Colors.green.shade100 : Colors.red.shade100,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(Icons.info, size: 20),
                                          SizedBox(width: 8),
                                          Text('View Details'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isActive ? Icons.block : Icons.check_circle,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(isActive ? 'Deactivate' : 'Activate'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'view') {
                                      _showUserDetails(user);
                                    } else if (value == 'toggle') {
                                      _toggleUserStatus(user);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegisterUserScreen(
                authService: widget.authService,
              ),
            ),
          );
          _loadUsers();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}