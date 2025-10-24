import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:training_app/models/user.dart';

class AuthService {
  // TODO: Change this to your backend URL
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

  String? _token;
  User? _currentUser;

  String? get token => _token;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access_token'];
        _currentUser = User.fromJson(data['user']);

        return {'success': true, 'user': _currentUser};
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'error': error['detail'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  void logout() {
    _token = null;
    _currentUser = null;
  }

  Map<String, String> getAuthHeaders() {
    if (_token == null) {
      throw Exception('Not authenticated');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentUser = User.fromJson(data);
        return {'success': true, 'user': _currentUser};
      } else {
        return {'success': false, 'error': 'Failed to get user info'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }
}
