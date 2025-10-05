import 'package:flutter/material.dart';
import '../screens/teacher_dashboard.dart';
import '../screens/settings_screen.dart';
import '../screens/time_table_screen.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final String? userRole;
  final Function(int)? onTabChanged;

  const AppBottomNavigation({
    Key? key,
    required this.currentIndex,
    this.userRole,
    this.onTabChanged,
  }) : super(key: key);

  void _handleNavigation(BuildContext context, int index) {
    // Prevent navigation to same screen
    if (index == currentIndex) {
      return; // Already on this tab, do nothing
    }

    // Call the callback if provided (but don't return, continue with navigation)
    if (onTabChanged != null) {
      onTabChanged!(index);
    }

    // Default navigation behavior
    switch (index) {
      case 0: // Home
        // Check if we're already on a home screen to prevent unnecessary navigation
        final currentRoute = ModalRoute.of(context)?.settings.name;
        final isAlreadyHome = currentRoute == '/home' ||
            currentRoute == '/' ||
            currentRoute == null; // null means we're at root

        if (!isAlreadyHome || currentIndex != 0) {
          print('DEBUG: Navigating to home from route: $currentRoute');
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          print('DEBUG: Already on home screen, no navigation needed');
        }
        break;
      case 1: // Teachers or Schedule (based on role)
        print('DEBUG: Second tab clicked, userRole: $userRole');
        // Check if user has permission to access teacher management
        if (userRole?.toLowerCase() == 'admin' ||
            userRole?.toLowerCase() == 'owner') {
          print('DEBUG: Admin/Owner access granted to TeacherDashboard');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const TeacherDashboard(),
              settings: const RouteSettings(name: '/teacher'),
            ),
          );
        } else {
          // For teachers and any other role, show TimeTableScreen
          print('DEBUG: User accessing Schedule (role: $userRole)');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const TimeTableScreen(
                userRole: 'teacher',
                // Note: teacherId will be automatically found by TimeTableScreen
              ),
              settings: const RouteSettings(name: '/schedule'),
            ),
          );
        }
        break;
      case 2: // Students
        Navigator.pushReplacementNamed(context, '/studentList');
        break;
      case 3: // Settings
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SettingsScreen(),
            settings: const RouteSettings(name: '/settings'),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create dynamic navigation items based on user role
    List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      // Second tab changes based on user role
      BottomNavigationBarItem(
        icon: Icon(userRole?.toLowerCase() == 'teacher'
            ? Icons.schedule
            : Icons.people),
        label: userRole?.toLowerCase() == 'teacher' ? 'Schedule' : 'Teachers',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.school),
        label: 'Students',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    return BottomNavigationBar(
      items: items,
      currentIndex: currentIndex,
      onTap: (index) => _handleNavigation(context, index),
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
    );
  }
}
