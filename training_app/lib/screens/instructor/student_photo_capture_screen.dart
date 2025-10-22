import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'student_confirmation_screen.dart';

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
      print('=== FLUTTER DEBUG ${DateTime.now()} ===');
      print('Area of API Call for Verify-Face');

      const backendUrl = 'http://localhost:8000/verify-face';
      final request = http.MultipartRequest('POST', Uri.parse(backendUrl));

      if (kIsWeb) {
        // Web: Read as bytes
        final studentBytes = await http.readBytes(
          Uri.parse(_studentPhotoPath!),
        );
        final licenseBytes = await http.readBytes(
          Uri.parse(_licensePhotoPath!),
        );

        request.files.add(
          http.MultipartFile.fromBytes(
            'student_photo',
            studentBytes,
            filename: 'student.jpg',
          ),
        );
        request.files.add(
          http.MultipartFile.fromBytes(
            'license_photo',
            licenseBytes,
            filename: 'license.jpg',
          ),
        );
      } else {
        // Mobile: Use file path
        request.files.add(
          await http.MultipartFile.fromPath(
            'student_photo',
            _studentPhotoPath!,
          ),
        );
        request.files.add(
          await http.MultipartFile.fromPath(
            'license_photo',
            _licensePhotoPath!,
          ),
        );
      }

      print('Sending request to: $backendUrl');
      final response = await request.send();
      print('Response status: ${response.statusCode}');

      final responseData = await response.stream.bytesToString();
      print('Response data: $responseData');

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
      print('Face verification error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Verification error: $e')));
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _proceedToDataEntry() async {
    if (_matchScore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify photos first')),
      );
      return;
    }

    // Run OCR and parse data
    if (_licensePhotoPath == null) return;

    try {
      final inputImage = InputImage.fromFilePath(_licensePhotoPath!);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      await textRecognizer.close();

      // Parse the licence data
      final parsedData = _parseUKLicence(recognizedText.text);

      // Navigate to confirmation screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentConfirmationScreen(
            parsedData: parsedData,
            studentPhotoPath: _studentPhotoPath!,
            licensePhotoPath: _licensePhotoPath!,
            sessionId: widget.sessionId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error processing licence: $e')));
    }
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

            //  Temporary
            ElevatedButton.icon(
              onPressed: _testOCRFromFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('TEST: Load License from Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            //  Temporary

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

  Future<void> _testOCR() async {
    if (_licensePhotoPath == null) return;

    try {
      final inputImage = InputImage.fromFilePath(_licensePhotoPath!);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      await textRecognizer.close();

      // Parse the extracted text
      final parsedData = _parseUKLicence(recognizedText.text);

      // Show parsed results
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Parsed Licence Data'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDataRow('Full Name', parsedData['full_name']),
                _buildDataRow('Address', parsedData['address']),
                _buildDataRow('Postcode', parsedData['postcode']),
                _buildDataRow('Date of Birth', parsedData['date_of_birth']),
                _buildDataRow('Age', parsedData['age']?.toString()),
                if (parsedData['age_warning'] != null)
                  Text(
                    parsedData['age_warning'],
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                _buildDataRow('Driver Number', parsedData['driver_number']),
                _buildDataRow('Issue Date', parsedData['issue_date']),
                _buildDataRow('Expiry Date', parsedData['expiry_date']),
                if (parsedData['validation_warning'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      parsedData['validation_warning'],
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                const Divider(),
                const Text(
                  'Raw OCR Text:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SelectableText(recognizedText.text),
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
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OCR Error: $e')));
    }
  }

  Widget _buildDataRow(String label, String? value) {
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
          Expanded(
            child: Text(
              value ?? 'Not found',
              style: TextStyle(
                color: value == null ? Colors.red : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testOCRFromFile() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery, // Pick from gallery instead of camera
    );

    if (image == null) return;

    setState(() {
      _licensePhotoPath = image.path;
    });

    // Now run OCR on it
    _testOCR();
  }

  Map<String, dynamic> _parseUKLicence(String ocrText) {
    final lines = ocrText.split('\n').map((line) => line.trim()).toList();

    Map<String, dynamic> result = {
      'driver_number': null,
      'surname': null,
      'forenames': null,
      'full_name': null,
      'date_of_birth': null,
      'age': null,
      'address': null,
      'postcode': null,
      'issue_date': null,
      'expiry_date': null,
      'is_valid': null,
      'validation_warning': null,
    };

    try {
      // Field 6: Driver Number (format: SURNAME612185JJ9BE - 16 chars with specific pattern)
      final driverNumberPattern = RegExp(r'[A-Z]{5}\d{6}[A-Z]{2}\d[A-Z]{2}');
      final driverNumberMatch = driverNumberPattern.firstMatch(ocrText);
      if (driverNumberMatch != null) {
        result['driver_number'] = driverNumberMatch.group(0);
      }

      // Field 3: Date of Birth (format: DD.MM.YYYY)
      final dobPattern = RegExp(r'\b(\d{2})\.(\d{2})\.(\d{4})\b');
      final dobMatches = dobPattern.allMatches(ocrText).toList();

      if (dobMatches.isNotEmpty) {
        final dobMatch = dobMatches[0]; // First date is usually DOB
        final day = dobMatch.group(1);
        final month = dobMatch.group(2);
        final year = dobMatch.group(3);
        result['date_of_birth'] = '$day.$month.$year';

        // Calculate age
        final dob = DateTime(
          int.parse(year!),
          int.parse(month!),
          int.parse(day!),
        );
        final today = DateTime.now();
        int age = today.year - dob.year;
        if (today.month < dob.month ||
            (today.month == dob.month && today.day < dob.day)) {
          age--;
        }
        result['age'] = age;

        // Check if age 16 and needs automatic warning
        if (age == 16) {
          result['age_warning'] = 'Age 16: Automatic transmission only';
        }
      }

      // Field 4a & 4b: Issue and Expiry Dates (subsequent dates after DOB)
      if (dobMatches.length >= 3) {
        // Usually: DOB, Issue Date, Expiry Date
        final issueMatch = dobMatches[1];
        final expiryMatch = dobMatches[2];

        result['issue_date'] =
            '${issueMatch.group(1)}.${issueMatch.group(2)}.${issueMatch.group(3)}';
        result['expiry_date'] =
            '${expiryMatch.group(1)}.${expiryMatch.group(2)}.${expiryMatch.group(3)}';

        // Validate licence dates
        final issueDate = DateTime(
          int.parse(issueMatch.group(3)!),
          int.parse(issueMatch.group(2)!),
          int.parse(issueMatch.group(1)!),
        );
        final expiryDate = DateTime(
          int.parse(expiryMatch.group(3)!),
          int.parse(expiryMatch.group(2)!),
          int.parse(expiryMatch.group(1)!),
        );
        final today = DateTime.now();

        result['is_valid'] =
            today.isAfter(issueDate) && today.isBefore(expiryDate);

        if (!result['is_valid']) {
          if (today.isBefore(issueDate)) {
            result['validation_warning'] = '⚠️ Licence not yet valid';
          } else {
            result['validation_warning'] = '🚨 Licence has expired';
          }
        }
      }

      // Fields 1 & 2: Name (look for pattern of capitalized words)
      // Find "DRIVING LICENCE" line and extract name components near it
      int drivingLicenceIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('DRIVING LICENCE')) {
          drivingLicenceIndex = i;
          break;
        }
      }

      if (drivingLicenceIndex >= 0 && drivingLicenceIndex + 3 < lines.length) {
        // Fields 1 & 2: Name (look for numbered fields)
        String surname = '';
        String forenames = '';

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();

          // Look for "1." followed by surname (all caps, single word usually)
          if (line.startsWith('1.')) {
            surname = line.replaceAll(RegExp(r'^1\.\s*'), '').trim();
            // Take only first word if there's extra text
            surname = surname.split(' ').first;
          }

          // Look for "2." followed by forenames
          if (line.startsWith('2.')) {
            forenames = line.replaceAll(RegExp(r'^2\.\s*'), '').trim();
            // Remove any trailing non-letter characters
            forenames = forenames.replaceAll(RegExp(r'[^A-Z\s]+$'), '').trim();
          }
        }

        if (surname.isNotEmpty && forenames.isNotEmpty) {
          result['surname'] = surname;
          result['forenames'] = forenames;
          result['full_name'] = '$forenames $surname';
        }
      }

      // Field 8: Address and Postcode
      // Look for line starting with "8" or "8."
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('8.') || lines[i].startsWith('8 ')) {
          String addressLine = lines[i]
              .replaceAll(RegExp(r'^8\.?\s*'), '')
              .trim();

          // Check if there's a next line that's part of the address
          if (i + 1 < lines.length &&
              !lines[i + 1].startsWith(RegExp(r'^\d'))) {
            addressLine += ' ' + lines[i + 1].trim();
          }

          // Split address and postcode by last comma
          final lastCommaIndex = addressLine.lastIndexOf(',');
          if (lastCommaIndex > 0) {
            result['address'] = addressLine.substring(0, lastCommaIndex).trim();
            result['postcode'] = addressLine
                .substring(lastCommaIndex + 1)
                .trim();
          } else {
            result['address'] = addressLine;
          }
          break;
        }
      }
    } catch (e) {
      print('Parser error: $e');
    }

    return result;
  }
}
