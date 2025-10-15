import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import '../widgets/modern_dashboard.dart';
import '../services/language_service.dart';
import '../services/cache_service.dart';
import 'settings_screen.dart';
import 'student_dashboard.dart';
import '../views/class_list.dart';
import 'student_attendance_screen.dart';
import 'teacher_qr_scan_screen.dart';
import 'teacher_detail_screen.dart'; // For teacher card navigation
import 'exam_result_screen.dart'; // For exam result navigation
import '../models/teacher.dart'; // For Teacher model
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  String schoolName = 'School'; // Add school name variable
  String? schoolLogoUrl; // Add school logo URL variable

  // --- End caching fields ---

  @override
  void initState() {
    super.initState();
    _fetchUserRole(); // Fetch user role
    _fetchSchoolName(); // Fetch school name
    _fetchTeachers();
    _fetchDashboardStats(); // Use combined method for better performance
  }

  Future<void> _fetchUserRole() async {
    final user = await ParseUser.currentUser();
    final role = user?.get<String>('role');
    print('DEBUG: Fetched userRole: $role');
    setState(() {
      userRole = role;
    });
  }

  Future<void> _fetchSchoolName() async {
    // Try to get cached school info first
    final cachedSchoolInfo = await CacheService.getSchoolInfo();
    if (cachedSchoolInfo != null) {
      setState(() {
        schoolName = cachedSchoolInfo['name'] ?? 'School';
        schoolLogoUrl = cachedSchoolInfo['logoUrl'];
      });
    }

    try {
      final query = QueryBuilder<ParseObject>(ParseObject('School'));
      final response = await query.query();

      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        final school = response.results!.first;
        final fetchedSchoolName = school.get<String>('name') ?? 'School';
        final fetchedLogoUrl = school.get<String>('logoUrl');
        final fetchedAddress = school.get<String>('address');
        final fetchedPhone = school.get<String>('phone');
        final fetchedEmail = school.get<String>('email');

        // Cache the school information
        await CacheService.saveSchoolInfo(
          name: fetchedSchoolName,
          logoUrl: fetchedLogoUrl,
          address: fetchedAddress,
          phone: fetchedPhone,
          email: fetchedEmail,
        );

        if (mounted) {
          setState(() {
            schoolName = fetchedSchoolName;
            schoolLogoUrl = fetchedLogoUrl;
          });
        }
      }
    } catch (e) {
      print('Error fetching school name: $e');
      // Keep cached or default name if error occurs
    }
  }

  Future<void> _fetchTeachers() async {
    // Try to get cached teachers first for faster display
    final cachedTeachers = CacheService.getTeacherList();
    if (cachedTeachers != null && cachedTeachers.isNotEmpty) {
      // Convert cached data back to ParseObject list
      final teacherObjects = cachedTeachers.map((teacherData) {
        final parseObject = ParseObject('Teacher');
        teacherData.forEach((key, value) {
          parseObject.set(key, value);
        });
        return parseObject;
      }).toList();

      setState(() {
        teachers = teacherObjects;
        loading = false;
      });
    } else {
      setState(() {
        loading = true;
        error = '';
      });
    }

    // Always fetch latest data in background
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Teacher'));
      final response = await query.query();

      if (response.success && response.results != null) {
        final fetchedTeachers = response.results!.cast<ParseObject>();

        // Convert to Map for caching
        final teacherDataList = fetchedTeachers.map((teacher) {
          return {
            'objectId': teacher.objectId,
            'name': teacher.get<String>('name'),
            'email': teacher.get<String>('email'),
            'phone': teacher.get<String>('phone'),
            'subject': teacher.get<String>('subject'),
            'profilePictureUrl': teacher.get<String>('profilePictureUrl'),
            'createdAt': teacher.createdAt?.toIso8601String(),
            'updatedAt': teacher.updatedAt?.toIso8601String(),
          };
        }).toList();

        // Save to cache
        await CacheService.saveTeacherList(teacherDataList);

        setState(() {
          teachers = fetchedTeachers;
          loading = false;
        });
      } else if (cachedTeachers == null) {
        setState(() {
          error = 'Failed to fetch teachers.';
          loading = false;
        });
      }
    } catch (e) {
      print('Error fetching teachers: $e');
      if (cachedTeachers == null) {
        setState(() {
          error = 'Error: $e';
          loading = false;
        });
      }
    }
  }

  Future<void> _fetchDashboardStats() async {
    // Try to get cached dashboard stats first
    final cachedStats = await CacheService.getDashboardStats();
    if (cachedStats != null) {
      setState(() {
        studentCount = cachedStats['studentCount'] ?? 0;
        classCount = cachedStats['classCount'] ?? 0;
      });
    }

    try {
      // Fetch student count
      final studentQuery = QueryBuilder<ParseObject>(ParseObject('Student'));
      final studentResponse = await studentQuery.count();

      // Fetch class count
      final classQuery = QueryBuilder<ParseObject>(ParseObject('Class'));
      final classResponse = await classQuery.count();

      if (studentResponse.success && classResponse.success) {
        final fetchedStudentCount = studentResponse.count;
        final fetchedClassCount = classResponse.count;
        final teacherCount = teachers.length;

        // Cache the dashboard statistics
        await CacheService.saveDashboardStats(
          studentCount: fetchedStudentCount,
          teacherCount: teacherCount,
          classCount: fetchedClassCount,
        );

        setState(() {
          studentCount = fetchedStudentCount;
          classCount = fetchedClassCount;
        });
      }
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      // Keep cached or default values if error occurs
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
          final l10n = AppLocalizations.of(context)!;
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
                            Text('${l10n.subject}: $subject',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2),
                            Text('${l10n.gender}: $gender',
                                style: const TextStyle(fontSize: 12)),
                            Text('${l10n.experience}: $years ${l10n.years}',
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
                              child: Text(
                                l10n.tapToViewDetails,
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

  // Method to refresh all data and clear cache
  Future<void> _refreshData() async {
    setState(() {
      loading = true;
    });

    // Clear relevant cache if you want fresh data
    // await CacheService.clearCache('schoolBox');
    // await CacheService.clearCache('dashboardBox');
    // await CacheService.clearTeacherList();

    await Future.wait([
      _fetchSchoolName(),
      _fetchTeachers(),
      _fetchDashboardStats(),
    ]);

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        // Wait for userRole to be fetched before building the dashboard
        if (userRole == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        print('DEBUG: Building AdminDashboard with userRole: $userRole');

        return ModernDashboard(
          title: schoolName,
          subtitle: 'Over view',
          userRole: userRole, // Pass userRole to ModernDashboard
          logoUrl: schoolLogoUrl, // Pass school logo URL
          activities: [
            {'title': l10n.students, 'desc': 'Total: $studentCount'},
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
              print(
                  'DEBUG: Tab 1 selected - delegating to AppBottomNavigation');
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ExamResultScreen(),
              ),
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
              MaterialPageRoute(
                  builder: (_) => const StudentAttendanceScreen()),
            );
          },
        );
      },
    );
  }
}
