import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'add_certificate_batch_screen.dart';

class ManageCertificatesScreen extends StatefulWidget {
  final AuthService authService;

  const ManageCertificatesScreen({Key? key, required this.authService})
      : super(key: key);

  @override
  State<ManageCertificatesScreen> createState() =>
      _ManageCertificatesScreenState();
}

class _ManageCertificatesScreenState extends State<ManageCertificatesScreen> {
  late ApiService _apiService;
  List<dynamic> _batches = [];
  bool _isLoading = false;
  String _filterType = 'ALL';
  String _filterStatus = 'ACTIVE';

  final List<String> _sessionTypes = ['ALL', 'CBT', 'MODULE_1', 'MODULE_2', 'DAS', 'A2'];

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.authService);
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);

    final result = await _apiService.getCertificateInventory();

    if (result['success']) {
      setState(() {
        _batches = result['data']['batches'] ?? [];
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

  List<dynamic> get _filteredBatches {
    return _batches.where((batch) {
      final matchesType = _filterType == 'ALL' || batch['session_type'] == _filterType;
      final matchesStatus = _filterStatus == 'ALL' || batch['status'] == _filterStatus;
      return matchesType && matchesStatus;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'EXHAUSTED':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getRemainingColor(int remaining, int total) {
    final percentage = remaining / total;
    if (percentage > 0.5) return Colors.green;
    if (percentage > 0.2) return Colors.orange;
    return Colors.red;
  }

  void _showBatchDetails(Map<String, dynamic> batch) {
    final remaining = batch['certificates_remaining'] ?? 0;
    final total = batch['batch_size'] ?? 25;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${batch['session_type']} Batch'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Session Type', batch['session_type_description'] ?? batch['session_type']),
              const Divider(),
              _buildDetailRow('Start Number', batch['start_certificate_number'].toString()),
              _buildDetailRow('End Number', batch['end_certificate_number'].toString()),
              _buildDetailRow('Current Number', batch['current_certificate_number'].toString()),
              const Divider(),
              _buildDetailRow('Total Certificates', total.toString()),
              _buildDetailRow('Remaining', remaining.toString()),
              _buildDetailRow('Issued', (total - remaining).toString()),
              const Divider(),
              _buildDetailRow('Status', batch['status']),
              if (batch['received_date'] != null)
                _buildDetailRow('Received', batch['received_date'].substring(0, 10)),
              if (batch['notes'] != null)
                _buildDetailRow('Notes', batch['notes']),
            ],
          ),
        ),
        actions: [
          if (batch['status'] == 'ACTIVE')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _voidBatch(batch);
              },
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text('Void Batch', style: TextStyle(color: Colors.red)),
            ),
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
            width: 120,
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

  Future<void> _voidBatch(Map<String, dynamic> batch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Certificate Batch'),
        content: Text(
          'Are you sure you want to void this batch?\n\n'
          'Batch: ${batch['session_type']}\n'
          'Range: ${batch['start_certificate_number']} - ${batch['end_certificate_number']}\n'
          'Remaining: ${batch['certificates_remaining']}\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Void Batch'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // TODO: Implement void batch API endpoint
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Void batch - API endpoint needed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredBatches = _filteredBatches;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Certificates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBatches,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Session Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sessionTypes.map((type) {
                    return ChoiceChip(
                      label: Text(type),
                      selected: _filterType == type,
                      onSelected: (_) => setState(() => _filterType = type),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['ALL', 'ACTIVE', 'EXHAUSTED', 'CANCELLED'].map((status) {
                    return ChoiceChip(
                      label: Text(status),
                      selected: _filterStatus == status,
                      onSelected: (_) => setState(() => _filterStatus = status),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Summary Card
          if (!_isLoading && _batches.isNotEmpty)
            Card(
              margin: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      'Total Batches',
                      _batches.length.toString(),
                      Icons.inventory,
                    ),
                    _buildSummaryItem(
                      'Active',
                      _batches.where((b) => b['status'] == 'ACTIVE').length.toString(),
                      Icons.check_circle,
                    ),
                    _buildSummaryItem(
                      'Total Remaining',
                      _batches
                          .where((b) => b['status'] == 'ACTIVE')
                          .fold<int>(0, (sum, b) => sum + (b['certificates_remaining'] ?? 0) as int)
                          .toString(),
                      Icons.confirmation_number,
                    ),
                  ],
                ),
              ),
            ),

          // Batch List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredBatches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No certificate batches found',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _filterType != 'ALL' || _filterStatus != 'ACTIVE'
                                  ? 'Try changing filters'
                                  : 'Add a new batch to get started',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBatches,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredBatches.length,
                          itemBuilder: (context, index) {
                            final batch = filteredBatches[index];
                            final remaining = batch['certificates_remaining'] ?? 0;
                            final total = batch['batch_size'] ?? 25;
                            final percentage = total > 0 ? remaining / total : 0.0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => _showBatchDetails(batch),
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
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              batch['status'],
                                              style: const TextStyle(fontSize: 11, color: Colors.white),
                                            ),
                                            backgroundColor: _getStatusColor(batch['status']),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Range: ${batch['start_certificate_number']} - ${batch['end_certificate_number']}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      ),
                                      Text(
                                        'Current: ${batch['current_certificate_number']}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '$remaining / $total remaining',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _getRemainingColor(remaining, total),
                                            ),
                                          ),
                                          Text(
                                            '${(percentage * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              color: _getRemainingColor(remaining, total),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: percentage,
                                        backgroundColor: Colors.grey[300],
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _getRemainingColor(remaining, total),
                                        ),
                                      ),
                                    ],
                                  ),
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
              builder: (context) => AddCertificateBatchScreen(
                authService: widget.authService,
              ),
            ),
          );
          _loadBatches();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Batch'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}