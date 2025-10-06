import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../services/class_service.dart';
import '../services/cache_service.dart';
import '../widgets/app_bottom_navigation.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'login_page.dart';
import 'school_management_screen.dart';
import 'teacher_dashboard.dart'; // Import for teacher management
import 'student_dashboard.dart'; // Import for student dashboard

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
      final fetchedRole = user?.get<String>('role');
      if (mounted) {
        setState(() {
          userRole = fetchedRole;
        });
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Text(error, style: const TextStyle(color: Colors.red)))
              : CustomScrollView(
                  slivers: [
                    // Custom App Bar with gradient
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
                                        color: Colors.black.withOpacity(0.2),
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
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.3)),
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
                            const Text(
                              'Settings',
                              style: TextStyle(
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
                                'Edit Profile',
                                'Update your personal information',
                                const Color(0xFF4A90E2),
                              ),
                              _buildSettingsTile(
                                Icons.lock_outline,
                                'Change Password',
                                'Update your account password',
                                const Color(0xFF10B981),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            _buildSettingsCard([
                              _buildSettingsTile(
                                Icons.school,
                                'Students',
                                'View and manage students',
                                const Color(0xFFFF6B35),
                              ),
                              _buildSettingsTile(
                                Icons.people_outline,
                                'Manage Teacher',
                                'Add, edit, or remove teachers',
                                const Color(0xFF8B5CF6),
                              ),
                              _buildSettingsTile(
                                Icons.school_outlined,
                                'School Management',
                                'Configure school settings',
                                const Color(0xFFEF4444),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            _buildSettingsCard([
                              _buildSettingsTile(
                                Icons.logout,
                                'Logout',
                                'Sign out of your account',
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
    if (title == 'Logout') {
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
    if (title == 'Students') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const StudentDashboard(),
        ),
      );
    }
    // Navigate to School Management Screen
    if (title == 'School Management') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SchoolManagementScreen(),
        ),
      );
    }
    // Navigate to Manage Teacher Screen
    if (title == 'Manage Teacher') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TeacherDashboard(),
        ),
      );
    }
    // TODO: Implement navigation for other settings
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: const Center(
        child: Text('Edit Profile Screen'),
      ),
    );
  }
}
