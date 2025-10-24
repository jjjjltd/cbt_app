import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class CompanySettingsScreen extends StatefulWidget {
  final AuthService authService;

  const CompanySettingsScreen({super.key, required this.authService});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _countyController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _siteCodeController = TextEditingController();
  final _trainingBodyRefController = TextEditingController();

  final _picker = ImagePicker();
  Uint8List? _stampImageBytes;
  String? _stampImagePath;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _countyController.dispose();
    _postcodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _siteCodeController.dispose();
    _trainingBodyRefController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyData() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/company'),
        headers: widget.authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _nameController.text = data['company_name'] ?? '';
          _addressLine1Controller.text = data['address_line_1'] ?? '';
          _addressLine2Controller.text = data['address_line_2'] ?? '';
          _cityController.text = data['city'] ?? '';
          _countyController.text = data['county'] ?? '';
          _postcodeController.text = data['postcode'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emailController.text = data['email'] ?? '';
          _trainingBodyRefController.text =
              data['training_body_reference'] ?? '';
          // TODO: Load stamp image if path exists
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading company data: $e')),
        );
      }
    }
  }

  Future<void> _pickStampImage() async {
    final XFile? image = await _picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _stampImageBytes = bytes;
        _stampImagePath = image.path;
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.put(
        Uri.parse('http://localhost:8000/company'),
        headers: widget.authService.getAuthHeaders(),
        body: json.encode({
          'company_name': _nameController.text,
          'address_line_1': _addressLine1Controller.text,
          'address_line_2': _addressLine2Controller.text,
          'city': _cityController.text,
          'county': _countyController.text,
          'postcode': _postcodeController.text,
          'phone': _phoneController.text,
          'email': _emailController.text,
          'training_body_reference': _trainingBodyRefController.text,
        }),
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => _hasChanges = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // TODO: Upload stamp image if changed
        if (_stampImageBytes != null) {
          _uploadStampImage();
        }
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error['detail'] ?? 'Failed to save settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _uploadStampImage() async {
    // TODO: Implement image upload endpoint
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image upload - API endpoint needed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Settings'),
        actions: [
          if (_hasChanges)
            IconButton(icon: const Icon(Icons.save), onPressed: _saveSettings),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Company Stamp Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Company Stamp / Logo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'This will appear on certificates (bottom left)',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_stampImageBytes != null)
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _stampImageBytes!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.business,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text('No stamp/logo uploaded'),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _pickStampImage,
                              icon: const Icon(Icons.upload),
                              label: Text(
                                _stampImageBytes == null
                                    ? 'Upload Stamp/Logo'
                                    : 'Change Stamp/Logo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Company Details Section
                    const Text(
                      'Company Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Company Name *',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _hasChanges = true),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _trainingBodyRefController,
                      decoration: const InputDecoration(
                        labelText: 'Training Body Reference *',
                        border: OutlineInputBorder(),
                        hintText: 'Appears on certificates',
                      ),
                      onChanged: (_) => setState(() => _hasChanges = true),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _addressLine1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Address Line 1',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _hasChanges = true),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _addressLine2Controller,
                      decoration: const InputDecoration(
                        labelText: 'Address Line 2',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _hasChanges = true),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) =>
                                setState(() => _hasChanges = true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _postcodeController,
                            decoration: const InputDecoration(
                              labelText: 'Postcode',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) =>
                                setState(() => _hasChanges = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _countyController,
                      decoration: const InputDecoration(
                        labelText: 'County',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _hasChanges = true),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() => _hasChanges = true),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() => _hasChanges = true),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Save Settings',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
