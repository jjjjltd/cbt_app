import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';
import '../login_screen.dart';
import 'add_certificate_batch_screen.dart';
import 'register_user_screen.dart';

class AdminDashboard extends StatefulWidget {
  final AuthService authService;

  const AdminDashboard({super.key, required this.authService});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late ApiService _apiService;
  List<dynamic> _certificateBatches = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.authService);
    _loadCertificateInventory();
  }

  Future<void> _loadCertificateInventory() async {
    setState(() => _isLoading = true);
    
    final result = await _apiService.getCertificateInventory();
    
    if (result['success']) {
      setState(() {
        _certificateBatches = result['data']['batches'] ?? [];
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCertificateInventory,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
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
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(
                  icon: Icons.person_add,
                  title: 'Register User',
                  color: Colors.blue,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RegisterUserScreen(
                          authService: widget.authService,
                        ),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.confirmation_number,
                  title: 'Add Certificates',
                  color: Colors.green,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddCertificateBatchScreen(
                          authService: widget.authService,
                        ),
                      ),
                    );
                    _loadCertificateInventory();
                  },
                ),
                _buildActionCard(
                  icon: Icons.analytics,
                  title: 'Reports',
                  color: Colors.orange,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reports coming soon')),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.settings,
                  title: 'Settings',
                  color: Colors.purple,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings coming soon')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Certificate Inventory
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Certificate Inventory',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_certificateBatches.isEmpty && !_isLoading)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'No certificate batches yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...(_certificateBatches.map((batch) => _buildBatchCard(batch))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> batch) {
    final remaining = batch['certificates_remaining'] ?? 0;
    final total = batch['batch_size'] ?? 25;
    final percentage = total > 0 ? (remaining / total) : 0.0;
    
    Color statusColor = Colors.green;
    if (percentage < 0.2) {
      statusColor = Colors.red;
    } else if (percentage < 0.5) {
      statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Range: ${batch['start_certificate_number']} - ${batch['end_certificate_number']}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              'Current: ${batch['current_certificate_number']}',
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
}