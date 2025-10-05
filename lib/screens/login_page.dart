import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';
import 'signup_page.dart';
import '../screens/admin_dashboard.dart';
import '../screens/student_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Remove auto-login logic since RoleBasedHome handles authentication
  }

  // Auto-login logic removed - RoleBasedHome handles authentication
  /*
  Future<void> _checkSessionAndAutoLogin() async {
    final box = await Hive.openBox('userSessionBox');
    final sessionToken = box.get('sessionToken');
    final username = box.get('username');
    final role = box.get('role');
    if (sessionToken != null && username != null && role != null) {
      // Optionally, validate sessionToken with Parse if needed
      if (role == 'admin') {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const AdminDashboard(currentIndex: 0)));
      } else if (role == 'teacher') {
        // Teachers should also go to AdminDashboard with limited access
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const AdminDashboard(currentIndex: 0)));
      } else {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const StudentDashboard(currentIndex: 2)));
      }
    }
  }
  */

  Future<void> loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final user = ParseUser(email, password, email);
    final response = await user.login();
    if (response.success && response.result != null) {
      final role = response.result.get<String>('role');
      // Cache session info in Hive
      final box = await Hive.openBox('userSessionBox');
      await box.put('sessionToken', user.sessionToken);
      await box.put('username', email);
      await box.put('role', role);

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const AdminDashboard(currentIndex: 0)));
      } else if (role == 'teacher') {
        // Teachers should also go to AdminDashboard with limited access
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const AdminDashboard(currentIndex: 0)));
      } else {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const StudentDashboard(currentIndex: 2)));
      }
    } else {
      if (!mounted) return;
      setState(() {
        errorMessage = response.error?.message ?? 'Login failed';
      });
    }
  }

  // Add this logout function to clear session
  Future<void> logoutUser() async {
    final box = await Hive.openBox('userSessionBox');
    await box.clear();
    // Optionally, also log out from Parse
    await ParseUser.currentUser()
      ..logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Center(
              child: Image.asset(
                'assets/logo.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade200, blurRadius: 12)
                ],
              ),
              child: Column(
                children: [
                  Text('Login',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900])),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: loginUser,
                      child:
                          const Text('Login', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final box = await Hive.openBox('userSessionBox');
                      await box.clear();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupPage()),
                      );
                    },
                    child: const Text('Don\'t have an account? Sign Up'),
                  ),
                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(errorMessage,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
