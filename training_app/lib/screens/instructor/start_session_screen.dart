import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'session_detail_screen.dart';

class StartSessionScreen extends StatefulWidget {
  final AuthService authService;

  const StartSessionScreen({super.key, required this.authService});

  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _siteCodeController = TextEditingController();
  final _notesController = TextEditingController();

  late ApiService _apiService;
  String _selectedSessionType = 'CBT';
  bool _isLoading = false;

  final List<Map<String, String>> _sessionTypes = [
    {'value': 'CBT', 'label': 'CBT', 'description': 'Compulsory Basic Training'},
    {'value': 'MODULE_1', 'label': 'Module 1', 'description': 'Off-road Riding Test'},
    {'value': 'MODULE_2', 'label': 'Module 2', 'description': 'On-road Riding Test'},
    {'value': 'DAS', 'label': 'DAS', 'description': 'Direct Access Scheme'},
    {'value': 'A2', 'label': 'A2', 'description': 'A2 License Training'},
  ];

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.authService);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _siteCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.createSession(
      sessionType: _selectedSessionType,
      location: _locationController.text.isEmpty
          ? null
          : _locationController.text,
      siteCode: _siteCodeController.text.isEmpty
          ? null
          : _siteCodeController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      final sessionId = result['data']['session_id'];
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session started successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to session detail screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SessionDetailScreen(
            authService: widget.authService,
            sessionId: sessionId,
          ),
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

  @override
  Widget build(BuildContext context) {
    final selectedType = _sessionTypes.firstWhere(
      (type) => type['value'] == _selectedSessionType,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Training Session'),
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
                          'Quick session start. Add students and begin training immediately.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Session Type Selection
              const Text(
                'Session Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ...(_sessionTypes.map((type) {
                final isSelected = type['value'] == _selectedSessionType;
                return Card(
                  color: isSelected ? Colors.green.shade50 : null,
                  child: RadioListTile<String>(
                    title: Text(
                      type['label']!,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(type['description']!),
                    value: type['value']!,
                    groupValue: _selectedSessionType,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        _selectedSessionType = value!;
                      });
                    },
                  ),
                );
              })),
              const SizedBox(height: 24),

              // Location (optional)
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                  hintText: 'e.g., North Training Ground',
                ),
              ),
              const SizedBox(height: 16),

              // Site Code (optional)
              TextFormField(
                controller: _siteCodeController,
                decoration: const InputDecoration(
                  labelText: 'Site Code (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                  hintText: 'For certificates',
                ),
              ),
              const SizedBox(height: 16),

              // Notes (optional)
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                  hintText: 'Weather, conditions, special notes...',
                ),
              ),
              const SizedBox(height: 32),

              // Start Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _startSession,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  _isLoading ? 'Starting...' : 'Start ${selectedType['label']} Session',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}