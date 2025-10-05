import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../screens/teacher_registration_screen.dart'; // Import for navigation
import '../screens/teacher_detail_screen.dart'; // Import for teacher detail
import '../models/teacher.dart'; // Import Teacher model

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
    setState(() {
      loading = true;
      error = '';
    });
    final query = QueryBuilder<ParseObject>(ParseObject('Teacher'));
    final response = await query.query();
    if (response.success && response.results != null) {
      setState(() {
        teachers = response.results!.cast<ParseObject>();
        loading = false;
      });
    } else {
      setState(() {
        error = 'Failed to fetch teachers.';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Teacher List'),
        backgroundColor: Colors.blue[900],
        elevation: 0,
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
                                      onPressed: () {
                                        // Create Teacher model from ParseObject
                                        final teacherModel = Teacher(
                                          objectId: teacher.objectId!,
                                          fullName: name,
                                          gender: gender,
                                          subject: subject,
                                          photoUrl: photoUrl ?? '',
                                          address:
                                              teacher.get<String>('Address') ??
                                                  '',
                                        );

                                        // Navigate to TeacherDetailScreen
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                TeacherDetailScreen(
                                              teacher: teacherModel,
                                            ),
                                          ),
                                        );
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
            _fetchTeachers();
          }
        },
        backgroundColor: Colors.blue[900],
        child: const Icon(Icons.add),
        tooltip: 'Create Teacher',
      ),
    );
  }
}
