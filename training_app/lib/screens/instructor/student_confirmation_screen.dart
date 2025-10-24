import 'package:flutter/material.dart';
import '../../models/student_enrollment_data.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class StudentConfirmationScreen extends StatefulWidget {
  final StudentEnrollmentData enrollmentData;
  final int sessionId;
  final AuthService authService; // ← ADD THIS LINE

  const StudentConfirmationScreen({
    super.key,
    required this.enrollmentData,
    required this.sessionId,
    required this.authService, // ← ADD THIS LINE
  });

  @override
  State<StudentConfirmationScreen> createState() =>
      _StudentConfirmationScreenState();
}

class _StudentConfirmationScreenState extends State<StudentConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  String _bikeType = 'Manual';
  bool _showAdditionalFields = false;
  bool _isSubmitting = false; // ← ADD THIS LINE

  @override
  void dispose() {
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  void _confirmDetails() {
    setState(() {
      _showAdditionalFields = true;
    });
  }

  Future<void> _submitStudent() async {
    if (!_formKey.currentState!.validate()) return;

    // TODO: Call API to save student with all data
    // For now, just show success and go back
    print('Sending photos:');
    print(
      'Student: ${widget.enrollmentData.studentPhotoPath.substring(0, 50)}...',
    );
    print(
      'License: ${widget.enrollmentData.licensePhotoPath.substring(0, 50)}...',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Student enrolled successfully'),
        backgroundColor: Colors.green,
      ),
    );

    // Return to session detail screen
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Student Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Verification Status
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Identity Verified',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Photos captured and verified',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Extracted Data
              const Text(
                'Extracted from Driving Licence',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _buildDataCard(
                'Full Name',
                '${widget.enrollmentData.forename} ${widget.enrollmentData.surname}',
              ),
              _buildDataCard('Address', widget.enrollmentData.address),
              _buildDataCard('Postcode', widget.enrollmentData.postcode),
              _buildDataCard(
                'Date of Birth',
                widget.enrollmentData.dateOfBirth,
              ),
              _buildDataCard(
                'Age',
                'Calculated from DOB',
              ), // TODO: Calculate age from dateOfBirth
              // Age 16 Warning
              if (widget.enrollmentData.ageRestrictionWarning == true)
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            const Text('16 year old - AUTOMATIC Only!!')
                                as String,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              _buildDataCard(
                'Driver Number',
                widget.enrollmentData.driverNumber,
              ),
              _buildDataCard(
                'Issue Date',
                'N/A',
              ), // Not in model yet - add if needed
              _buildDataCard(
                'Expiry Date',
                'N/A',
              ), // Not in model yet - add if needed
              // Licence Validity Warning
              if (widget.enrollmentData.isLicenceExpired == true)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            const Text('License Expired - Cannot proceed!')
                                as String,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Confirm Button (if not yet confirmed)
              if (!_showAdditionalFields)
                ElevatedButton(
                  onPressed: _confirmDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text(
                    'Confirm Details',
                    style: TextStyle(fontSize: 16),
                  ),
                ),

              // Additional Information Fields (shown after confirmation)
              if (_showAdditionalFields) ...[
                const Divider(height: 32),
                const Text(
                  'Additional Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'student@example.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emergencyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact Name',
                    hintText: 'John Doe',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Emergency contact name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact Phone',
                    hintText: '07700 900000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Emergency contact phone is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _bikeType,
                  decoration: const InputDecoration(
                    labelText: 'Bike Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.motorcycle),
                  ),
                  items: ['Manual', 'Automatic'].map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _bikeType = value!;
                    });
                  },
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _submitStudent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text(
                    'Complete Enrolment',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataCard(String label, String? value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value ?? 'Not found',
                style: TextStyle(
                  fontSize: 16,
                  color: value == null ? Colors.red : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to _StudentConfirmationScreenState class
  Future<void> _submitEnrollment() async {
    setState(() {
      _isSubmitting = true;
    });

    final apiService = ApiService(
      widget.authService,
    ); // You'll need to pass authService

    final result = await apiService.enrollStudentWithVerification(
      sessionId: widget.sessionId,
      studentData: widget.enrollmentData.toJson(),
    );

    setState(() {
      _isSubmitting = false;
    });

    if (result['success']) {
      // Success! Show message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student enrolled successfully')),
      );
      Navigator.of(context).pop();
    } else {
      // Error - show message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${result['error']}')));
    }
  }
}
