import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../main.dart'; // Import to access RoleBasedHome

class TeacherLimitedDashboard extends StatefulWidget {
  const TeacherLimitedDashboard({super.key});

  @override
  State<TeacherLimitedDashboard> createState() =>
      _TeacherLimitedDashboardState();
}

class _TeacherLimitedDashboardState extends State<TeacherLimitedDashboard> {
  List<Map<String, dynamic>> _assignedClasses = [];
  Map<String, List<Map<String, dynamic>>> _classStudents = {};
  bool _loading = true;
  String _error = '';
  String? _teacherId;
  String? _teacherName;

  @override
  void initState() {
    super.initState();
    _fetchTeacherData();
  }

  Future<void> _fetchTeacherData() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      // Get current user and find teacher record
      final user = await ParseUser.currentUser();
      if (user == null) {
        throw Exception('No user logged in');
      }

      final userId = user.objectId;
      final username = user.username;
      _teacherName = user.get<String>('name') ?? username;

      print(
          'DEBUG: Looking for teacher with userId: $userId, username: $username');

      // Try multiple methods to find the teacher record
      ParseObject? teacherObj;

      // Method 1: Find by userId (preferred method)
      print('DEBUG: Creating query for Teacher table with userId pointer');
      final teacherQueryByUserId =
          QueryBuilder<ParseObject>(ParseObject('Teacher'))
            ..whereEqualTo(
                'userId', user.toPointer()); // Use pointer instead of string
      print('DEBUG: Executing userId query...');
      final teacherResponseByUserId = await teacherQueryByUserId.query();

      print(
          'DEBUG: userId query response - Success: ${teacherResponseByUserId.success}');
      print(
          'DEBUG: userId query response - Count: ${teacherResponseByUserId.count}');
      print(
          'DEBUG: userId query response - Results length: ${teacherResponseByUserId.results?.length ?? 0}');
      if (!teacherResponseByUserId.success) {
        print(
            'DEBUG: userId query error: ${teacherResponseByUserId.error?.message}');
      }

      if (teacherResponseByUserId.success &&
          teacherResponseByUserId.results != null &&
          teacherResponseByUserId.results!.isNotEmpty) {
        teacherObj = teacherResponseByUserId.results!.first as ParseObject;
        print('DEBUG: Found teacher by userId: ${teacherObj.objectId}');
      } else {
        // Method 2: Find by username (fallback method)
        print('DEBUG: Teacher not found by userId, trying username: $username');
        final teacherQueryByUsername =
            QueryBuilder<ParseObject>(ParseObject('Teacher'))
              ..whereEqualTo('username', username);
        print('DEBUG: Executing username query...');
        final teacherResponseByUsername = await teacherQueryByUsername.query();

        print(
            'DEBUG: username query response - Success: ${teacherResponseByUsername.success}');
        print(
            'DEBUG: username query response - Count: ${teacherResponseByUsername.count}');
        print(
            'DEBUG: username query response - Results length: ${teacherResponseByUsername.results?.length ?? 0}');
        if (!teacherResponseByUsername.success) {
          print(
              'DEBUG: username query error: ${teacherResponseByUsername.error?.message}');
        }

        if (teacherResponseByUsername.success &&
            teacherResponseByUsername.results != null &&
            teacherResponseByUsername.results!.isNotEmpty) {
          teacherObj = teacherResponseByUsername.results!.first as ParseObject;
          print('DEBUG: Found teacher by username: ${teacherObj.objectId}');

          // Update the teacher record with the userId for future lookups
          print('DEBUG: Updating teacher record with userId pointer...');
          teacherObj.set(
              'userId', user.toPointer()); // Use pointer instead of string
          final updateResponse = await teacherObj.save();
          if (updateResponse.success) {
            print('DEBUG: Successfully updated teacher record with userId');
          } else {
            print(
                'DEBUG: Failed to update teacher record: ${updateResponse.error?.message}');
          }
        }
      }

      if (teacherObj == null) {
        // If still not found, create a basic teacher record
        print('DEBUG: No teacher record found, creating one...');
        print('DEBUG: Teacher data to save:');
        print('  - fullName: ${_teacherName ?? 'Unknown Teacher'}');
        print(
            '  - email: ${user.get<String>('email') ?? user.emailAddress ?? ''}');
        print('  - userId: Pointer to User ${userId}');
        print('  - username: $username');

        try {
          final newTeacher = ParseObject('Teacher')
            ..set('fullName', _teacherName ?? 'Unknown Teacher')
            ..set('email', user.get<String>('email') ?? user.emailAddress ?? '')
            ..set('userId',
                user.toPointer()) // Use a pointer to the User object instead of string
            ..set('username', username)
            ..set('isActive', true)
            ..set('createdAt', DateTime.now());

          print('DEBUG: Attempting to save teacher record to Parse...');
          final createResponse = await newTeacher.save();

          print('DEBUG: Save response - Success: ${createResponse.success}');
          print(
              'DEBUG: Save response - StatusCode: ${createResponse.statusCode}');

          if (createResponse.success) {
            teacherObj = createResponse.result as ParseObject;
            print(
                'DEBUG: Successfully created new teacher record: ${teacherObj.objectId}');
          } else {
            print(
                'DEBUG: Failed to create teacher record: ${createResponse.error?.message}');
            print('DEBUG: Error code: ${createResponse.error?.code}');
            print('DEBUG: Error type: ${createResponse.error?.type}');
            throw Exception(
                'Failed to create teacher record: ${createResponse.error?.message ?? 'Unknown error'}');
          }
        } catch (createError) {
          print('DEBUG: Exception during teacher creation: $createError');
          print('DEBUG: Exception type: ${createError.runtimeType}');

          // If creation fails, create a minimal teacher record for this session only
          // This allows the teacher to use the app even if database save fails
          print('DEBUG: Creating temporary teacher record...');
          teacherObj = ParseObject('Teacher')
            ..objectId =
                'temp_${userId}_${DateTime.now().millisecondsSinceEpoch}'
            ..set('fullName', _teacherName ?? 'Unknown Teacher')
            ..set('email', user.get<String>('email') ?? user.emailAddress ?? '')
            ..set('userId', user.toPointer()) // Use pointer for consistency
            ..set('username', username)
            ..set('isActive', true);

          print('DEBUG: Using temporary teacher ID: ${teacherObj.objectId}');

          // Show a warning to the user about the temporary state
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '⚠️ Running in temporary mode. Some features may be limited. '
                    'Please contact your administrator.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          });
        }
      }

      _teacherId = teacherObj.objectId;
      print('DEBUG: Using teacher ID: $_teacherId');

      // Fetch assigned classes for this teacher
      await _fetchAssignedClasses();

      setState(() => _loading = false);
    } catch (e) {
      print('DEBUG: Error in _fetchTeacherData: $e');
      setState(() {
        _error = 'Error loading teacher data: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fetchAssignedClasses() async {
    if (_teacherId == null) return;

    try {
      // Fetch classes assigned to this teacher using TeacherClassAssignment
      final assignmentQuery = QueryBuilder<ParseObject>(
          ParseObject('TeacherClassAssignment'))
        ..whereEqualTo('teacher', ParseObject('Teacher')..objectId = _teacherId)
        ..whereEqualTo('isActive', true)
        ..includeObject(['class']);

      final assignmentResponse = await assignmentQuery.query();

      List<Map<String, dynamic>> classes = [];

      if (assignmentResponse.success && assignmentResponse.results != null) {
        for (var assignment in assignmentResponse.results!) {
          final classObj = assignment.get<ParseObject>('class');
          if (classObj != null) {
            final classData = {
              'objectId': classObj.objectId,
              'classname': classObj.get<String>('classname') ?? 'Unknown Class',
              'assignedAt': assignment.get<DateTime>('assignedAt'),
            };
            classes.add(classData);

            // Fetch students for this class
            await _fetchStudentsForClass(classObj.objectId!);
          }
        }
      }

      // If no TeacherClassAssignment records found, try the old method (teacherPointers in Class)
      if (classes.isEmpty) {
        await _fetchClassesFromClassPointers();
      } else {
        setState(() => _assignedClasses = classes);
      }
    } catch (e) {
      print('Error fetching assigned classes: $e');
    }
  }

  Future<void> _fetchClassesFromClassPointers() async {
    if (_teacherId == null) return;

    try {
      // Query classes where this teacher is in teacherPointers
      final classQuery = QueryBuilder<ParseObject>(ParseObject('Class'));
      final classResponse = await classQuery.query();

      List<Map<String, dynamic>> classes = [];

      if (classResponse.success && classResponse.results != null) {
        for (var classObj in classResponse.results!) {
          final teacherPointers =
              classObj.get<List<dynamic>>('teacherPointers') ?? [];

          // Check if this teacher is assigned to this class
          bool isAssigned = false;
          for (var pointer in teacherPointers) {
            if (pointer is Map<String, dynamic> &&
                pointer['objectId'] == _teacherId) {
              isAssigned = true;
              break;
            }
          }

          if (isAssigned) {
            final classData = {
              'objectId': classObj.objectId,
              'classname': classObj.get<String>('classname') ?? 'Unknown Class',
              'assignedAt': null, // No assignment date in this method
            };
            classes.add(classData);

            // Fetch students for this class
            await _fetchStudentsForClass(classObj.objectId!);
          }
        }
      }

      setState(() => _assignedClasses = classes);
    } catch (e) {
      print('Error fetching classes from pointers: $e');
    }
  }

  Future<void> _fetchStudentsForClass(String classId) async {
    try {
      // Query Enrollment table to get students in this class
      final enrollmentQuery =
          QueryBuilder<ParseObject>(ParseObject('Enrollment'))
            ..whereEqualTo('class', ParseObject('Class')..objectId = classId)
            ..includeObject(['student']);

      final enrollmentResponse = await enrollmentQuery.query();

      List<Map<String, dynamic>> students = [];

      if (enrollmentResponse.success && enrollmentResponse.results != null) {
        for (var enrollment in enrollmentResponse.results!) {
          final studentObj = enrollment.get<ParseObject>('student');
          if (studentObj != null) {
            students.add({
              'objectId': studentObj.objectId,
              'name': studentObj.get<String>('name') ?? 'Unknown Student',
              'grade': studentObj.get<String>('grade') ?? '',
              'enrolledAt': enrollment.get<DateTime>('createdAt'),
            });
          }
        }
      }

      setState(() {
        _classStudents[classId] = students;
      });
    } catch (e) {
      print('Error fetching students for class $classId: $e');
    }
  }

  Future<void> _markAttendance(String classId, String className) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherAttendanceScreen(
          classId: classId,
          className: className,
          students: _classStudents[classId] ?? [],
        ),
      ),
    );
  }

  Future<void> _viewGrades(String classId, String className) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherGradesScreen(
          classId: classId,
          className: className,
          students: _classStudents[classId] ?? [],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final user = await ParseUser.currentUser();
      if (user != null) {
        await user.logout();
      }
      if (mounted) {
        // Navigate to the main app entry point, clearing all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoleBasedHome()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Teacher Dashboard'),
          backgroundColor: Colors.blue[900],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Unable to load teacher data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This might happen if your teacher account is not properly set up.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Debug info: $_error',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _fetchTeacherData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        // Show debug information
                        final user = await ParseUser.currentUser();
                        if (user != null) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Debug Information'),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('User ID: ${user.objectId ?? 'N/A'}'),
                                    Text('Username: ${user.username ?? 'N/A'}'),
                                    Text(
                                        'Email: ${user.get<String>('email') ?? user.emailAddress ?? 'N/A'}'),
                                    Text(
                                        'Role: ${user.get<String>('role') ?? 'N/A'}'),
                                    Text(
                                        'Name: ${user.get<String>('name') ?? 'N/A'}'),
                                    const SizedBox(height: 16),
                                    const Text('Teacher Info:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        'Teacher ID: ${_teacherId ?? 'Not found'}'),
                                    Text(
                                        'Teacher Name: ${_teacherName ?? 'N/A'}'),
                                    Text(
                                        'Assigned Classes: ${_assignedClasses.length}'),
                                    const SizedBox(height: 16),
                                    const Text('App State:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text('Loading: $_loading'),
                                    Text('Has Error: ${_error.isNotEmpty}'),
                                    const SizedBox(height: 16),
                                    const Text('All User Data:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text('${user.toJson()}'),
                                    const SizedBox(height: 16),
                                    const Text('Error Details:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(_error),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Debug'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Navigate to settings or logout
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.info, color: Colors.orange[700]),
                        const SizedBox(height: 8),
                        Text(
                          'If this problem persists, please contact your administrator.',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $_teacherName'),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTeacherData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _assignedClasses.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No classes assigned yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please contact your administrator',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Teacher Dashboard',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'You have ${_assignedClasses.length} assigned class${_assignedClasses.length == 1 ? '' : 'es'}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'My Assigned Classes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...(_assignedClasses.map((classData) {
                    final classId = classData['objectId'];
                    final className = classData['classname'];
                    final students = _classStudents[classId] ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.class_,
                                    color: Colors.blue[900], size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    className,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Text(
                              'Students: ${students.length}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),

                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _markAttendance(classId, className),
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('Attendance'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _viewGrades(classId, className),
                                    icon: const Icon(Icons.grade),
                                    label: const Text('Grades'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // View students button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TeacherStudentListScreen(
                                        classId: classId,
                                        className: className,
                                        students: students,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.people),
                                label:
                                    Text('View Students (${students.length})'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList()),
                ],
              ),
            ),
    );
  }
}

// Placeholder screens - these would be implemented separately
class TeacherAttendanceScreen extends StatelessWidget {
  final String classId;
  final String className;
  final List<Map<String, dynamic>> students;

  const TeacherAttendanceScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - $className'),
      ),
      body: Center(
        child: Text(
            'Attendance screen for $className\\nStudents: ${students.length}'),
      ),
    );
  }
}

class TeacherGradesScreen extends StatelessWidget {
  final String classId;
  final String className;
  final List<Map<String, dynamic>> students;

  const TeacherGradesScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grades - $className'),
      ),
      body: Center(
        child:
            Text('Grades screen for $className\\nStudents: ${students.length}'),
      ),
    );
  }
}

class TeacherStudentListScreen extends StatelessWidget {
  final String classId;
  final String className;
  final List<Map<String, dynamic>> students;

  const TeacherStudentListScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Students - $className'),
      ),
      body: students.isEmpty
          ? const Center(
              child: Text('No students enrolled in this class'),
            )
          : ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(student['name'][0].toUpperCase()),
                  ),
                  title: Text(student['name']),
                  subtitle: Text('Grade: ${student['grade']}'),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to student details
                  },
                );
              },
            ),
    );
  }
}
