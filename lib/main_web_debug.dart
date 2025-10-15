import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/student_attendance_history_screen.dart';
import 'screens/student_dashboard.dart';
import 'services/cache_service.dart';
import 'services/language_service.dart';
import 'screens/admin_dashboard.dart';
import 'screens/login_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'font_test.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // For web, let's simplify initialization
  if (kIsWeb) {
    print('🌐 Running on Web - Using simplified initialization');

    try {
      // Try to initialize Hive, but don't fail if it doesn't work
      await Hive.initFlutter();
      await Hive.openBox('studentImages');
      print('✅ Hive initialized for web');
    } catch (e) {
      print('⚠️ Hive failed on web (continuing): $e');
    }

    try {
      await CacheService.init();
      print('✅ Cache service initialized');
    } catch (e) {
      print('⚠️ Cache service failed (continuing): $e');
    }

    // Initialize language service with fallback
    final languageService = LanguageService();
    try {
      await languageService.loadSavedLanguage();
      print('✅ Language service loaded');
    } catch (e) {
      print('⚠️ Language service fallback: $e');
    }

    // Initialize Parse with timeout
    try {
      await Parse()
          .initialize(
            'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5',
            'https://parseapi.back4app.com/',
            clientKey: 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE',
            autoSendSessionId: true,
            debug: true,
          )
          .timeout(const Duration(seconds: 10));
      print('✅ Parse initialized successfully');
    } catch (e) {
      print('❌ Parse initialization failed: $e');
    }

    runApp(
      ChangeNotifierProvider(
        create: (context) => languageService,
        child: const MyWebApp(),
      ),
    );
  } else {
    // Mobile initialization (original)
    try {
      await Hive.initFlutter();
      await Hive.openBox('studentImages');
      await CacheService.init();
      print('✅ Mobile initialization complete');
    } catch (e) {
      print('❌ Mobile initialization error: $e');
    }

    final languageService = LanguageService();
    await languageService.loadSavedLanguage();

    await Parse().initialize(
      'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5',
      'https://parseapi.back4app.com/',
      clientKey: 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE',
      autoSendSessionId: true,
      debug: false,
    );

    runApp(
      ChangeNotifierProvider(
        create: (context) => languageService,
        child: const MyApp(),
      ),
    );
  }
}

class MyWebApp extends StatelessWidget {
  const MyWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return MaterialApp(
          title: 'Edu Solution',
          debugShowCheckedModeBanner: false,
          locale: languageService.currentLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LanguageService.supportedLocales,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            textTheme: GoogleFonts.robotoTextTheme(),
          ),
          home: const WebRoleBasedHome(),
          routes: {
            '/home': (context) => const WebRoleBasedHome(),
            '/login': (context) => const LoginPage(),
            '/admin': (context) => const AdminDashboard(),
            '/student': (context) => const StudentDashboard(currentIndex: 0),
          },
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  TextTheme _getTextThemeForLocale(Locale locale) {
    if (locale.languageCode == 'km') {
      return GoogleFonts.notoSansKhmerTextTheme();
    } else {
      return GoogleFonts.robotoTextTheme();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return MaterialApp(
          title: 'Edu Solution',
          debugShowCheckedModeBanner: false,
          locale: languageService.currentLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LanguageService.supportedLocales,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            textTheme: _getTextThemeForLocale(languageService.currentLocale),
          ),
          home: const RoleBasedHome(),
          routes: {
            '/home': (context) => const RoleBasedHome(),
            '/studentAttendanceHistory': (context) =>
                const StudentAttendanceHistoryScreen(),
            '/studentList': (context) =>
                const StudentDashboard(currentIndex: 2),
            '/fontTest': (context) => const FontTestScreen(),
          },
        );
      },
    );
  }
}

class WebRoleBasedHome extends StatefulWidget {
  const WebRoleBasedHome({super.key});

  @override
  State<WebRoleBasedHome> createState() => _WebRoleBasedHomeState();
}

class _WebRoleBasedHomeState extends State<WebRoleBasedHome> {
  String? userRole;
  bool isLoading = true;
  bool hasError = false;
  String debugInfo = '';

  @override
  void initState() {
    super.initState();
    _initializeWebApp();
  }

  Future<void> _initializeWebApp() async {
    print('🌐 WebRoleBasedHome: Starting web initialization');

    try {
      setState(() {
        debugInfo = 'Checking authentication...';
      });

      // Add a small delay to ensure Parse is ready
      await Future.delayed(const Duration(milliseconds: 500));

      final user = await ParseUser.currentUser();
      print('👤 Current user: ${user?.objectId}');

      if (user != null) {
        final role = user.get<String>('role');
        print('🎭 User role: $role');

        if (mounted) {
          setState(() {
            userRole = role;
            isLoading = false;
            hasError = false;
            debugInfo = 'User authenticated: $role';
          });
        }
      } else {
        print('🚪 No authenticated user, showing login');
        if (mounted) {
          setState(() {
            userRole = null;
            isLoading = false;
            hasError = false;
            debugInfo = 'No authenticated user';
          });
        }
      }
    } catch (e) {
      print('❌ Web initialization error: $e');
      if (mounted) {
        setState(() {
          hasError = false; // Don't show error, just go to login
          isLoading = false;
          userRole = null;
          debugInfo = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏠 WebRoleBasedHome build: loading=$isLoading, userRole=$userRole');

    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading Edu Solution...'),
              const SizedBox(height: 8),
              if (kDebugMode)
                Text(debugInfo, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    // If no role or null role, show login page
    if (userRole == null || userRole!.isEmpty) {
      print('🚪 No user role, showing login page');
      return const LoginPage();
    }

    print('🎯 Routing user with role: $userRole');
    // Route users based on their roles
    switch (userRole!.toLowerCase()) {
      case 'owner':
      case 'admin':
        print('👑 Routing to AdminDashboard');
        return const AdminDashboard();
      case 'teacher':
        print('🍎 Routing to AdminDashboard (teacher)');
        return const AdminDashboard();
      case 'student':
        print('🎓 Routing to StudentDashboard');
        return const StudentDashboard(currentIndex: 0);
      default:
        print('❓ Unknown role, showing login page');
        return const LoginPage();
    }
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
      print('🔍 Checking user authentication...');
      final user = await ParseUser.currentUser();
      print('👤 Current user: ${user?.objectId ?? 'null'}');

      if (user != null) {
        final role = user.get<String>('role');
        print('🎭 User role: $role');

        if (mounted) {
          setState(() {
            userRole = role;
            isLoading = false;
            hasError = false;
          });
        }
      } else {
        print('🚪 No current user, showing login');
        if (mounted) {
          setState(() {
            userRole = null;
            isLoading = false;
            hasError = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error getting user role: $e');
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
    print(
        '🏠 RoleBasedHome build: loading=$isLoading, hasError=$hasError, userRole=$userRole');

    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Edu Solution...'),
            ],
          ),
        ),
      );
    }

    if (hasError) {
      print('🚪 Error occurred, showing login page');
      return const LoginPage();
    }

    // If no role or null role, show login page
    if (userRole == null || userRole!.isEmpty) {
      print('🚪 No user role, showing login page');
      return const LoginPage();
    }

    print('🎯 Routing user with role: $userRole');
    // Route users based on their roles
    switch (userRole!.toLowerCase()) {
      case 'owner':
      case 'admin':
        print('👑 Routing to AdminDashboard');
        return const AdminDashboard();
      case 'teacher':
        print('🍎 Routing to AdminDashboard (teacher)');
        return const AdminDashboard();
      case 'student':
        print('🎓 Routing to StudentDashboard');
        return const StudentDashboard(currentIndex: 0);
      default:
        print('❓ Unknown role, showing login page');
        return const LoginPage();
    }
  }
}
