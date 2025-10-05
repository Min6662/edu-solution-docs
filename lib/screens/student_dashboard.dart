import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'add_student_information_screen.dart';
import '../services/class_service.dart';
import '../widgets/app_bottom_navigation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class StudentDashboard extends StatefulWidget {
  final int currentIndex;
  const StudentDashboard({super.key, this.currentIndex = 2});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List<Map<String, dynamic>> allStudents = [];
  List<Map<String, dynamic>> filteredStudents = [];
  bool loading = false;
  String searchQuery = '';
  String error = '';
  String? userRole; // Add userRole field

  @override
  void initState() {
    super.initState();
    _fetchUserRole(); // Fetch user role
    _loadCachedStudents();
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

  Future<void> _loadCachedStudents() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final box = await Hive.openBox('studentListBox');
      final cached = box.get('studentList') as List<dynamic>?;
      if (cached != null && cached.isNotEmpty) {
        allStudents =
            cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        filteredStudents = _filterStudents(searchQuery);
        setState(() {
          loading = false;
        });
      } else {
        await _loadStudents(forceRefresh: false);
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load cached students: \\${e.toString()}';
        loading = false;
      });
    }
  }

  Future<void> _loadStudents({bool forceRefresh = false}) async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final students =
          await ClassService.getStudentList(forceRefresh: forceRefresh);
      allStudents = students;
      final box = await Hive.openBox('studentListBox');
      await box.put('studentList', allStudents);
      filteredStudents = _filterStudents(searchQuery);
      setState(() {
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Error loading students: \\${e.toString()}';
      });
    }
  }

  Future<void> _refreshStudents() async {
    final box = await Hive.openBox('studentListBox');
    await box.delete('studentList');
    await _loadStudents(forceRefresh: true);
  }

  List<Map<String, dynamic>> _filterStudents(String query) {
    if (query.isEmpty) return allStudents;
    final lower = query.toLowerCase();
    return allStudents
        .where((stu) => (stu['name'] ?? '').toLowerCase().contains(lower))
        .toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value.trim();
      filteredStudents = _filterStudents(searchQuery);
    });
  }

  Future<Uint8List?> _getStudentImage(String studentId, String imageUrl) async {
    final box = Hive.box('studentImages');
    final cached = box.get(studentId);
    if (cached != null) {
      return Uint8List.fromList(List<int>.from(cached));
    }
    if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          await box.put(studentId, response.bodyBytes);
          return response.bodyBytes;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
        title: const Text('search and find students',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: () => _refreshStudents(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: 8),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(error, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: filteredStudents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final student = filteredStudents[i];
                      final name = student['name'] ?? '';
                      final years = student['yearsOfExperience'] ?? 0;
                      final rating = student['rating']?.toDouble() ?? 4.5;
                      final ratingCount = student['ratingCount'] ?? 100;
                      final hourlyRate = student['hourlyRate'] ?? '20/hr';
                      final photoUrl = student['photo'] ??
                          'https://randomuser.me/api/portraits/men/1.jpg';
                      final studentId = student['objectId'] ?? '';
                      return FutureBuilder<Uint8List?>(
                        future: _getStudentImage(studentId, photoUrl),
                        builder: (context, snapshot) {
                          return TeacherCard(
                            name: name,
                            role: 'Student Of Assalam',
                            years: years,
                            rating: rating,
                            ratingCount: ratingCount,
                            hourlyRate: hourlyRate,
                            imageBytes: snapshot.data,
                            imageUrl: photoUrl,
                            onAdd: () {},
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddStudentInformationScreen(),
            ),
          );
        },
        backgroundColor: Colors.blue,
        tooltip: 'Add Student',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: widget.currentIndex,
        userRole: userRole, // Pass userRole for proper access control
        // Remove onTabChanged to let AppBottomNavigation handle all navigation
      ),
    );
  }
}

class TeacherCard extends StatelessWidget {
  final String name;
  final String role;
  final int years;
  final double rating;
  final int ratingCount;
  final String? hourlyRate; // Make optional for student cards
  final String imageUrl;
  final Uint8List? imageBytes;
  final VoidCallback? onAdd;
  const TeacherCard({
    super.key,
    required this.name,
    required this.role,
    required this.years,
    required this.rating,
    required this.ratingCount,
    this.hourlyRate, // Optional
    required this.imageUrl,
    this.imageBytes,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageBytes != null
                  ? Image.memory(
                      imageBytes!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading student image: $error');
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.person,
                              size: 32, color: Colors.grey),
                        );
                      },
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.work, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(role,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ),
                    ],
                  ),
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                  Text('$years years of experience',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 16),
                      Text('${rating.toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(' ($ratingCount)',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      if (hourlyRate != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(hourlyRate!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Additional student info fields (address, phone, etc.)
                  if (imageBytes == null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            imageUrl,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onAdd != null)
              IconButton(
                icon:
                    const Icon(Icons.add_circle_outline, color: Colors.orange),
                onPressed: onAdd,
              ),
          ],
        ),
      ),
    );
  }
}
