import 'package:flutter/material.dart';
import '../models/teacher.dart';
import '../views/teacher_card.dart' as views;
import 'teacher_registration_screen.dart';
import '../services/class_service.dart';
import '../services/cache_service.dart';
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
  Map<String, Uint8List> teacherImages = {}; // Add teacherImages map

  @override
  void initState() {
    super.initState();
    _loadTeachers(); // Fixed method name
  }

  Future<void> _loadTeachers({bool forceRefresh = false}) async {
    print('DEBUG: _loadTeachers called with forceRefresh: $forceRefresh');

    setState(() {
      loading = true;
      error = '';
    });

    try {
      // If force refresh, clear cache first
      if (forceRefresh) {
        print('DEBUG: Force refresh - clearing teacher cache...');
        await CacheService.clearTeacherList();
      }

      final teacherList = await ClassService.getTeacherList();
      print('DEBUG: Received ${teacherList.length} teachers from ClassService');

      allTeachers = teacherList.map((data) {
        print(
            'DEBUG: Converting teacher data: ${data['fullName']} - ${data['yearsOfExperience']} years - \$${data['hourlyRate']}/hr');
        return Teacher.fromParseObject(data);
      }).toList();

      print(
          'DEBUG: Successfully converted ${allTeachers.length} teachers to Teacher objects');

      setState(() {
        loading = false;
      });

      // Load teacher images from cache or network
      for (final teacher in allTeachers) {
        _getTeacherImage(teacher.objectId, teacher.photoUrl ?? '');
      }
    } catch (e) {
      print('DEBUG: Error in _loadTeachers: $e');
      setState(() {
        error = 'Failed to load teachers: ${e.toString()}';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
    );
  }
}
