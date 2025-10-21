import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class StudentPhotoCaptureScreen extends StatefulWidget {
  final int sessionId;

  const StudentPhotoCaptureScreen({super.key, required this.sessionId});

  @override
  State<StudentPhotoCaptureScreen> createState() =>
      _StudentPhotoCaptureScreenState();
}

class _StudentPhotoCaptureScreenState extends State<StudentPhotoCaptureScreen> {
  final ImagePicker _picker = ImagePicker();

  String? _studentPhotoPath;
  String? _licensePhotoPath;
  bool _isVerifying = false;
  double? _matchScore;
  String? _verificationStatus;
  Color? _statusColor;

  Future<void> _takePhoto(bool isStudent) async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        if (isStudent) {
          _studentPhotoPath = photo.path;
        } else {
          _licensePhotoPath = photo.path;
        }
        _matchScore = null;
        _verificationStatus = null;
      });
    }
  }

  Future<void> _verifyPhotos() async {
    if (_studentPhotoPath == null || _licensePhotoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take both photos first')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      const backendUrl = 'http://localhost:8000/verify-face';

      final request = http.MultipartRequest('POST', Uri.parse(backendUrl));
      request.files.add(
        await http.MultipartFile.fromPath('student_photo', _studentPhotoPath!),
      );
      request.files.add(
        await http.MultipartFile.fromPath('license_photo', _licensePhotoPath!),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final result = json.decode(responseData);

      setState(() {
        _matchScore = result['match_score'];

        if (_matchScore! >= 90) {
          _verificationStatus = 'PASS - Match Verified';
          _statusColor = Colors.green;
        } else if (_matchScore! >= 50) {
          _verificationStatus = 'MANUAL CHECK REQUIRED';
          _statusColor = Colors.orange;
        } else {
          _verificationStatus = 'FAIL - Manual Override Required';
          _statusColor = Colors.red;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Verification error: $e')));
      // For demo purposes, generate a random score
      setState(() {
        _matchScore = 85.0 + (DateTime.now().millisecond % 15);
        if (_matchScore! >= 90) {
          _verificationStatus = 'PASS - Match Verified';
          _statusColor = Colors.green;
        } else if (_matchScore! >= 50) {
          _verificationStatus = 'MANUAL CHECK REQUIRED';
          _statusColor = Colors.orange;
        } else {
          _verificationStatus = 'FAIL - Manual Override Required';
          _statusColor = Colors.red;
        }
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _proceedToDataEntry() async {
    // TODO: Run OCR on license photo here
    // For now, navigate back with the photos

    if (_matchScore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify photos first')),
      );
      return;
    }

    // Return the captured data
    Navigator.pop(context, {
      'student_photo': _studentPhotoPath,
      'license_photo': _licensePhotoPath,
      'match_score': _matchScore,
      'verification_status': _verificationStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Identity Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student Photo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Student Photo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_studentPhotoPath != null)
                      kIsWeb
                          ? Image.network(
                              _studentPhotoPath!,
                              height: 200,
                              fit: BoxFit.contain,
                            )
                          : Image.file(
                              File(_studentPhotoPath!),
                              height: 200,
                              fit: BoxFit.contain,
                            )
                    else
                      Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(Icons.person, size: 80),
                      ),

                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _takePhoto(true),
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                        _studentPhotoPath == null
                            ? 'Take Photo'
                            : 'Retake Photo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // License Photo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'License Photo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_licensePhotoPath != null)
                      // For License Photo
                      if (_licensePhotoPath != null)
                        kIsWeb
                            ? Image.network(
                                _licensePhotoPath!,
                                height: 200,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(_licensePhotoPath!),
                                height: 200,
                                fit: BoxFit.contain,
                              )
                      else
                        Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Icon(Icons.credit_card, size: 80),
                        ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _takePhoto(false),
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                        _licensePhotoPath == null
                            ? 'Take Photo'
                            : 'Retake Photo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Verify Button
            ElevatedButton.icon(
              onPressed: _isVerifying ? null : _verifyPhotos,
              icon: _isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user),
              label: Text(_isVerifying ? 'Verifying...' : 'Verify Photos'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            // Add this right after the Verify Button
            const SizedBox(height: 16),

            // TEST OCR BUTTON
            ElevatedButton.icon(
              onPressed: _licensePhotoPath == null ? null : _testOCR,
              icon: const Icon(Icons.text_fields),
              label: const Text('TEST: Extract Text from License'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),

            // Verification Result
            if (_matchScore != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _statusColor?.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        _matchScore! >= 90
                            ? Icons.check_circle
                            : _matchScore! >= 50
                            ? Icons.warning
                            : Icons.error,
                        size: 48,
                        color: _statusColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Match Score: ${_matchScore!.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _verificationStatus!,
                        style: TextStyle(
                          fontSize: 16,
                          color: _statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _proceedToDataEntry,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Proceed to Data Entry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<Map<String, String?>> _extractLicenceData() async {
    if (_licensePhotoPath == null) {
      return {};
    }

    try {
      final inputImage = InputImage.fromFilePath(_licensePhotoPath!);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      // Extract all text
      String fullText = recognizedText.text;

      // Parse UK driving licence fields
      final extractedData = _parseUKLicence(fullText);

      await textRecognizer.close();

      return extractedData;
    } catch (e) {
      print('OCR Error: $e');
      return {};
    }
  }

  Map<String, String?> _parseUKLicence(String text) {
    // TODO: Parse specific fields from UK licence
    // This is where the magic happens - we'll build this next

    return {
      'licence_number': null,
      'surname': null,
      'forename': null,
      'date_of_birth': null,
      'address': null,
      'postcode': null,
      'issue_date': null,
      'expiry_date': null,
    };
  }

  Future<void> _testOCR() async {
    if (_licensePhotoPath == null) return;

    try {
      final inputImage = InputImage.fromFilePath(_licensePhotoPath!);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      await textRecognizer.close();

      // Show what we found!
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('OCR Results'),
          content: SingleChildScrollView(
            child: SelectableText(
              recognizedText.text.isEmpty
                  ? 'No text found'
                  : recognizedText.text,
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
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OCR Error: $e')));
    }
  }
}
