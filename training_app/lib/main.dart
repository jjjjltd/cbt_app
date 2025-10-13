import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MotorcycleTrainingApp());
}

class MotorcycleTrainingApp extends StatelessWidget {
  const MotorcycleTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      title: 'Motorcycle Training',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: LoginScreen(authService: authService),
      debugShowCheckedModeBanner: false,
    );
  }
}