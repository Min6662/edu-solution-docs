import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../services/cache_service.dart';

class EnrolledStudentsScreen extends StatefulWidget {
  final String classId;
  final String className;

  const EnrolledStudentsScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<EnrolledStudentsScreen> createState() => _EnrolledStudentsScreenState();
}

class _EnrolledStudentsScreenState extends State<EnrolledStudentsScreen> {
  bool loading = true;
  String error = '';
  List<EnrolledStudent> enrolledStudents = [];

  @override
  void initState() {
    super.initState();
    _loadEnrolledStudentsInstant();
  }

  void _loadEnrolledStudentsInstant() async {
    // Try to load from cache using CacheService
    final cached = CacheService.getEnrolledStudents(widget.classId);
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        enrolledStudents = cached
            .map((e) => EnrolledStudent(
                  name: e['name'] ?? '',
                  studentId: e['studentId'] ?? '',
                  enrolmentId: e['enrolmentId'] ?? '',
                ))
            .toList();
        loading = false;
      });
    } else {
      setState(() {
        error = 'No cached data available. Please refresh to fetch data.';
        loading = false;
      });
    }
  }

  Future<void> _fetchEnrolledStudents() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      // First, get all enrolments for this class
      final enrolQuery = QueryBuilder<ParseObject>(ParseObject('Enrolment'))
        ..whereEqualTo(
            'class', ParseObject('Class')..objectId = widget.classId);

      // TODO: Add school filtering when multi-tenant system is implemented
      // ..whereEqualTo('school', ParseObject('School')..objectId = currentSchoolId);

      final enrolResponse = await enrolQuery.query();

      if (enrolResponse.success && enrolResponse.results != null) {
        List<EnrolledStudent> students = [];
        List<String> studentIds = [];
        Map<String, String> enrolmentIdByStudentId = {};

        // Extract student IDs and enrolment IDs
        for (final enrol in enrolResponse.results!) {
          final studentPointer = enrol.get<ParseObject>('student');
          String? studentId = studentPointer?.objectId;
          String? enrolmentId = enrol.objectId;

          if (studentId != null && enrolmentId != null) {
            studentIds.add(studentId);
            enrolmentIdByStudentId[studentId] = enrolmentId;
          }
        }

        // If we have student IDs, fetch their details
        if (studentIds.isNotEmpty) {
          final studentQuery = QueryBuilder<ParseObject>(ParseObject('Student'))
            ..whereContainedIn('objectId', studentIds);

          // TODO: Add school filtering when multi-tenant system is implemented
          // ..whereEqualTo('school', ParseObject('School')..objectId = currentSchoolId);

          final studentResponse = await studentQuery.query();

          if (studentResponse.success && studentResponse.results != null) {
            for (final studentObj in studentResponse.results!) {
              final name = studentObj.get<String>('name') ?? '';
              final studentId = studentObj.objectId;
              final enrolmentId = enrolmentIdByStudentId[studentId];

              if (name.isNotEmpty && studentId != null && enrolmentId != null) {
                students.add(EnrolledStudent(
                  name: name,
                  studentId: studentId,
                  enrolmentId: enrolmentId,
                ));
              }
            }
          }
        }

        setState(() {
          enrolledStudents = students;
          loading = false;
        });

        // Save to cache using CacheService
        await CacheService.saveEnrolledStudents(
          widget.classId,
          students
              .map((e) => {
                    'name': e.name,
                    'studentId': e.studentId,
                    'enrolmentId': e.enrolmentId,
                  })
              .toList(),
        );
      } else {
        setState(() {
          error = 'Failed to fetch enrolled students.';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    // Clear cache and fetch fresh data
    await CacheService.clearEnrolledStudents(widget.classId);
    await _fetchEnrolledStudents();
  }

  Future<void> _removeStudent(String enrolmentId, String studentName) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text(
            'Are you sure you want to remove $studentName from ${widget.className}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() {
        loading = true;
      });

      final enrolment = ParseObject('Enrolment')..objectId = enrolmentId;
      final response = await enrolment.delete();

      if (response.success) {
        await _fetchEnrolledStudents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('$studentName removed from ${widget.className}')),
          );
        }
      } else {
        setState(() {
          loading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to remove student: ${response.error?.message ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} - Enrolled Students'),
        backgroundColor: Colors.orange[400],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh List',
            onPressed: () async {
              await CacheService.clearEnrolledStudents(widget.classId);
              _fetchEnrolledStudents();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.orange[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.className,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${enrolledStudents.length} student${enrolledStudents.length != 1 ? 's' : ''} enrolled',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Student list
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(
                              error,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchEnrolledStudents,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : enrolledStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No students enrolled in ${widget.className}',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Students can be enrolled from the main dashboard',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[500]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: enrolledStudents.length,
                            itemBuilder: (context, index) {
                              final student = enrolledStudents[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue[100],
                                    child: Text(
                                      student.name.isNotEmpty
                                          ? student.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    student.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Student ID: ${student.studentId}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red),
                                    tooltip: 'Remove from class',
                                    onPressed: loading
                                        ? null
                                        : () => _removeStudent(
                                              student.enrolmentId,
                                              student.name,
                                            ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        backgroundColor: Colors.orange[400],
        tooltip: 'Add Student to Class',
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Future<void> _showAddStudentDialog() async {
    // First, fetch all available students
    List<ParseObject> allStudents = [];
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Student'));
      final response = await query.query();

      if (response.success && response.results != null) {
        allStudents = response.results!.cast<ParseObject>();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load students: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Filter out students already enrolled in this class
    final enrolledStudentIds = enrolledStudents.map((e) => e.studentId).toSet();
    final availableStudents = allStudents
        .where((student) => !enrolledStudentIds.contains(student.objectId))
        .toList();

    if (availableStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available students to add to this class'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show dialog with available students
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_add,
                      color: Colors.orange[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Student',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Select a student to enroll in ${widget.className}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Search bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[500]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search students...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          // TODO: Implement search functionality
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Students count
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${availableStudents.length} available students',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Students list
              Expanded(
                child: ListView.separated(
                  itemCount: availableStudents.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = availableStudents[index];
                    final studentName =
                        student.get<String>('name') ?? 'Unknown';
                    final studentId = student.objectId ?? '';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[300]!, Colors.blue[600]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Center(
                              child: Text(
                                studentName.isNotEmpty
                                    ? studentName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Student info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: $studentId',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Add button
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange[400]!,
                                  Colors.orange[600]!
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await _enrollStudent(student);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  child: const Text(
                                    'Add',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Bottom actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enrollStudent(ParseObject student) async {
    final studentName = student.get<String>('name') ?? 'Unknown';

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(50),
                ),
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.orange[400]!),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Enrolling Student',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Adding $studentName to ${widget.className}...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Create enrollment record
      final enrollment = ParseObject('Enrolment')
        ..set('student', student)
        ..set('class', ParseObject('Class')..objectId = widget.classId)
        ..set('studentName', studentName);

      final response = await enrollment.save();

      // Close loading dialog
      Navigator.of(context).pop();

      if (response.success) {
        // Refresh the student list
        await _fetchEnrolledStudents();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$studentName enrolled in ${widget.className} successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to enroll student: ${response.error?.message ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enrolling student: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class EnrolledStudent {
  final String name;
  final String studentId;
  final String enrolmentId;

  EnrolledStudent({
    required this.name,
    required this.studentId,
    required this.enrolmentId,
  });
}
