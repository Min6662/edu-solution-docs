import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/student_attendance_history_screen.dart';
import 'screens/student_dashboard.dart';
import 'services/cache_service.dart';
import 'screens/admin_dashboard.dart';
import 'screens/login_page.dart' as login_page;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter(); // Initialize Hive for Flutter
  await Hive.openBox('studentImages'); // Open box for student images
  await CacheService.init(); // Initialize Hive cache boxes
  await Parse().initialize(
    'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5',
    'https://parseapi.back4app.com/',
    clientKey: 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE',
    autoSendSessionId: true,
    debug: false, // Disabled for production
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edu Solution',
      debugShowCheckedModeBanner: false, // Remove debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RoleBasedHome(),
      routes: {
        '/home': (context) => const RoleBasedHome(),
        '/studentAttendanceHistory': (context) =>
            const StudentAttendanceHistoryScreen(),
        '/studentList': (context) => const StudentDashboard(currentIndex: 2),
      },
    );
  }
}

class RoleBasedHome extends StatefulWidget {
  const RoleBasedHome({super.key});

  @override
  State<RoleBasedHome> createState() => _RoleBasedHomeState();
}

class _RoleBasedHomeState extends State<RoleBasedHome> {
  String? userRole;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    try {
      final user = await ParseUser.currentUser();
      final role = user?.get<String>('role');

      if (mounted) {
        setState(() {
          userRole = role;
          isLoading = false;
          hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError) {
      return const login_page.LoginPage();
    }

    // If no role or null role, show login page
    if (userRole == null || userRole!.isEmpty) {
      return const login_page.LoginPage();
    }

    // Route users based on their roles
    switch (userRole!.toLowerCase()) {
      case 'owner':
      case 'admin':
        return const AdminDashboard(); // Admin sees the normal app with full access
      case 'teacher':
        return const AdminDashboard(); // Teachers see the same app but with limited access
      case 'student':
        return const StudentDashboard(
            currentIndex: 0); // Students see their dashboard
      default:
        return const login_page
            .LoginPage(); // Redirect to login for unknown roles
    }
  }
}
