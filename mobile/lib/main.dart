import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/student/main_navigation_screen.dart';
import 'screens/teacher/teacher_main_navigation.dart';
import 'screens/hod/hod_main_navigation.dart';
import 'services/api_service.dart';

void main() {
  runApp(const SmartAttendanceApp());
}

class SmartAttendanceApp extends StatelessWidget {
  const SmartAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3C72)),
        useMaterial3: true,
        fontFamily: 'Inter', // Assuming Inter is available or fallback
      ),
      home: const LoginScreen(),
    );
  }
}
