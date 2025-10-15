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

  // Different initialization for web vs mobile
  if (kIsWeb) {
    print('🌐 Initializing for Web...');
    await _initializeForWeb();
  } else {
    print('📱 Initializing for Mobile...');
    await _initializeForMobile();
  }
}

Future<void> _initializeForWeb() async {
  try {
    // Initialize Hive with error handling for web
    try {
      await Hive.initFlutter();
      await Hive.openBox('studentImages');
      print('✅ Hive initialized for web');
    } catch (e) {
      print('⚠️ Hive initialization skipped for web: $e');
    }

    // Initialize cache service with error handling
    try {
      await CacheService.init();
      print('✅ Cache service initialized for web');
    } catch (e) {
      print('⚠️ Cache service skipped for web: $e');
    }

    // Initialize language service
    final languageService = LanguageService();
    try {
      await languageService.loadSavedLanguage();
      print('✅ Language service initialized for web');
    } catch (e) {
      print('⚠️ Language service using defaults for web: $e');
    }

    // Initialize Parse with timeout for web
    try {
      await Parse()
          .initialize(
            'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5',
            'https://parseapi.back4app.com/',
            clientKey: 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE',
            autoSendSessionId: true,
            debug: true, // Enable debug for web
          )
          .timeout(const Duration(seconds: 10));
      print('✅ Parse Server initialized for web');
    } catch (e) {
      print('❌ Parse Server initialization failed for web: $e');
    }

    runApp(
      ChangeNotifierProvider(
        create: (context) => languageService,
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('❌ Web initialization failed: $e');
    // Still run the app even if initialization fails
    runApp(
      ChangeNotifierProvider(
        create: (context) => LanguageService(),
        child: const MyApp(),
      ),
    );
  }
}

Future<void> _initializeForMobile() async {
  try {
    await Hive.initFlutter();
    await Hive.openBox('studentImages');
    await CacheService.init();
    print('✅ Hive initialized successfully for mobile');
  } catch (e) {
    print('⚠️ Hive initialization error (continuing anyway): $e');
  }

  // Initialize language service
  final languageService = LanguageService();
  try {
    await languageService.loadSavedLanguage();
    print('✅ Language service initialized');
  } catch (e) {
    print('⚠️ Language service error (using default): $e');
  }

  // Initialize Parse
  try {
    await Parse().initialize(
      'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5',
      'https://parseapi.back4app.com/',
      clientKey: 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE',
      autoSendSessionId: true,
      debug: false, // Disabled for mobile production
    );
    print('✅ Parse Server initialized successfully');
  } catch (e) {
    print('❌ Parse Server initialization error: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => languageService,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Get appropriate text theme based on current locale
  TextTheme _getTextThemeForLocale(Locale locale) {
    if (locale.languageCode == 'km') {
      // Use Noto Sans Khmer for Khmer text
      return GoogleFonts.notoSansKhmerTextTheme();
    } else {
      // Use a modern, readable font for English text
      // Popular options:
      // GoogleFonts.robotoTextTheme() - Clean, modern (Google's Material Design font)
      // GoogleFonts.latoTextTheme() - Friendly, professional
      // GoogleFonts.openSansTextTheme() - Highly readable, neutral
      // GoogleFonts.poppinsTextTheme() - Modern, geometric
      // GoogleFonts.interTextTheme() - Optimized for UI, very readable
      // GoogleFonts.sourceSansProTextTheme() - Clean, professional

      return GoogleFonts
          .robotoTextTheme(); // You can change this to any font above
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return MaterialApp(
          title: 'Edu Solution',
          debugShowCheckedModeBanner: false, // Remove debug banner
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
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Initializing Edu Solution...'),
              if (kIsWeb) ...[
                const SizedBox(height: 20),
                const Text('Web Version',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()),
                    );
                  },
                  child: const Text('Skip to Login'),
                ),
              ],
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
