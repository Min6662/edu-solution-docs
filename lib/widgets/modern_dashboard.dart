import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import '../widgets/app_bottom_navigation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../screens/time_table_screen.dart';
import '../screens/teacher_qr_scan_screen.dart'; // Import smart QR scanner
import '../screens/attendance_history_screen.dart'; // Import attendance history
import '../screens/schedule_data_manager_screen.dart'; // Import schedule manager
import '../screens/admin_attendance_overview_screen.dart'; // Import admin attendance overview

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
  final VoidCallback? onQRScanTap;
  final VoidCallback? onStudentAttendanceTap;
  final VoidCallback? onTimetableTap;
  final String? userRole; // Add userRole parameter
  final String? logoUrl; // Add logoUrl parameter
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
    this.onQRScanTap,
    this.onStudentAttendanceTap,
    this.onTimetableTap,
    this.userRole, // Add userRole to constructor
    this.logoUrl, // Add logoUrl to constructor
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
      // Teacher-only: Individual Scan History
      if (widget.userRole?.toLowerCase() != 'admin' &&
          widget.userRole?.toLowerCase() != 'owner')
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
      // Admin-only: All Teachers QR Attendance Overview
      if (widget.userRole?.toLowerCase() == 'admin' ||
          widget.userRole?.toLowerCase() == 'owner')
        {
          'icon': Icons.admin_panel_settings,
          'title': 'Scan Record',
          'description': 'Staff Attendance',
          'onTap': () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => const AdminAttendanceOverviewScreen(),
              ),
            );
          },
        },
      // Only show Schedule card if user is not a teacher
      if (widget.userRole?.toLowerCase() != 'teacher')
        {
          'icon': Icons.data_usage,
          'title': 'Schedule',
          'description': 'Check & Manage',
          'onTap': () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => const ScheduleDataManagerScreen(),
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
    final l10n = AppLocalizations.of(context)!;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isMediumScreen = screenSize.width >= 360 && screenSize.width < 400;

    // Responsive card width calculation
    double getCardWidth() {
      if (isSmallScreen)
        return screenSize.width * 0.85; // 85% for small screens
      if (isMediumScreen) return 350; // Fixed width for medium screens
      return 380; // Original width for large screens
    }

    // Responsive card max width
    double getCardMaxWidth() {
      if (isSmallScreen) return screenSize.width * 0.9;
      if (isMediumScreen) return 380;
      return 420;
    }

    // Responsive grid columns
    int getGridColumns() {
      if (isSmallScreen) return 1; // Single column for very small screens
      return 2; // Two columns for medium and large screens
    }

    // Update school data cards with localized strings
    _schoolDataCards = [
      {
        'icon': Icons.class_,
        'title': l10n.classCard,
        'description': l10n.viewAllClasses,
        'onTap': widget.onClassTap ?? () {},
      },
      {
        'icon': Icons.school,
        'title': l10n.student,
        'description': l10n.viewAllStudents,
        'onTap': widget.onStudentTap ?? () {},
      },
      {
        'icon': Icons.assignment,
        'title': l10n.examResult,
        'description': l10n.viewExamResults,
        'onTap': widget.onExamResultTap ?? () {},
      },
      {
        'icon': Icons.qr_code_scanner,
        'title': l10n.qrScan,
        'description': l10n.smartAttendance,
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
        'title': l10n.attendance,
        'description': l10n.forStudents,
        'onTap': widget.onStudentAttendanceTap ?? () {},
      },
      // Teacher-only: Individual Scan History
      if (widget.userRole?.toLowerCase() != 'admin' &&
          widget.userRole?.toLowerCase() != 'owner')
        {
          'icon': Icons.history,
          'title': l10n.scanHistory,
          'description': l10n.attendanceRecords,
          'onTap': () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => const AttendanceHistoryScreen(),
              ),
            );
          },
        },
      // Admin-only: All Teachers QR Attendance Overview
      if (widget.userRole?.toLowerCase() == 'admin' ||
          widget.userRole?.toLowerCase() == 'owner')
        {
          'icon': Icons.admin_panel_settings,
          'title': l10n.scanRecord,
          'description': l10n.staffAttendance,
          'onTap': () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => const AdminAttendanceOverviewScreen(),
              ),
            );
          },
        },
      // Only show Schedule card if user is not a teacher
      if (widget.userRole?.toLowerCase() != 'teacher')
        {
          'icon': Icons.data_usage,
          'title': l10n.schedule,
          'description': l10n.checkManage,
          'onTap': () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => const ScheduleDataManagerScreen(),
              ),
            );
          },
        },
      // Only show Timetable card if user is not a teacher
      if (widget.userRole?.toLowerCase() != 'teacher')
        {
          'icon': Icons.schedule,
          'title': l10n.timetable,
          'description': l10n.schedule,
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              backgroundImage:
                  widget.logoUrl != null && widget.logoUrl!.isNotEmpty
                      ? NetworkImage(widget.logoUrl!)
                      : null,
              child: widget.logoUrl == null || widget.logoUrl!.isEmpty
                  ? const Icon(Icons.school, color: Colors.white)
                  : null,
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
              height: isSmallScreen ? 200 : 240, // Responsive height
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Container(
                    width: getCardWidth(), // Use responsive width
                    constraints: BoxConstraints(
                        maxWidth:
                            getCardMaxWidth()), // Use responsive max width
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
                      padding: EdgeInsets.symmetric(
                          vertical:
                              isSmallScreen ? 24.0 : 32.0, // Responsive padding
                          horizontal: isSmallScreen
                              ? 16.0
                              : 20.0), // Responsive padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.school,
                                  color: Color(0xFF1565C0),
                                  size: isSmallScreen
                                      ? 24
                                      : 28), // Responsive icon size
                              SizedBox(width: 10),
                              Text('School Overview',
                                  style: TextStyle(
                                      color: Color(0xFF1565C0),
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen
                                          ? 16
                                          : 18)), // Responsive font size
                            ],
                          ),
                          SizedBox(
                              height: isSmallScreen
                                  ? 16
                                  : 24), // Responsive spacing
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _overviewStat(
                                  'Students',
                                  widget.activities.isNotEmpty
                                      ? widget.activities[0]['desc'] ?? ''
                                      : '',
                                  Colors.black87,
                                  isSmallScreen: isSmallScreen),
                              _overviewStat(
                                  'Teachers',
                                  widget.activities.length > 1
                                      ? widget.activities[1]['desc'] ?? ''
                                      : '',
                                  Colors.black87,
                                  isSmallScreen: isSmallScreen),
                              _overviewStat(
                                  'Classes',
                                  widget.activities.length > 2
                                      ? widget.activities[2]['desc'] ?? ''
                                      : '',
                                  Colors.black87,
                                  isSmallScreen: isSmallScreen),
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
              spacing: isSmallScreen ? 12 : 16, // Responsive spacing
              runSpacing: isSmallScreen ? 12 : 16, // Responsive spacing
              maxMainAxisCount: getGridColumns(), // Use responsive column count
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
                  isSmallScreen: isSmallScreen, // Pass screen size info
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
    bool isSmallScreen = false, // Add screen size parameter
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minWidth: isSmallScreen ? 140 : 160, // Responsive min width
          maxWidth: isSmallScreen ? 280 : 300, // Responsive max width
          minHeight: isSmallScreen ? 120 : 140, // Responsive min height
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 20, // Responsive padding
          vertical: isSmallScreen ? 20 : 24, // Responsive padding
        ),
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
            Icon(icon,
                size: isSmallScreen ? 40 : 48, // Responsive icon size
                color: Colors.blue),
            SizedBox(height: isSmallScreen ? 12 : 16), // Responsive spacing
            Text(title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 16 : 18, // Responsive font size
                )),
            SizedBox(height: isSmallScreen ? 6 : 8), // Responsive spacing
            Text(description,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12, // Responsive font size
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _overviewStat(String label, String value, Color textColor,
      {bool isSmallScreen = false}) {
    final displayValue = value.replaceAll('Total: ', '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14 : 18)), // Responsive font size
        SizedBox(height: isSmallScreen ? 4 : 6), // Responsive spacing
        Text(displayValue,
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 24 : 32)), // Responsive font size
      ],
    );
  }
}
