import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';
import '../screens/time_table_screen.dart';
import '../screens/teacher_qr_scan_screen.dart';
import '../screens/exam_result_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
      case 1: // Schedule
        print('DEBUG: Schedule tab clicked, userRole: $userRole');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TimeTableScreen(
              userRole: userRole ?? 'admin',
              // Note: teacherId will be automatically found by TimeTableScreen
            ),
            settings: const RouteSettings(name: '/schedule'),
          ),
        );
        break;
      case 2: // Exam Results
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ExamResultScreen(),
            settings: const RouteSettings(name: '/exam_results'),
          ),
        );
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

  void _handleQRScan(BuildContext context) {
    print('DEBUG: QR Scan button clicked');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeacherQRScanScreen(),
        settings: const RouteSettings(name: '/qr_scan'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Bottom Navigation Bar with custom spacing
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 60,
              child: Row(
                children: [
                  // Home
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleNavigation(context, 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home,
                            color:
                                currentIndex == 0 ? Colors.blue : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.home,
                            style: TextStyle(
                              color:
                                  currentIndex == 0 ? Colors.blue : Colors.grey,
                              fontSize: 12,
                              fontWeight: currentIndex == 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Schedule (with right padding)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 32.0),
                      child: GestureDetector(
                        onTap: () => _handleNavigation(context, 1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule,
                              color:
                                  currentIndex == 1 ? Colors.blue : Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.schedule,
                              style: TextStyle(
                                color: currentIndex == 1
                                    ? Colors.blue
                                    : Colors.grey,
                                fontSize: 12,
                                fontWeight: currentIndex == 1
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Exam Results (with left padding)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 32.0),
                      child: GestureDetector(
                        onTap: () => _handleNavigation(context, 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assessment,
                              color:
                                  currentIndex == 2 ? Colors.blue : Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.results,
                              style: TextStyle(
                                color: currentIndex == 2
                                    ? Colors.blue
                                    : Colors.grey,
                                fontSize: 12,
                                fontWeight: currentIndex == 2
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Settings
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleNavigation(context, 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.settings,
                            color:
                                currentIndex == 3 ? Colors.blue : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.settings,
                            style: TextStyle(
                              color:
                                  currentIndex == 3 ? Colors.blue : Colors.grey,
                              fontSize: 12,
                              fontWeight: currentIndex == 3
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Floating QR Scan Button
        Positioned(
          left:
              MediaQuery.of(context).size.width / 2 - 28, // Center horizontally
          top: -28, // Position above the bottom nav
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () => _handleQRScan(context),
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(
                Icons.qr_code_scanner,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
