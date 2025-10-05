import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import '../widgets/app_bottom_navigation.dart';

import '../screens/assigned_classes_screen.dart'; // Import the new screen
import '../screens/time_table_screen.dart';
import '../screens/teacher_qr_scan_screen.dart'; // Import smart QR scanner
import '../screens/attendance_history_screen.dart'; // Import attendance history
import '../screens/schedule_data_manager_screen.dart'; // Import schedule manager

class ModernDashboard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Map<String, String>> activities;
  final List<Map<String, String>> users;
  final List<Map<String, String>> items;
  final List<Widget>? actions;
  final int currentIndex;
  final void Function(int)? onTabSelected;
  final VoidCallback? onClassTap;
  final VoidCallback? onStudentTap;
  final VoidCallback? onExamResultTap;
  final VoidCallback? onEnrolmentsTap;
  final VoidCallback? onQRScanTap;
  final VoidCallback? onStudentAttendanceTap;
  final VoidCallback? onAssignedClassesTap;
  final VoidCallback? onTimetableTap;
  final String? userRole; // Add userRole parameter
  const ModernDashboard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.activities,
    required this.users,
    required this.items,
    this.actions,
    this.currentIndex = 0,
    this.onTabSelected,
    this.onClassTap,
    this.onStudentTap,
    this.onExamResultTap,
    this.onEnrolmentsTap,
    this.onQRScanTap,
    this.onStudentAttendanceTap,
    this.onAssignedClassesTap,
    this.onTimetableTap,
    this.userRole, // Add userRole to constructor
  });

  @override
  State<ModernDashboard> createState() => _ModernDashboardState();
}

class _ModernDashboardState extends State<ModernDashboard> {
  int _selectedIndex = 0;

  // Initialize school data cards at declaration to avoid LateInitializationError
  List<Map<String, dynamic>> _schoolDataCards = [];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;

    // Debug print to check userRole
    print('DEBUG: userRole in ModernDashboard: ${widget.userRole}');
    print('DEBUG: userRole?.toLowerCase(): ${widget.userRole?.toLowerCase()}');
    print(
        'DEBUG: Should hide Enrollments: ${widget.userRole?.toLowerCase() == 'teacher'}');

    _schoolDataCards = [
      {
        'icon': Icons.class_,
        'title': 'Class',
        'description': 'View all classes',
        'onTap': widget.onClassTap ?? () {},
      },
      {
        'icon': Icons.school,
        'title': 'Student',
        'description': 'View all students',
        'onTap': widget.onStudentTap ?? () {},
      },
      {
        'icon': Icons.assignment,
        'title': 'Exam Result',
        'description': 'View exam results',
        'onTap': widget.onExamResultTap ?? () {},
      },
      // Only show Enrollments card if user is not a teacher
      if (widget.userRole?.toLowerCase() != 'teacher')
        {
          'icon': Icons.how_to_reg,
          'title': 'Enrolments',
          'description': 'View enrolments',
          'onTap': widget.onEnrolmentsTap ?? () {},
        },
      {
        'icon': Icons.qr_code_scanner,
        'title': 'QR Scan',
        'description': 'Smart Attendance',
        'onTap': () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => const TeacherQRScanScreen(),
            ),
          );
        },
      },
      {
        'icon': Icons.check_circle,
        'title': 'Attendance',
        'description': 'For Students',
        'onTap': widget.onStudentAttendanceTap ?? () {},
      },
      {
        'icon': Icons.history,
        'title': 'Scan History',
        'description': 'Attendance Records',
        'onTap': () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => const AttendanceHistoryScreen(),
            ),
          );
        },
      },
      {
        'icon': Icons.data_usage,
        'title': 'Schedule Data',
        'description': 'Check & Manage',
        'onTap': () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => const ScheduleDataManagerScreen(),
            ),
          );
        },
      },
      // New cards for teacher features
      {
        'icon': Icons.assignment_ind,
        'title': 'Assigned',
        'description': 'Teaching Classes',
        'onTap': () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => const AssignedClassesScreen(),
            ),
          );
        },
      },
      // Only show Timetable card if user is not a teacher
      if (widget.userRole?.toLowerCase() != 'teacher')
        {
          'icon': Icons.schedule,
          'title': 'Timetable',
          'description': 'Schedule',
          'onTap': () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => TimeTableScreen(
                  userRole: widget.userRole ?? 'admin',
                  // teacherId will be automatically found by the TimeTableScreen
                  // for teacher users in the _findTeacherId method
                ),
              ),
            );
          },
        },
    ];

    // Debug print final card count
    print('DEBUG: Total cards: ${_schoolDataCards.length}');
    _schoolDataCards.forEach((card) => print('DEBUG: Card: ${card['title']}'));
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
    }
    // Navigate to StudentListScreen when Students tab is tapped
    if (index == 2) {
      // Use root navigator to ensure navigation works in all dashboard contexts
      Navigator.of(context, rootNavigator: true)
          .pushNamed('/studentList'); // This will now go to StudentDashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.school, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(widget.title, style: const TextStyle(color: Colors.black)),
          ],
        ),
        // Removed actions: widget.actions
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              16, 16, 16, kBottomNavigationBarHeight + 17),
          children: [
            const SizedBox(height: 16),
            // Move card to top
            SizedBox(
              height: 240,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Container(
                    width: 380,
                    constraints: const BoxConstraints(maxWidth: 420),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E6E0), // Softer pink
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 32.0, horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.school,
                                  color: Color(0xFF1565C0), size: 28),
                              SizedBox(width: 10),
                              Text('School Overview',
                                  style: const TextStyle(
                                      color: Color(0xFF1565C0),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _overviewStat(
                                  'Students',
                                  widget.activities.isNotEmpty
                                      ? widget.activities[0]['desc'] ?? ''
                                      : '',
                                  Colors.black87),
                              _overviewStat(
                                  'Teachers',
                                  widget.activities.length > 1
                                      ? widget.activities[1]['desc'] ?? ''
                                      : '',
                                  Colors.black87),
                              _overviewStat(
                                  'Classes',
                                  widget.activities.length > 2
                                      ? widget.activities[2]['desc'] ?? ''
                                      : '',
                                  Colors.black87),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Move School Data title closer to card
            const Text('School Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 12),
            ReorderableWrap(
              spacing: 16,
              runSpacing: 16,
              maxMainAxisCount: 2,
              needsLongPressDraggable: true,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  final item = _schoolDataCards.removeAt(oldIndex);
                  _schoolDataCards.insert(newIndex, item);
                });
              },
              children: _schoolDataCards.map((card) {
                return _schoolDataCard(
                  icon: card['icon'],
                  title: card['title'],
                  description: card['description'],
                  onTap: card['onTap'],
                  key: ValueKey(card['title']),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _selectedIndex,
        userRole: widget.userRole,
        onTabChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (widget.onTabSelected != null) {
            widget.onTabSelected!(index);
          }
          // The AppBottomNavigation will now handle navigation automatically
          // No need for manual navigation here anymore
        },
      ),
    );
  }

  Widget _schoolDataCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    Key? key,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        constraints:
            const BoxConstraints(minWidth: 160, maxWidth: 300, minHeight: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _overviewStat(String label, String value, Color textColor) {
    final displayValue = value.replaceAll('Total: ', '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.w600, fontSize: 18)),
        const SizedBox(height: 6),
        Text(displayValue,
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.bold, fontSize: 32)),
      ],
    );
  }
}
