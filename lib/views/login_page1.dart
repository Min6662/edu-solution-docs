import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';
import '../screens/admin_dashboard.dart';
import '../screens/student_dashboard.dart';
import '../screens/signup_page.dart';

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
    _checkSessionAndAutoLogin();
  }

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
    }
  }

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
      setState(() {
        errorMessage = response.error?.message ?? 'Login failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 120, height: 120),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    const CircleAvatar(
                      radius: 36,
                      backgroundImage: AssetImage('assets/university_logo.png'),
                      backgroundColor: Colors.transparent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Columbia University',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Colors.blue[700],
                                ),
                                onPressed: loginUser,
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const SignupPage()));
                              },
                              child:
                                  const Text("Don't have an account? Sign Up"),
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
