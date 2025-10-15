import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import '../services/class_service.dart';
import '../services/cache_service.dart';
import '../services/language_service.dart';
import '../widgets/app_bottom_navigation.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'school_management_screen.dart';
import 'teacher_dashboard.dart'; // Import for teacher management
import 'student_dashboard.dart'; // Import for student dashboard
import 'change_password_screen.dart'; // Import for change password
import 'edit_profile_screen.dart'; // Import for edit profile
import 'teacher_detail_screen.dart';
import 'login_page.dart'; // Import for login page
import '../models/teacher.dart'; // Import for teacher detail screen
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? name;
  String? username;
  String? photoUrl;
  Uint8List? photoBytes;
  String? role;
  String? userRole; // Add userRole field for bottom navigation
  bool loading = true;
  String error = '';
  String? userCacheKey;

  @override
  void initState() {
    super.initState();
    _loadSettingsInstant();
    _fetchUserInfo();
    _fetchUserRole(); // Add user role fetching
  }

  Future<void> _fetchUserRole() async {
    try {
      final user = await ParseUser.currentUser();
      if (user != null) {
        final fetchedRole = user.get<String>('role');
        if (mounted) {
          setState(() {
            userRole = fetchedRole;
          });
        }
      }
    } catch (e) {
      print('Error fetching user role: $e');
    }
  }

  void _loadSettingsInstant() {
    final cached = CacheService.getSettings();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        role = cached['role'] ?? '';
        loading = false;
      });
    }
    _fetchSettings(); // Fetch fresh settings in background
  }

  Future<void> _fetchUserInfo() async {
    setState(() {
      loading = true;
      error = '';
    });
    final user = await ParseUser.currentUser();
    if (user != null) {
      name = user.get<String>('name') ?? '';
      username = user.username ?? '';
      userCacheKey = 'photoBytes_${username ?? user.objectId}';
      final box = await Hive.openBox(CacheService.userBoxName);
      final cachedBytes = box.get(userCacheKey!);
      if (cachedBytes != null) {
        setState(() {
          photoBytes = Uint8List.fromList(List<int>.from(cachedBytes));
        });
      }
      final fetchedPhoto = user.get<String>('photo');
      photoUrl = fetchedPhoto;
      // Download and cache image bytes if not cached and URL is valid
      if (fetchedPhoto != null &&
          fetchedPhoto.isNotEmpty &&
          cachedBytes == null) {
        try {
          final response = await http.get(Uri.parse(fetchedPhoto));
          if (response.statusCode == 200) {
            await box.put(userCacheKey!, response.bodyBytes);
            setState(() {
              photoBytes = response.bodyBytes;
            });
          }
        } catch (_) {}
      }
      setState(() {
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
        error = 'No user found.';
      });
    }
  }

  Future<void> _fetchSettings() async {
    final settings = await ClassService.getSettings();
    setState(() {
      role = settings?['role'] ?? '';
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FE),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : error.isNotEmpty
                  ? Center(
                      child: Text(l10n.noUserFound,
                          style: const TextStyle(color: Colors.red)))
                  : CustomScrollView(
                      slivers: [
                        // Custom App Bar with gradient and language switcher
                        SliverAppBar(
                          expandedHeight: 280,
                          floating: false,
                          pinned: true,
                          automaticallyImplyLeading: false,
                          flexibleSpace: FlexibleSpaceBar(
                            background: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF4A90E2),
                                    Color(0xFF7B68EE),
                                    Color(0xFF9B59B6),
                                  ],
                                ),
                              ),
                              child: SafeArea(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 20),
                                    // Profile Image with beautiful shadow
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Colors.white,
                                        child: CircleAvatar(
                                          radius: 46,
                                          backgroundImage: photoBytes != null
                                              ? MemoryImage(photoBytes!)
                                              : (photoUrl != null &&
                                                      photoUrl!.isNotEmpty
                                                  ? NetworkImage(photoUrl!)
                                                  : null),
                                          child: (photoBytes == null &&
                                                  (photoUrl == null ||
                                                      photoUrl!.isEmpty))
                                              ? const Icon(Icons.person,
                                                  size: 50, color: Colors.grey)
                                              : null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Name with beautiful typography
                                    Text(
                                      name ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(0, 2),
                                            blurRadius: 4,
                                            color: Colors.black26,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Username with subtle styling
                                    Text(
                                      username ?? '',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Role badge
                                    if (role != null && role!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          role!.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                        // Settings Content
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.settings,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Settings Cards
                                _buildSettingsCard([
                                  _buildSettingsTile(
                                    Icons.person_outline,
                                    l10n.editProfile,
                                    l10n.updatePersonalInfo,
                                    const Color(0xFF4A90E2),
                                  ),
                                  // Hide change password for teachers
                                  if (userRole != 'teacher')
                                    _buildSettingsTile(
                                      Icons.lock_outline,
                                      l10n.changePassword,
                                      l10n.updatePassword,
                                      const Color(0xFF10B981),
                                    ),
                                ]),
                                const SizedBox(height: 16),
                                _buildSettingsCard([
                                  _buildSettingsTile(
                                    Icons.school,
                                    l10n.students,
                                    l10n.viewManageStudents,
                                    const Color(0xFFFF6B35),
                                  ),
                                  // Only show teacher management for admin users
                                  if (userRole == 'admin')
                                    _buildSettingsTile(
                                      Icons.people_outline,
                                      l10n.manageTeacher,
                                      l10n.addEditRemoveTeachers,
                                      const Color(0xFF8B5CF6),
                                    ),
                                  // Only show school management for admin users
                                  if (userRole == 'admin')
                                    _buildSettingsTile(
                                      Icons.school_outlined,
                                      l10n.schoolManagement,
                                      l10n.configureSchoolSettings,
                                      const Color(0xFFEF4444),
                                    ),
                                ]),
                                const SizedBox(height: 16),
                                _buildSettingsCard([
                                  _buildSettingsTile(
                                    Icons.language,
                                    l10n.language,
                                    l10n.changeAppLanguage,
                                    const Color(0xFF06B6D4),
                                  ),
                                  _buildSettingsTile(
                                    Icons.logout,
                                    l10n.logout,
                                    l10n.signOutAccount,
                                    const Color(0xFF6B7280),
                                  ),
                                ]),
                                const SizedBox(
                                    height: 100), // Space for bottom navigation
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
          // Add bottom navigation with Settings selected (index 3)
          bottomNavigationBar: AppBottomNavigation(
            currentIndex: 3, // Settings tab
            userRole: userRole, // Pass userRole for proper access control
          ),
        );
      },
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile(
      IconData icon, String title, String subtitle, Color iconColor) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Color(0xFF2D3748),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Color(0xFF718096),
          fontSize: 14,
        ),
      ),
      trailing: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Color(0xFF9CA3AF),
        ),
      ),
      onTap: () => _handleSettingsTap(title),
    );
  }

  void _handleSettingsTap(String title) async {
    final l10n = AppLocalizations.of(context)!;

    if (title == l10n.logout) {
      // Clear session info from Hive and Parse
      final box = await Hive.openBox('userSessionBox');
      await box.delete('sessionToken');
      await box.delete('username');
      await box.delete('role');
      final userBox = await Hive.openBox(CacheService.userBoxName);
      if (userCacheKey != null) {
        await userBox.delete(userCacheKey!);
      }
      final user = await ParseUser.currentUser();
      if (user != null) {
        await user.logout();
      }
      // Clear all cache data
      await CacheService.clearAllCache();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
    // Navigate to Students Screen
    if (title == l10n.students) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const StudentDashboard(),
        ),
      );
    }
    // Navigate to School Management Screen (Admin only)
    if (title == l10n.schoolManagement) {
      if (userRole == 'admin') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SchoolManagementScreen(),
          ),
        );
      } else {
        // Show unauthorized access message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied: Admin privileges required.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    // Navigate to Manage Teacher Screen (Admin only)
    if (title == l10n.manageTeacher) {
      if (userRole == 'admin') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TeacherDashboard(),
          ),
        );
      } else {
        // Show unauthorized access message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied: Admin privileges required.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    // Navigate to Edit Profile Screen (or Teacher Detail for teachers)
    if (title == l10n.editProfile) {
      if (userRole == 'teacher') {
        // For teachers, show their own teacher detail screen
        _navigateToTeacherDetail();
      } else {
        // For admins/students, show regular edit profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EditProfileScreen(),
          ),
        );
      }
    }
    // Navigate to Change Password Screen
    if (title == l10n.changePassword) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ChangePasswordScreen(),
        ),
      );
    }
    // Handle Language Selection
    if (title == l10n.language) {
      _showLanguageDialog();
    }
  }

  void _showLanguageDialog() {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<LanguageService>(
          builder: (context, languageService, child) {
            return AlertDialog(
              title: Text(l10n.selectLanguage),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
                    title: Text(l10n.english),
                    trailing: languageService.currentLocale.languageCode == 'en'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      languageService.changeLanguage(const Locale('en'));
                      Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    leading: const Text('🇰🇭', style: TextStyle(fontSize: 24)),
                    title: Text(l10n.khmer),
                    trailing: languageService.currentLocale.languageCode == 'km'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      languageService.changeLanguage(const Locale('km'));
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToTeacherDetail() async {
    try {
      // Get current user
      final ParseUser? currentUser = await ParseUser.currentUser();
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.loginFailed)),
        );
        return;
      }

      // Try multiple query strategies to find the teacher record
      ParseObject? teacherObject;

      // Strategy 1: Query by user pointer reference
      QueryBuilder<ParseObject> query1 =
          QueryBuilder<ParseObject>(ParseObject('Teacher'));
      query1.whereEqualTo('user', currentUser);
      ParseResponse response1 = await query1.query();

      if (response1.success &&
          response1.results != null &&
          response1.results!.isNotEmpty) {
        teacherObject = response1.results!.first;
      } else {
        // Strategy 2: Query by userId string
        QueryBuilder<ParseObject> query2 =
            QueryBuilder<ParseObject>(ParseObject('Teacher'));
        query2.whereEqualTo('userId', currentUser.objectId);
        ParseResponse response2 = await query2.query();

        if (response2.success &&
            response2.results != null &&
            response2.results!.isNotEmpty) {
          teacherObject = response2.results!.first;
        } else {
          // Strategy 3: Query by username
          QueryBuilder<ParseObject> query3 =
              QueryBuilder<ParseObject>(ParseObject('Teacher'));
          query3.whereEqualTo('username', currentUser.username);
          ParseResponse response3 = await query3.query();

          if (response3.success &&
              response3.results != null &&
              response3.results!.isNotEmpty) {
            teacherObject = response3.results!.first;
          }
        }
      }

      if (teacherObject != null) {
        // Convert ParseObject to Teacher model
        final Map<String, dynamic> teacherData = teacherObject.toJson();
        final Teacher teacher = Teacher.fromParseObject(teacherData);

        // Navigate to teacher detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherDetailScreen(teacher: teacher),
          ),
        );
      } else {
        // Teacher record not found - show detailed error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Teacher profile not found. Please contact administrator.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to teacher detail: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.unknownError)),
      );
    }
  }
}
