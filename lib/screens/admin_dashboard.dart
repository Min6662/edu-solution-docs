import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../widgets/modern_dashboard.dart';
import 'settings_screen.dart';
import 'student_dashboard.dart';
import '../views/class_list.dart';
import '../screens/assign_student_to_class_screen.dart';
import 'student_attendance_screen.dart';
import 'teacher_qr_scan_screen.dart';
import 'teacher_detail_screen.dart'; // For teacher card navigation
import '../models/teacher.dart'; // For Teacher model

class AdminDashboard extends StatefulWidget {
  final int currentIndex;
  const AdminDashboard({super.key, this.currentIndex = 0});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<ParseObject> teachers = [];
  bool loading = true;
  String error = '';
  int studentCount = 0;
  int classCount = 0;
  String? userRole; // Add userRole variable

  // Caching for teachers
  List<ParseObject>? _cachedTeachers;
  // Caching for student count
  int? _cachedStudentCount;
  // Caching for class count
  int? _cachedClassCount;
  // --- End caching fields ---

  @override
  void initState() {
    super.initState();
    _fetchUserRole(); // Fetch user role
    _fetchTeachers();
    _fetchStudentCount();
    _fetchClassCount();
  }

  Future<void> _fetchUserRole() async {
    final user = await ParseUser.currentUser();
    final role = user?.get<String>('role');
    print('DEBUG: Fetched userRole: $role');
    setState(() {
      userRole = role;
    });
  }

  Future<void> _fetchTeachers() async {
    // Show cached value immediately if available
    if (_cachedTeachers != null) {
      setState(() {
        teachers = _cachedTeachers!;
        loading = false;
      });
    } else {
      setState(() {
        loading = true;
        error = '';
      });
    }
    // Always fetch latest in background
    final query = QueryBuilder<ParseObject>(ParseObject('Teacher'));
    final response = await query.query();
    if (response.success && response.results != null) {
      final fetchedTeachers = response.results!.cast<ParseObject>();
      _cachedTeachers = fetchedTeachers;
      setState(() {
        teachers = fetchedTeachers;
        loading = false;
      });
    } else if (_cachedTeachers == null) {
      setState(() {
        error = 'Failed to fetch teachers.';
        loading = false;
      });
    }
  }

  Future<void> _fetchStudentCount() async {
    if (_cachedStudentCount != null) {
      setState(() {
        studentCount = _cachedStudentCount!;
      });
    }
    final query = QueryBuilder<ParseObject>(ParseObject('Student'));
    final response = await query.count();
    if (response.success) {
      _cachedStudentCount = response.count;
      setState(() {
        studentCount = response.count;
      });
    }
  }

  Future<void> _fetchClassCount() async {
    if (_cachedClassCount != null) {
      setState(() {
        classCount = _cachedClassCount!;
      });
    }
    final query = QueryBuilder<ParseObject>(ParseObject('Class'));
    final response = await query.count();
    if (response.success) {
      _cachedClassCount = response.count;
      setState(() {
        classCount = response.count;
      });
    }
  }

  Widget _teacherListWidget() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error.isNotEmpty) {
      return Center(
          child: Text(error, style: const TextStyle(color: Colors.red)));
    }
    if (teachers.isEmpty) {
      return const Center(child: Text('No teachers found.'));
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: teachers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final teacher = teachers[index];
          final name = teacher.get<String>('fullName') ?? '';
          final photoUrl = teacher.get<String>('photo');
          final subject = teacher.get<String>('subject') ?? '';
          final gender = teacher.get<String>('gender') ?? '';
          final years = teacher.get<int>('yearsOfExperience') ?? 0;
          return GestureDetector(
            onTap: () {
              // Create Teacher model from ParseObject
              final teacherModel = Teacher(
                objectId: teacher.objectId!,
                fullName: name,
                gender: gender,
                subject: subject,
                address: teacher.get<String>('Address'),
                email: teacher.get<String>('email'),
                photoUrl: photoUrl,
                joinDate: teacher.get<DateTime>('hireDate'),
              );

              // Navigate to teacher detail screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TeacherDetailScreen(teacher: teacherModel),
                ),
              );
            },
            child: Card(
              elevation: 2,
              child: IntrinsicWidth(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          width: 112,
                          height: 112,
                          child: (photoUrl != null && photoUrl.isNotEmpty)
                              ? Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2),
                            Text('Subject: $subject',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2),
                            Text('Gender: $gender',
                                style: const TextStyle(fontSize: 12)),
                            Text('Experience: $years years',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: const Text(
                                'Tap to view details',
                                style:
                                    TextStyle(fontSize: 10, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wait for userRole to be fetched before building the dashboard
    if (userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    print('DEBUG: Building AdminDashboard with userRole: $userRole');

    return ModernDashboard(
      title: 'Assalam School',
      subtitle: 'Over view',
      userRole: userRole, // Pass userRole to ModernDashboard
      activities: [
        {'title': 'Students', 'desc': 'Total: $studentCount'},
        {'title': 'Teachers', 'desc': 'Total: ${teachers.length}'},
        {'title': 'Classes', 'desc': 'Total: $classCount'},
      ],
      users: const [],
      items: const [],
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.black),
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()));
          },
        ),
      ],
      currentIndex: widget.currentIndex,
      onTabSelected: (index) {
        if (index == 0) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => const AdminDashboard(currentIndex: 0)));
        } else if (index == 1) {
          // Navigation handled by AppBottomNavigation widget
          // No need for additional access control here
          print('DEBUG: Tab 1 selected - delegating to AppBottomNavigation');
        } else if (index == 2) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => const StudentDashboard(currentIndex: 2)));
        } else if (index == 3) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()));
        }
      },
      onClassTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClassList()),
        );
      },
      onStudentTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const StudentDashboard(currentIndex: 2)),
        );
      },
      onExamResultTap: () {
        // TODO: Implement exam result navigation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam Result card clicked')),
        );
      },
      onEnrolmentsTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AssignStudentToClassScreen()),
        );
      },
      onQRScanTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeacherQRScanScreen()),
        );
      },
      onStudentAttendanceTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentAttendanceScreen()),
        );
      },
    );
  }
}
