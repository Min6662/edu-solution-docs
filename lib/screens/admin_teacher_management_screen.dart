import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class AdminTeacherManagementScreen extends StatefulWidget {
  const AdminTeacherManagementScreen({super.key});

  @override
  State<AdminTeacherManagementScreen> createState() =>
      _AdminTeacherManagementScreenState();
}

class _AdminTeacherManagementScreenState
    extends State<AdminTeacherManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedGender = 'Male';
  List<ParseObject> _availableClasses = [];
  List<String> _selectedClassIds = [];
  bool _loading = false;
  bool _loadingClasses = true;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => _loadingClasses = true);
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Class'));
      final response = await query.query();
      if (response.success && response.results != null) {
        setState(() {
          _availableClasses = response.results!.cast<ParseObject>();
          _loadingClasses = false;
        });
      }
    } catch (e) {
      setState(() => _loadingClasses = false);
      _showError('Failed to load classes: $e');
    }
  }

  String _generateUsername(String fullName) {
    // Remove spaces and special characters, convert to lowercase
    String username =
        fullName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();

    // If too short, pad with numbers
    if (username.length < 3) {
      username += '123';
    }

    return username;
  }

  Future<String> _generateUniqueUsername(String fullName) async {
    String baseUsername = _generateUsername(fullName);
    String username = baseUsername;
    int counter = 1;

    // Keep trying until we find a unique username
    while (await _checkUsernameExists(username)) {
      username = baseUsername + counter.toString();
      counter++;
      if (counter > 99) break; // Prevent infinite loop
    }

    return username;
  }

  Future<void> _suggestUsername() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter the teacher name first');
      return;
    }

    setState(() => _loading = true);
    try {
      final suggestedUsername =
          await _generateUniqueUsername(_nameController.text.trim());
      _usernameController.text = suggestedUsername;
      _showSuccess('Username suggestion: $suggestedUsername');
    } catch (e) {
      _showError('Failed to generate username: $e');
    }
    setState(() => _loading = false);
  }

  Future<bool> _checkUsernameExists(String username) async {
    try {
      final query = QueryBuilder<ParseUser>(ParseUser.forQuery())
        ..whereEqualTo('username', username);
      final response = await query.query();
      return response.success &&
          response.results != null &&
          response.results!.isNotEmpty;
    } catch (e) {
      return false; // If error occurs, assume username doesn't exist
    }
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      final query = QueryBuilder<ParseUser>(ParseUser.forQuery())
        ..whereEqualTo('email', email);
      final response = await query.query();
      return response.success &&
          response.results != null &&
          response.results!.isNotEmpty;
    } catch (e) {
      return false; // If error occurs, assume email doesn't exist
    }
  }

  Future<void> _createTeacherAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassIds.isEmpty) {
      _showError('Please assign at least one class to the teacher');
      return;
    }

    setState(() => _loading = true);

    try {
      // Check if username already exists
      final usernameExists =
          await _checkUsernameExists(_usernameController.text.trim());
      if (usernameExists) {
        setState(() => _loading = false);
        _showError(
            '❌ Username "${_usernameController.text.trim()}" already exists.\\n\\n💡 Please choose a different username or use the "Suggest Username" button.');
        return;
      }

      // Check if email already exists
      final emailExists = await _checkEmailExists(_emailController.text.trim());
      if (emailExists) {
        setState(() => _loading = false);
        _showError(
            '❌ Email "${_emailController.text.trim()}" already exists.\\n\\n💡 Please use a different email address.');
        return;
      }

      // 1. Create Parse User account for teacher
      final user = ParseUser.createUser(
        _usernameController.text.trim(),
        _passwordController.text,
        _emailController.text.trim(),
      );
      user.set('role', 'teacher');
      user.set('name', _nameController.text.trim());

      final userResponse = await user.signUp();
      if (!userResponse.success) {
        // Provide more specific error messages
        String errorMessage = 'Failed to create user account';
        if (userResponse.error?.message != null) {
          if (userResponse.error!.message.contains('already exists')) {
            errorMessage =
                '❌ Username or email already exists.\\n\\n💡 Please choose different credentials or use the suggest button.';
          } else {
            errorMessage =
                'Failed to create user account: ${userResponse.error!.message}';
          }
        }
        throw Exception(errorMessage);
      }

      // 2. Create Teacher record
      final teacher = ParseObject('Teacher')
        ..set('fullName', _nameController.text.trim())
        ..set('email', _emailController.text.trim())
        ..set('subject', _subjectController.text.trim())
        ..set('phoneNumber', _phoneController.text.trim())
        ..set('gender', _selectedGender)
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
          '✅ Teacher account created successfully!\\n\\n👤 Username: ${_usernameController.text.trim()}\\n🔐 Password: ${_passwordController.text}\\n\\n📚 Classes assigned: ${_selectedClassIds.length}');
      _clearForm();
    } catch (e) {
      _showError('Error creating teacher: $e');
    }

    setState(() => _loading = false);
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

        // Also update the class to include this teacher in teacherPointers
        final classQuery = QueryBuilder<ParseObject>(ParseObject('Class'))
          ..whereEqualTo('objectId', classId);
        final classResponse = await classQuery.query();

        if (classResponse.success && classResponse.results != null) {
          final classObj = classResponse.results!.first;
          final teacherPointers = List<Map<String, String>>.from(
              classObj.get<List<dynamic>>('teacherPointers') ?? []);

          // Add teacher pointer if not already exists
          final teacherPointer = {
            '__type': 'Pointer',
            'className': 'Teacher',
            'objectId': teacher.objectId!
          };

          if (!teacherPointers.any((p) => p['objectId'] == teacher.objectId)) {
            teacherPointers.add(teacherPointer);
            classObj.set('teacherPointers', teacherPointers);
            await classObj.save();
          }
        }
      } catch (e) {
        print('Error assigning class $classId to teacher: $e');
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _subjectController.clear();
    _phoneController.clear();
    _usernameController.clear();
    _passwordController.clear();
    setState(() {
      _selectedGender = 'Male';
      _selectedClassIds.clear();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Teacher Account'),
        backgroundColor: Colors.blue[900],
      ),
      body: _loadingClasses
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[900]),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Create a new teacher account with login credentials and assign classes.',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Teacher Information',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter teacher name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter email address';
                        }
                        if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject/Specialization',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.book),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter subject';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.wc),
                      ),
                      items: ['Male', 'Female'].map((gender) {
                        return DropdownMenuItem(
                            value: gender, child: Text(gender));
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedGender = value!);
                      },
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Login Credentials',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.account_circle),
                              helperText: 'Teacher will use this to login',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter username';
                              }
                              if (value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _loading ? null : _suggestUsername,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Suggest'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        helperText: 'Minimum 6 characters',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Assign Classes',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select which classes this teacher will be responsible for:',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _availableClasses.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No classes available. Please create classes first.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : Column(
                              children: _availableClasses.map((classObj) {
                                final className =
                                    classObj.get<String>('classname') ??
                                        'Unknown';
                                final classId = classObj.objectId!;

                                return CheckboxListTile(
                                  title: Text(className),
                                  subtitle: Text('Class ID: $classId'),
                                  value: _selectedClassIds.contains(classId),
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedClassIds.add(classId);
                                      } else {
                                        _selectedClassIds.remove(classId);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                    ),
                    if (_selectedClassIds.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green[700]),
                              const SizedBox(width: 8),
                              Text(
                                '${_selectedClassIds.length} class${_selectedClassIds.length == 1 ? '' : 'es'} selected',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _createTeacherAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Create Teacher Account',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
