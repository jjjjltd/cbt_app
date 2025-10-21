import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiService {
  final AuthService authService;
  static String get baseUrl {
    if (kIsWeb) {
      // Web (Chrome, Edge, etc.)
      return 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      // Android emulator
      return 'http://10.0.2.2:8000';
    } else {
      // iOS, desktop, etc.
      return 'http://localhost:8000';
    }
  }

  ApiService(this.authService);

  // Certificate Batch Management
  Future<Map<String, dynamic>> addCertificateBatch({
    required String sessionType,
    required int startNumber,
    int batchSize = 25,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/certificates/batch'),
        headers: authService.getAuthHeaders(),
        body: json.encode({
          'session_type': sessionType,
          'start_certificate_number': startNumber,
          'batch_size': batchSize,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error':
              json.decode(response.body)['detail'] ?? 'Failed to add batch',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> getCertificateInventory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/certificates/inventory'),
        headers: authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to get inventory'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Session Management
  Future<Map<String, dynamic>> createSession({
    required String sessionType,
    String? location,
    String? siteCode,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sessions'),
        headers: authService.getAuthHeaders(),
        body: json.encode({
          'session_type': sessionType,
          'location': location,
          'site_code': siteCode,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error':
              json.decode(response.body)['detail'] ??
              'Failed to create session',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> getActiveSessions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sessions/active'),
        headers: authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to get sessions'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> getSession(int sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sessions/$sessionId'),
        headers: authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to get session'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Student Management
  Future<Map<String, dynamic>> addStudentToSession({
    required int sessionId,
    required String name,
    required String licenseNumber,
    String? email,
    String? phone,
    String? dateOfBirth,
    String? bikeType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sessions/$sessionId/students'),
        headers: authService.getAuthHeaders(),
        body: json.encode({
          'name': name,
          'license_number': licenseNumber,
          'email': email,
          'phone': phone,
          'date_of_birth': dateOfBirth,
          'bike_type': bikeType,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error':
              json.decode(response.body)['detail'] ?? 'Failed to add student',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Task Completion
  Future<Map<String, dynamic>> completeTaskForAll({
    required int sessionId,
    required String taskId,
    required bool completed,
    String? notes,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/sessions/$sessionId/tasks/complete'),
        headers: authService.getAuthHeaders(),
        body: json.encode({
          'task_id': taskId,
          'completed': completed,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to complete task'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateStudentTask({
    required int studentId,
    required String taskId,
    required bool completed,
    String? notes,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/students/$studentId/tasks/$taskId'),
        headers: authService.getAuthHeaders(),
        body: json.encode({
          'task_id': taskId,
          'completed': completed,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to update task'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> completeSession(int sessionId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sessions/$sessionId/complete'),
        headers: authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to complete session'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }
}
