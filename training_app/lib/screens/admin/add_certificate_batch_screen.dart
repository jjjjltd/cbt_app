import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';

class AddCertificateBatchScreen extends StatefulWidget {
  final AuthService authService;

  const AddCertificateBatchScreen({super.key, required this.authService});

  @override
  State<AddCertificateBatchScreen> createState() =>
      _AddCertificateBatchScreenState();
}

class _AddCertificateBatchScreenState extends State<AddCertificateBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startNumberController = TextEditingController();
  final _batchSizeController = TextEditingController(text: '25');
  
  late ApiService _apiService;
  String _selectedSessionType = 'CBT';
  bool _isLoading = false;

  final List<Map<String, String>> _sessionTypes = [
    {'value': 'CBT', 'label': 'CBT - Compulsory Basic Training'},
    {'value': 'MODULE_1', 'label': 'Module 1 - Off-road Test'},
    {'value': 'MODULE_2', 'label': 'Module 2 - On-road Test'},
    {'value': 'DAS', 'label': 'DAS - Direct Access Scheme'},
    {'value': 'A2', 'label': 'A2 License Training'},
  ];

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.authService);
  }

  @override
  void dispose() {
    _startNumberController.dispose();
    _batchSizeController.dispose();
    super.dispose();
  }

  Future<void> _addBatch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.addCertificateBatch(
      sessionType: _selectedSessionType,
      startNumber: int.parse(_startNumberController.text),
      batchSize: int.parse(_batchSizeController.text),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Certificate batch added successfully'),
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

  int? get _endNumber {
    if (_startNumberController.text.isEmpty ||
        _batchSizeController.text.isEmpty) {
      return null;
    }
    return int.tryParse(_startNumberController.text)! +
        int.tryParse(_batchSizeController.text)! -
        1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Certificate Batch'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Enter the first certificate number from your new batch. '
                          'The system will automatically generate the full range.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Session Type Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedSessionType,
                decoration: const InputDecoration(
                  labelText: 'Session Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _sessionTypes.map((type) {
                  return DropdownMenuItem(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSessionType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Start Certificate Number
              TextFormField(
                controller: _startNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'First Certificate Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                  hintText: 'e.g., 5965176',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the first certificate number';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Batch Size
              TextFormField(
                controller: _batchSizeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Batch Size',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                  hintText: 'Default: 25',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter batch size';
                  }
                  final size = int.tryParse(value);
                  if (size == null || size < 1) {
                    return 'Please enter a valid size';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // Preview Card
              if (_endNumber != null)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Batch Preview',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPreviewRow(
                          'Session Type',
                          _sessionTypes
                              .firstWhere((t) => t['value'] == _selectedSessionType)['label']!,
                        ),
                        _buildPreviewRow(
                          'First Certificate',
                          _startNumberController.text,
                        ),
                        _buildPreviewRow(
                          'Last Certificate',
                          _endNumber.toString(),
                        ),
                        _buildPreviewRow(
                          'Total Certificates',
                          _batchSizeController.text,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Add Button
              ElevatedButton(
                onPressed: _isLoading ? null : _addBatch,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Add Certificate Batch',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[700]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}