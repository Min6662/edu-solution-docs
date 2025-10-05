import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'dart:math' as math;

class TeacherRegistrationScreen extends StatefulWidget {
  const TeacherRegistrationScreen({super.key});

  @override
  State<TeacherRegistrationScreen> createState() =>
      _TeacherRegistrationScreenState();
}

class _TeacherRegistrationScreenState extends State<TeacherRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _experienceController = TextEditingController();

  String _selectedGender = 'Male';
  List<ParseObject> _availableClasses = [];
  List<String> _selectedClassIds = [];
  bool _loading = false;
  bool _loadingClasses = true;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
    _generateCredentials();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _fetchClasses() async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Class'));
      final response = await query.query();

      if (response.success && response.results != null) {
        setState(() {
          _availableClasses = response.results!.cast<ParseObject>();
          _loadingClasses = false;
        });
      } else {
        setState(() {
          _loadingClasses = false;
        });
        _showError('Failed to load classes: ${response.error?.message}');
      }
    } catch (e) {
      setState(() {
        _loadingClasses = false;
      });
      _showError('Error loading classes: $e');
    }
  }

  void _generateCredentials() {
    // Generate username based on timestamp
    final timestamp =
        DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    _usernameController.text = 'teacher$timestamp';

    // Generate random password
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = math.Random();
    final password = String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
    _passwordController.text = password;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassIds.isEmpty) {
      _showError('Please assign at least one class to the teacher');
      return;
    }

    setState(() => _loading = true);

    try {
      // 1. Create Parse User account for teacher
      final user = ParseUser.createUser(
        _usernameController.text.trim(),
        _passwordController.text,
        _emailController.text.trim(),
      );
      user.set('role', 'teacher');
      user.set('name', _nameController.text.trim());
      user.set('plainPassword',
          _passwordController.text); // Store plain password for admin access

      final userResponse = await user.signUp();
      if (!userResponse.success) {
        throw Exception(
            'Failed to create user account: ${userResponse.error?.message}');
      }

      // 2. Create Teacher record
      final teacher = ParseObject('Teacher')
        ..set('fullName', _nameController.text.trim())
        ..set('email', _emailController.text.trim())
        ..set('subject', _subjectController.text.trim())
        ..set('phoneNumber', _phoneController.text.trim())
        ..set('gender', _selectedGender)
        ..set(
            'yearsOfExperience', int.tryParse(_experienceController.text) ?? 0)
        ..set('userId',
            userResponse.result.toPointer()) // Link to Parse User with pointer
        ..set('username', _usernameController.text.trim())
        ..set('isActive', true)
        ..set('createdAt', DateTime.now());

      final teacherResponse = await teacher.save();
      if (!teacherResponse.success) {
        throw Exception(
            'Failed to create teacher record: ${teacherResponse.error?.message}');
      }

      // 3. Assign classes to teacher
      await _assignClassesToTeacher(teacherResponse.result as ParseObject);

      _showSuccess(
          '✅ Teacher account created successfully!\\n\\n👤 Username: ${_usernameController.text.trim()}\\n🔐 Password: ${_passwordController.text}');

      // Return success to refresh the teacher list
      Navigator.of(context).pop(true);
    } catch (e) {
      _showError('Error creating teacher: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _assignClassesToTeacher(ParseObject teacher) async {
    for (String classId in _selectedClassIds) {
      try {
        // Create teacher-class assignment record
        final assignment = ParseObject('TeacherClassAssignment')
          ..set('teacher', teacher)
          ..set('class', ParseObject('Class')..objectId = classId)
          ..set('assignedAt', DateTime.now())
          ..set('isActive', true);

        await assignment.save();
      } catch (e) {
        print('Error assigning class $classId to teacher: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Teacher Account'),
        backgroundColor: Colors.blue[900],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Enter teacher full name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value!.isEmpty) return 'Enter email address';
                        if (!value.contains('@')) return 'Enter valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Subject
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Enter subject' : null,
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Years of Experience
                    TextFormField(
                      controller: _experienceController,
                      decoration: const InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Gender
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Male', 'Female', 'Other'].map((gender) {
                        return DropdownMenuItem(
                            value: gender, child: Text(gender));
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedGender = value!),
                    ),
                    const SizedBox(height: 16),

                    // Username (read-only)
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username (Auto-generated)',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    // Password (read-only)
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password (Auto-generated)',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    // Class Assignment
                    const Text('Assign Classes:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    if (_loadingClasses)
                      const Center(child: CircularProgressIndicator())
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: _availableClasses.length,
                          itemBuilder: (context, index) {
                            final classObj = _availableClasses[index];
                            final classId = classObj.objectId!;
                            final className =
                                classObj.get<String>('classname') ??
                                    'Unknown Class';

                            return CheckboxListTile(
                              title: Text(className),
                              value: _selectedClassIds.contains(classId),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedClassIds.add(classId);
                                  } else {
                                    _selectedClassIds.remove(classId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _loading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create Teacher Account',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
