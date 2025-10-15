import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../screens/teacher_registration_screen.dart'; // Import for navigation
import '../screens/teacher_detail_screen.dart'; // Import for teacher detail
import '../models/teacher.dart'; // Import Teacher model
import '../services/cache_service.dart';

class TeacherList extends StatefulWidget {
  const TeacherList({super.key});

  @override
  State<TeacherList> createState() => _TeacherListState();
}

class _TeacherListState extends State<TeacherList> {
  List<ParseObject> teachers = [];
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    print('DEBUG: Starting _fetchTeachers...');

    // Try to load from cache first
    final cachedTeachers = CacheService.getTeacherList();
    print('DEBUG: Cached teachers data: ${cachedTeachers?.length ?? 0} items');

    if (cachedTeachers != null && cachedTeachers.isNotEmpty) {
      print('DEBUG: Found cached data, reconstructing ParseObjects...');

      // Convert cached data back to ParseObject list with proper Parse fields
      final teacherObjects = cachedTeachers.map((teacherData) {
        print(
            'DEBUG: Processing cached teacher: ${teacherData['fullName'] ?? 'Unknown'}');

        final parseObject = ParseObject('Teacher');

        // Set the objectId first (essential for Parse objects)
        if (teacherData['objectId'] != null) {
          parseObject.objectId = teacherData['objectId'] as String;
          print('DEBUG: Set objectId: ${parseObject.objectId}');
        }

        // Set all other fields
        teacherData.forEach((key, value) {
          if (key != 'objectId' && value != null) {
            // Handle date fields properly
            if (key == 'createdAt' || key == 'updatedAt') {
              if (value is String) {
                try {
                  parseObject.set(key, DateTime.parse(value));
                } catch (e) {
                  print('DEBUG: Failed to parse date $key: $value');
                }
              }
            } else {
              parseObject.set(key, value);
            }
          }
        });

        // Verify the fields are set correctly
        print(
            'DEBUG: Reconstructed teacher - Name: ${parseObject.get<String>('fullName')}, Subject: ${parseObject.get<String>('subject')}');

        return parseObject;
      }).toList();

      setState(() {
        teachers = teacherObjects;
        loading = false;
      });

      print(
          'DEBUG: Loaded ${teachers.length} teachers from cache with proper Parse fields');

      // Still fetch fresh data in background to ensure data is up to date
      _fetchFreshTeachers();
      return;
    }

    // Load fresh data if no cache or cache loading failed
    print('DEBUG: No cache found or cache empty, loading fresh data...');
    await _fetchFreshTeachers();
  }

  Future<void> _fetchFreshTeachers() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Teacher'));
      final response = await query.query();

      if (response.success && response.results != null) {
        final fetchedTeachers = response.results!.cast<ParseObject>();

        // Convert to Map for caching
        final teacherDataList = fetchedTeachers.map((teacher) {
          return {
            'objectId': teacher.objectId,
            'fullName': teacher.get<String>('fullName'),
            'subject': teacher.get<String>('subject'),
            'gender': teacher.get<String>('gender'),
            'photo': teacher.get<String>('photo'),
            'photoUrl': teacher.get<String>('photoUrl'),
            'yearsOfExperience': teacher.get<int>('yearsOfExperience'),
            'Address': teacher.get<String>('Address'),
            'address': teacher.get<String>('address'),
            'hourlyRate': teacher.get<double>('hourlyRate'),
            'createdAt': teacher.createdAt?.toIso8601String(),
            'updatedAt': teacher.updatedAt?.toIso8601String(),
          };
        }).toList();

        // Save to cache
        await CacheService.saveTeacherList(teacherDataList);

        setState(() {
          teachers = fetchedTeachers;
          loading = false;
        });

        print('DEBUG: Loaded and cached ${teachers.length} fresh teachers');
      } else {
        setState(() {
          error = 'Failed to fetch teachers.';
          loading = false;
        });
      }
    } catch (e) {
      print('Error fetching teachers: $e');
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  Future<void> _refreshTeachers() async {
    // Clear teacher cache to force fresh data
    await CacheService.clearTeacherList();

    // Reload data
    await _fetchTeachers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Teachers'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTeachers,
            tooltip: 'Refresh Teachers',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Teachers',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error.isNotEmpty
                      ? Center(
                          child: Text(error,
                              style: const TextStyle(color: Colors.red)))
                      : teachers.isEmpty
                          ? const Center(child: Text('No teachers found.'))
                          : ListView.builder(
                              itemCount: teachers.length,
                              itemBuilder: (context, index) {
                                final teacher = teachers[index];
                                final name =
                                    teacher.get<String>('fullName') ?? '';
                                final subject =
                                    teacher.get<String>('subject') ?? '';
                                final gender =
                                    teacher.get<String>('gender') ?? '';
                                final photoUrl = teacher.get<String>('photo');
                                final years =
                                    teacher.get<int>('yearsOfExperience') ?? 0;
                                return Card(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 2,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: (photoUrl != null &&
                                              photoUrl.isNotEmpty)
                                          ? NetworkImage(photoUrl)
                                          : const NetworkImage(
                                              'https://randomuser.me/api/portraits/men/1.jpg'),
                                      backgroundColor: Colors.pink[100],
                                    ),
                                    title: Text(name),
                                    subtitle: Text(
                                        'Subject: $subject\nGender: $gender\nExperience: $years years'),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.pink[400],
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      onPressed: () async {
                                        // Create Teacher model from ParseObject
                                        final teacherModel = Teacher(
                                          objectId: teacher.objectId!,
                                          fullName: name,
                                          gender: gender,
                                          subject: subject,
                                          photoUrl: photoUrl ?? '',
                                          address: teacher
                                                  .get<String>('Address') ??
                                              teacher.get<String>('address') ??
                                              '',
                                        );

                                        // Navigate to TeacherDetailScreen and wait for result
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                TeacherDetailScreen(
                                              teacher: teacherModel,
                                            ),
                                          ),
                                        );

                                        // Refresh list if changes were made
                                        if (result == true) {
                                          await CacheService.clearTeacherList();
                                          _fetchTeachers();
                                        }
                                      },
                                      child: const Text('View'),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TeacherRegistrationScreen(),
            ),
          );
          // Refresh teacher list if a teacher was created
          if (result == true) {
            // Clear cache to ensure fresh data is loaded
            await CacheService.clearTeacherList();
            _fetchTeachers();
          }
        },
        backgroundColor: Colors.blue[900],
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Teacher',
      ),
    );
  }
}
