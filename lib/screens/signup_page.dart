import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController roleIdController = TextEditingController();
  String selectedRole = 'student';
  String errorMessage = '';

  @override
  void dispose() {
    roleIdController.dispose();
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  Future<void> signupUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final username = usernameController.text.trim();
    final roleId = roleIdController.text.trim();

    if (selectedRole != 'owner' && roleId.isEmpty) {
      setState(() {
        errorMessage = 'ID is required for the selected role';
      });
      return;
    }

    final user = ParseUser.createUser(username, password, email);
    user.set('role', selectedRole);
    user.set('roleId', roleId);

    // TODO: Replace with actual school selection when multi-tenant system is implemented
    // For now, this will be null until school selection is implemented
    // user.set('school', ParseObject('School')..objectId = selectedSchoolId);

    final response = await user.signUp();
    if (response.success) {
      // Cache user session token and info in Hive
      final box = await Hive.openBox('userSessionBox');
      await box.put('sessionToken', user.sessionToken);
      await box.put('username', username);
      await box.put('role', selectedRole);
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginPage()));
    } else {
      setState(() {
        errorMessage = response.error?.message ?? 'Signup failed';
      });
    }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.school, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 12),
                Text('Assalam School',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900])),
              ],
            ),
            const SizedBox(height: 32),
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
                  Text('Sign Up',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900])),
                  const SizedBox(height: 24),
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(
                          value: 'teacher', child: Text('Teacher')),
                      DropdownMenuItem(
                          value: 'student', child: Text('Student')),
                      DropdownMenuItem(value: 'owner', child: Text('Owner')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedRole = val ?? 'student';
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                  if (selectedRole != 'owner')
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        TextField(
                          controller: roleIdController,
                          decoration: InputDecoration(
                            labelText:
                                '${selectedRole[0].toUpperCase()}${selectedRole.substring(1)} ID',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ],
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
                      onPressed: signupUser,
                      child:
                          const Text('Sign Up', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => const LoginPage()));
                    },
                    child: const Text('Already have an account? Login'),
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
