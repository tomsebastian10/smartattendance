import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../student/main_navigation_screen.dart';
import '../teacher/teacher_main_navigation.dart';
import '../hod/hod_main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      // For MVP, we'll use a hardcoded device hash for testing
      // In production, this would be generated from hardware IDs
      final deviceHash = "test_device_hash_123"; 
      final response = await _apiService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        deviceHash,
      );
      
      if (mounted) {
        final role = response['user']['role'];
        Widget nextScreen;
        if (role == 'STUDENT') {
          nextScreen = const StudentMainNavigation();
        } else if (role == 'ADMIN') {
          nextScreen = const HodMainNavigation();
        } else {
          nextScreen = const TeacherMainNavigation();
        }
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person_rounded, size: 80, color: Colors.white),
                const SizedBox(height: 24),
                const Text(
                  'Smart Attendance',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure • Reliable • Automated',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 48),
                _buildTextField(_emailController, 'Email', Icons.email_outlined),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, 'Password', Icons.lock_outline, isObscure: true),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3C72),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'LOGIN',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    final emailCtrl = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Reset Password'),
                        content: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Enter your email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Reset link sent to ${emailCtrl.text}')),
                              );
                            },
                            child: const Text('Send Reset Link'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isObscure = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }
}
