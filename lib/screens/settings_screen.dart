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
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        automaticallyImplyLeading:
            false, // This removes the back button completely
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Text(error, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: photoBytes != null
                                ? MemoryImage(photoBytes!)
                                : (photoUrl != null && photoUrl!.isNotEmpty
                                    ? NetworkImage(photoUrl!)
                                    : null),
                            child: (photoBytes == null &&
                                    (photoUrl == null || photoUrl!.isEmpty))
                                ? const Icon(Icons.person, size: 40)
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(name ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(username ?? '',
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 4),
                          if (role != null && role!.isNotEmpty)
                            Text('Role: $role',
                                style: const TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _settingsTile(Icons.person, 'Edit Profile'),
                    _settingsTile(Icons.lock, 'Change Password'),
                    _settingsTile(Icons.school, 'School Management'),
                    _settingsTile(Icons.logout, 'Logout'),
                  ],
                ),
      // Add bottom navigation with Settings selected (index 3)
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 3, // Settings tab
        userRole: userRole, // Pass userRole for proper access control
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () async {
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
        // Navigate to School Management Screen
        if (title == 'School Management') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SchoolManagementScreen(),
            ),
          );
        }
        // TODO: Implement navigation for other settings
      },
    );
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
