import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../models/teacher.dart';
import '../views/teacher_card.dart' as views;
import 'teacher_registration_screen.dart';
import '../services/class_service.dart';
import '../services/cache_service.dart';
import '../widgets/app_bottom_navigation.dart';
import 'package:hive/hive.dart';
import 'dart:typed_data';
import 'teacher_detail_screen.dart'; // Add import for navigation
import 'package:http/http.dart' as http;

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  List<Teacher> allTeachers = [];
  List<Teacher> filteredTeachers = [];
  bool loading = false;
  String searchQuery = '';
  String error = '';
  String? userRole; // Add userRole field
  Map<String, Uint8List> teacherImages = {}; // Add teacherImages map

  @override
  void initState() {
    super.initState();
    _fetchUserRole(); // Fetch user role
    _loadTeachers(); // Fixed method name
  }

  Future<void> _fetchUserRole() async {
    try {
      final user = await ParseUser.currentUser();
      final role = user?.get<String>('role');
      if (mounted) {
        setState(() {
          userRole = role;
        });
      }
    } catch (e) {
      print('Error fetching user role: $e');
    }
  }

  Future<void> _loadTeachers({bool forceRefresh = false}) async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final teacherList = await ClassService.getTeacherList();
      allTeachers =
          teacherList.map((data) => Teacher.fromParseObject(data)).toList();
      setState(() {
        loading = false;
      });
      // Load teacher images from cache or network
      for (final teacher in allTeachers) {
        _getTeacherImage(teacher.objectId, teacher.photoUrl ?? '');
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load teachers: \\${e.toString()}';
        loading = false;
      });
    }
  }

  Future<void> _getTeacherImage(String teacherId, String imageUrl) async {
    print('Getting image for teacherId: $teacherId, imageUrl: $imageUrl');
    final box = await Hive.openBox('teacherImages');
    final cached = box.get(teacherId);
    if (cached != null) {
      print('Loaded image from cache for $teacherId');
      setState(() {
        teacherImages[teacherId] = Uint8List.fromList(List<int>.from(cached));
      });
      return;
    }
    if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        print('Image download status for $teacherId: ${response.statusCode}');
        if (response.statusCode == 200) {
          await box.put(teacherId, response.bodyBytes);
          setState(() {
            teacherImages[teacherId] = response.bodyBytes;
          });
          print('Image cached for $teacherId');
        } else {
          print('Failed to download image for $teacherId');
        }
      } catch (e) {
        print('Error downloading image for $teacherId: $e');
      }
    } else {
      print('No valid image URL for $teacherId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false, // Remove back button
        title: const Text('Teachers', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            tooltip: 'Refresh Teacher List',
            onPressed: () async {
              await CacheService.clearTeacherList();
              _loadTeachers(forceRefresh: true);
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Text(error, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allTeachers.length,
                  itemBuilder: (context, index) {
                    final teacher = allTeachers[index];
                    return views.TeacherCard(
                      name: teacher.fullName,
                      photoUrl: teacher.photoUrl,
                      yearsOfExperience: teacher.yearsOfExperience,
                      rating: teacher.rating,
                      ratingCount: teacher.ratingCount,
                      hourlyRate: teacher.hourlyRate,
                      imageBytes: teacherImages[teacher.objectId],
                      onTap: () {
                        print(
                            'DEBUG: Teacher card tapped for ${teacher.fullName}');
                        // Navigate to TeacherDetailScreen instead of showing dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TeacherDetailScreen(teacher: teacher),
                          ),
                        );
                      },
                      onAdd: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TeacherRegistrationScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TeacherRegistrationScreen(),
            ),
          );
        },
        backgroundColor: Colors.blue,
        tooltip: 'Add Teacher',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 1, // Teachers tab
        userRole: userRole, // Pass userRole for proper access control
        // Remove onTabChanged to let AppBottomNavigation handle all navigation
      ),
    );
  }
}
